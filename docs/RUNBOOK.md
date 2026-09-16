# Runbook — awsome-fastapi

Operational runbook for alerts defined in [`monitoring/alerts/prometheus-rules.yaml`](../monitoring/alerts/prometheus-rules.yaml). Pair with [`docs/SLO.md`](SLO.md) for the reliability targets these alerts protect.

**Before you start:** point `kubectl` at the cluster:

```bash
aws eks update-kubeconfig --name dsb-devsecops-cluster --region us-east-1 --profile <your-profile>
```

---

## HighErrorRate (`HighErrorRate`)

**Severity:** warning (>1% 5xx for 5m) or critical (>5% 5xx for 2m)

### Symptoms
- Elevated 5xx responses observed by clients or in the Errors panel of the Golden Signals dashboard.
- Error budget burning faster than the slow/fast burn thresholds in `docs/SLO.md`.

### Likely causes
- Bad deploy (application bug, missing dependency, misconfiguration) just released via the `awsome-fastapi` CodePipeline.
- Pod crash-looping or failing readiness probes, reducing healthy replica count.
- Downstream dependency failure (database, external API) causing app-level 500s.
- Node resource pressure causing throttling/OOM kills.

### Investigation
```bash
# Pipeline / deploy history
aws codepipeline get-pipeline-state --name awsome-fastapi

# Pod status and recent events
kubectl -n default get pods -l app=awsome-fastapi -o wide
kubectl -n default describe pods -l app=awsome-fastapi
kubectl -n default get events --sort-by=.lastTimestamp | tail -30

# Application logs (last 100 lines per pod)
for p in $(kubectl -n default get pods -l app=awsome-fastapi -o name); do
  echo "== $p =="; kubectl -n default logs "$p" --tail=100
done

# Error rate over time in Prometheus (via port-forward, see install-monitoring.sh)
# query: sum(rate(http_requests_total{job="awsome-fastapi",code=~"5.."}[5m])) / sum(rate(http_requests_total{job="awsome-fastapi"}[5m]))
```

### Mitigation
1. **If caused by a recent deploy:** roll back the Kubernetes Deployment immediately:
   ```bash
   kubectl -n default rollout undo deployment/awsome-fastapi
   kubectl -n default rollout status deployment/awsome-fastapi
   ```
2. **If the pipeline needs to be reverted** so the next release doesn't reintroduce the bug:
   ```bash
   git revert <bad-commit-sha>
   git push origin main
   # Re-run the awsome-fastapi CodePipeline (Release change) once the revert is merged.
   ```
3. **If caused by downstream dependency failure:** confirm dependency health independently; consider temporarily scaling down non-essential traffic or enabling a maintenance response if the dependency has no retry/circuit breaker.
4. **If caused by resource pressure:** see `NodePressure` below.
5. Once error rate returns below 1% for at least 10 minutes, confirm alert has resolved in Alertmanager/Grafana.
6. Update the error budget freeze status per `docs/SLO.md` section 5 if the incident consumed significant budget — check the Grafana "30-Day Error Budget Remaining" gauge.

---

## HighLatency (`HighLatency`)

**Severity:** warning (p95 > 500ms for 10m)

### Symptoms
- p95 latency panel on Golden Signals dashboard trending above the 500ms SLO line.
- User reports of slow responses.

### Likely causes
- Traffic spike beyond current replica capacity (no HPA configured, or HPA lagging).
- CPU throttling due to insufficient resource requests/limits.
- Slow downstream calls (database, third-party API).
- Node-level CPU/memory pressure (noisy neighbor pods).

### Investigation
```bash
# Current replica count and resource usage
kubectl -n default get deployment awsome-fastapi
kubectl top pods -n default -l app=awsome-fastapi
kubectl top nodes

# Check for throttling
kubectl -n default describe pod -l app=awsome-fastapi | grep -A5 "Limits\|Requests"

# Prometheus query for p95 trend:
# histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket{job="awsome-fastapi"}[5m])) by (le))
```

### Mitigation
1. **Scale out manually** if traffic-driven and no autoscaler is in place:
   ```bash
   kubectl -n default scale deployment/awsome-fastapi --replicas=4
   ```
2. If a Horizontal Pod Autoscaler is configured, confirm it is scaling as expected:
   ```bash
   kubectl -n default get hpa
   kubectl -n default describe hpa awsome-fastapi
   ```
3. If caused by a recent deploy introducing a slow code path, roll back:
   ```bash
   kubectl -n default rollout undo deployment/awsome-fastapi
   ```
4. If caused by node saturation, see `NodePressure` below — consider adding nodes to the managed node group via the EKS Terraform Cloud workspace (`dsb-aws-devsecops-eks-cluster`) if sustained.
5. Record the incident in `docs/LOADTEST-RESULTS.md` if discovered/reproduced during load testing, noting the RPS at which p95 broke SLO.

---

## PodCrashLooping (`PodCrashLooping`)

**Severity:** critical (>3 restarts in 15m)

### Symptoms
- Reduced available replicas; possible correlated `HighErrorRate` or `HighLatency` alerts.
- `kubectl get pods` shows `CrashLoopBackOff`.

### Likely causes
- Application startup failure (bad config, missing environment variable, unhandled exception on boot).
- Failing liveness probe causing repeated restarts of an otherwise-healthy-but-slow-starting process.
- OOMKilled due to memory limit too low for actual usage.
- Bad image pushed by the pipeline (e.g. broken dependency in `requirements.txt`).

### Investigation
```bash
kubectl -n default get pods -l app=awsome-fastapi
kubectl -n default describe pod <pod-name>       # check "Last State" and "Reason" (OOMKilled, Error, etc.)
kubectl -n default logs <pod-name> --previous     # logs from the crashed instance
kubectl -n default get events --field-selector involvedObject.name=<pod-name>
```

### Mitigation
1. **OOMKilled:** increase memory limits/requests in the Deployment manifest (`terraform/pipelines/buildspecs/awsome-fastapi/build.yml` generates this at deploy time) or reduce the app's memory footprint. Re-deploy.
2. **Bad image/config from latest deploy:** roll back:
   ```bash
   kubectl -n default rollout undo deployment/awsome-fastapi
   ```
3. **Failing liveness probe on slow startup:** adjust `initialDelaySeconds`/`periodSeconds` on the probe and redeploy via the pipeline.
4. If the root cause is in application code, revert the offending commit in the app repository and re-release through CodePipeline (see `HighErrorRate` mitigation step 2 for the git revert pattern).

---

## NodePressure (`NodePressure`)

**Severity:** warning (node memory > 85% for 10m)

### Symptoms
- Node-level memory pressure; risk of pod eviction across the managed node group.
- Possible correlated `HighLatency` or `PodCrashLooping` alerts on co-located pods.

### Likely causes
- Node group undersized for current workload (t3.medium default, see README architecture diagram).
- Memory leak in the application or a noisy-neighbor pod.
- Insufficient number of nodes (desired count too low) during a traffic spike.

### Investigation
```bash
kubectl top nodes
kubectl describe node <node-name> | grep -A10 "Allocated resources"
kubectl -n default get pods -o wide --sort-by='.status.startTime'

# Identify which pods/namespaces are consuming the most memory on the node:
kubectl top pods -A --sort-by=memory
```

### Mitigation
1. **Short term:** cordon and drain the affected node to redistribute pods, if cluster has spare capacity:
   ```bash
   kubectl cordon <node-name>
   kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data
   ```
2. **Scale the node group** by increasing the desired/min node count in the EKS Terraform Cloud workspace (`dsb-aws-devsecops-eks-cluster`) and applying — this is an infrastructure change and goes through the normal Terraform Cloud plan/apply flow, not a manual `kubectl` edit.
3. **Reduce memory footprint:** identify and fix a leaking pod (see investigation commands above) or lower unnecessary replica counts for non-critical workloads.
4. Uncordon the node once healthy:
   ```bash
   kubectl uncordon <node-name>
   ```

---

## General rollback reference

```bash
# Roll back the last Kubernetes Deployment change
kubectl -n default rollout undo deployment/awsome-fastapi

# Roll back to a specific revision
kubectl -n default rollout history deployment/awsome-fastapi
kubectl -n default rollout undo deployment/awsome-fastapi --to-revision=<N>

# Revert the application code and re-trigger the pipeline
git revert <bad-commit-sha>
git push origin main
# Then: AWS Console -> CodePipeline -> awsome-fastapi -> Release change
```
