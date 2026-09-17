# Monitoring — Implementation Guide

Step-by-step guide to stand up monitoring, alerting, the Golden Signals dashboard, and optional Grafana Cloud remote_write for `awsome-fastapi` on `dsb-devsecops-cluster`. See [`../docs/SLO.md`](../docs/SLO.md) for the SLO targets these alerts protect and [`../docs/RUNBOOK.md`](../docs/RUNBOOK.md) for incident response.

## Prerequisites

1. `kubectl` pointed at the cluster:
   ```bash
   aws eks update-kubeconfig --name dsb-devsecops-cluster --region us-east-1 --profile <your-profile>
   ```
2. `helm` >= 3.12 installed locally.
3. EBS CSI driver installed on the cluster (required for the gp3 PVCs used by Prometheus/Grafana/Alertmanager persistence in [`values.yaml`](values.yaml)).
4. The `awsome-fastapi` app instrumented to expose Prometheus metrics on `/metrics` (e.g. via `prometheus-fastapi-instrumentator`). Until this exists, the `ServiceMonitor` scrapes an empty target and `HighErrorRate`/`HighLatency` alerts stay pending — this is a known gap noted in `docs/SLO.md` section 2.

## 1. Install the monitoring stack

```bash
./monitoring/install-monitoring.sh
```

This script (see [`install-monitoring.sh`](install-monitoring.sh)):

1. Adds/updates the `prometheus-community` Helm repo.
2. Creates the `monitoring` namespace.
3. Applies [`remote-write-secret.yaml`](remote-write-secret.yaml) (placeholder Grafana Cloud token — see step 4 below).
4. Installs/upgrades `kube-prometheus-stack` using [`values.yaml`](values.yaml) (7-day retention, gp3 storage, Grafana + Alertmanager enabled).
5. Applies the app [`servicemonitor.yaml`](servicemonitor.yaml).
6. Applies the alerting rules and Alertmanager config from [`alerts/`](alerts/).

Verify the pods came up:

```bash
kubectl -n monitoring get pods
```

## 2. Configure alert email routing

Edit [`alerts/alertmanager-config.yaml`](alerts/alertmanager-config.yaml) and replace the placeholder SMTP/email values (`${SMTP_HOST}`, `${SMTP_PORT}`, `${SMTP_FROM_ADDRESS}`, `${SMTP_USERNAME}`, `${SMTP_PASSWORD}`, `${ONCALL_EMAIL}`, `${TEAM_EMAIL}`) — inject them via your secrets manager or CI variable substitution, never commit real credentials. Re-apply:

```bash
kubectl apply -f monitoring/alerts/alertmanager-config.yaml
kubectl -n monitoring rollout restart statefulset alertmanager-kube-prometheus-stack-alertmanager
```

Confirm the rules loaded and the config parsed:

```bash
kubectl -n monitoring port-forward svc/kube-prometheus-stack-alertmanager 9093:9093
# open http://localhost:9093 -> Status -> check the config was accepted
```

## 3. View alerts and rules in Prometheus

```bash
kubectl -n monitoring port-forward svc/kube-prometheus-stack-kube-prom-prometheus 9090:9090
# open http://localhost:9090 -> Alerts, confirm HighErrorRate, HighLatency,
# PodCrashLooping, and NodePressure are listed (Inactive/Pending/Firing)
```

## 4. Import the Golden Signals dashboard into Grafana

Get the auto-generated Grafana admin password (or use the one you set in `values.yaml` under `grafana.adminPassword`):

```bash
kubectl -n monitoring get secret kube-prometheus-stack-grafana \
  -o jsonpath="{.data.admin-password}" | base64 -d; echo
```

Port-forward and log in:

```bash
kubectl -n monitoring port-forward svc/kube-prometheus-stack-grafana 3000:80
# open http://localhost:3000 (user: admin)
```

Load the dashboard either via the UI (**Dashboards -> New -> Import**, paste the contents of [`dashboards/golden-signals-dashboard.json`](dashboards/golden-signals-dashboard.json)) or automatically via the sidecar ConfigMap convention already enabled in `values.yaml`:

```bash
kubectl -n monitoring create configmap golden-signals-dashboard \
  --from-file=monitoring/dashboards/golden-signals-dashboard.json \
  --dry-run=client -o yaml \
  | kubectl label -f - --local -o yaml grafana_dashboard=1 \
  | kubectl apply -f -
```

The Grafana sidecar picks up any ConfigMap labeled `grafana_dashboard=1` across all namespaces (`sidecar.dashboards.searchNamespace: ALL` in `values.yaml`) and loads it within ~1 minute.

## 5. Enable Grafana Cloud remote_write (optional, off-cluster long-term storage)

1. Create/sign in to a Grafana Cloud stack and copy its Prometheus remote_write endpoint URL and API token from **Connections -> Data sources -> Prometheus** (or **My Account -> API Keys**).
2. Set the real token in the Secret instead of the placeholder:
   ```bash
   kubectl -n monitoring create secret generic grafana-cloud-remote-write \
     --from-literal=api-token="<your-grafana-cloud-api-token>" \
     --dry-run=client -o yaml | kubectl apply -f -
   ```
3. Update the placeholder endpoint in [`values.yaml`](values.yaml) under `prometheus.prometheusSpec.remoteWrite[0].url` to your stack's real push URL.
4. Re-apply the Helm release so Prometheus picks up the new remote_write config:
   ```bash
   ./monitoring/install-monitoring.sh
   ```
5. Confirm data is arriving in Grafana Cloud: **Explore** in your Grafana Cloud instance, query `http_requests_total` or `ALERTS`, and confirm series appear labeled `job="awsome-fastapi"`.

The `writeRelabelConfigs` in `values.yaml` intentionally keep only `http_*` app metrics and `ALERTS`/`ALERTS_FOR_STATE` series so usage stays within Grafana Cloud's free-tier active-series limits — everything else (cAdvisor, kube-state-metrics, node-exporter churn) stays local-only in the 7-day in-cluster Prometheus.

## 6. Verify alerts actually fire (optional smoke test)

Use the k6 load test to generate traffic and confirm the Golden Signals dashboard and alerts respond as expected:

```bash
BASE_URL=http://<load-balancer-dns> k6 run loadtest/loadtest.js
```

Record observations in [`../docs/LOADTEST-RESULTS.md`](../docs/LOADTEST-RESULTS.md).

## Uninstall

```bash
helm uninstall kube-prometheus-stack -n monitoring
kubectl delete namespace monitoring
```

This removes Prometheus, Grafana, Alertmanager, their PVCs, and all resources applied by `install-monitoring.sh`. It does not affect the `awsome-fastapi` app or the EKS cluster itself.
