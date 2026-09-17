# Service Level Objectives (SLO) — awsome-fastapi

**Service owner:** DevSecOps Platform Team
**Service:** `awsome-fastapi` (Kubernetes Deployment + LoadBalancer Service, namespace `default`, cluster `dsb-devsecops-cluster`)
**Status:** Active
**Last reviewed:** 2026-09-17
**Review cadence:** Quarterly, or after any incident that consumes >25% of a monthly error budget

## 1. Purpose

This document defines the Service Level Indicators (SLIs), Service Level Objectives (SLOs), error budget policy, and burn-rate alerting strategy for the `awsome-fastapi` service. It is the source of truth for what "reliable enough" means for this service and what happens when reliability degrades.

## 2. Service Level Indicators (SLIs)

SLIs are measured from Prometheus metrics scraped from the application's `/metrics` endpoint (via the `ServiceMonitor` in [`monitoring/servicemonitor.yaml`](../monitoring/servicemonitor.yaml)) and from the Kubernetes/ingress layer.

| SLI | Definition | Metric source | PromQL (illustrative) |
|---|---|---|---|
| Availability | Proportion of HTTP requests that do **not** return a 5xx status code | `http_requests_total` (or `http_server_requests_seconds_count` depending on instrumentation library) | `sum(rate(http_requests_total{job="awsome-fastapi",code!~"5.."}[5m])) / sum(rate(http_requests_total{job="awsome-fastapi"}[5m]))` |
| Latency | Proportion of requests served with p95 latency under threshold | `http_request_duration_seconds_bucket` | `histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket{job="awsome-fastapi"}[5m])) by (le))` |

> **Instrumentation note:** the current `awsome-fastapi` app does not yet expose Prometheus metrics. Before these SLIs can be measured, add an instrumentation library (e.g. `prometheus-fastapi-instrumentator` for FastAPI) that exposes `/metrics` with request count and duration histograms labeled by `code`/`status_code` and `path`. Until instrumented, the `ServiceMonitor` will scrape an empty/absent target and alerts will remain pending.

## 3. Service Level Objectives (SLOs)

| SLO | Target | Measurement window | Rationale |
|---|---|---|---|
| Availability | 99.9% of requests succeed (non-5xx) | Rolling 30 days | Matches a "three nines" internal-tool tier; balances user experience against low-cost single-region, single-LB architecture |
| Latency | 95% of requests complete in < 500 ms | Rolling 30 days | FastAPI hello-world workload; 500 ms budget leaves headroom for downstream calls added later |

### 3.1 Error budget

A 99.9% availability SLO over 30 days allows the following error budget:

| Window | Allowed downtime (error budget) |
|---|---|
| 30 days (month) | **43.2 minutes** |
| 7 days (week) | 10.08 minutes |
| 1 day | 1.44 minutes |
| 1 hour | 3.6 seconds |

Calculation: `(1 - 0.999) * 30 days * 24 hours * 60 minutes = 43.2 minutes`.

The error budget is tracked as **percent of budget consumed**, not just raw minutes, so both availability and latency violations can be normalized against the same 43.2-minute-equivalent budget.

## 4. Burn-rate alerting policy

Burn-rate alerts fire when the service is consuming its error budget faster than sustainable, well before the full 43.2-minute budget is exhausted. Two windows are used to catch both sudden outages and slow degradations, following the multi-window, multi-burn-rate pattern.

| Alert | Burn rate | Budget consumed | Detection window | Severity | Meaning |
|---|---|---|---|---|---|
| Fast burn | 14.4x | 2% of monthly budget | 1 hour | Critical | At this rate the entire monthly budget is exhausted in ~2 days; page immediately |
| Slow burn | 6x | 5% of monthly budget | 6 hours | Warning | At this rate the entire monthly budget is exhausted in ~5 days; ticket/Slack, review within business hours |

Burn rate is computed as:

```
burn_rate = (error_ratio_over_window) / (1 - SLO_target)
```

For example, a fast-burn alert on the 1-hour window fires when:

```
sum(rate(http_requests_total{job="awsome-fastapi",code=~"5.."}[1h]))
  /
sum(rate(http_requests_total{job="awsome-fastapi"}[1h]))
  > 14.4 * (1 - 0.999)   # i.e. > 1.44% error rate sustained for 1h
```

These thresholds are implemented as Prometheus alerting rules in [`monitoring/alerts/prometheus-rules.yaml`](../monitoring/alerts/prometheus-rules.yaml) (`HighErrorRate` warning/critical rules) and routed via [`monitoring/alerts/alertmanager-config.yaml`](../monitoring/alerts/alertmanager-config.yaml).

## 5. Error budget policy

| Budget consumed (rolling 30 days) | Policy |
|---|---|
| < 50% | Normal operations. Feature work and deploys proceed as usual. |
| ≥ 50% | **Feature deploy freeze.** Only reliability fixes, security patches, and rollbacks are permitted until the budget recovers below 50% or the window rolls forward enough to restore headroom. |
| ≥ 75% | Freeze extends to all non-critical changes. Incident review required before any further deploy. On-call escalates to service owner. |
| 100% (budget exhausted) | Full change freeze. Only rollback / hotfix for the causing incident is allowed. Post-incident review mandatory before freeze is lifted. |

Freeze/unfreeze decisions are made by the service owner and recorded in the team's change log. The freeze applies to the CodePipeline `awsome-fastapi` release stage — a freeze means **Release change** is not clicked, not a change to pipeline code itself.

## 6. Reporting

- Error budget burn and SLO compliance are visualized on the **Golden Signals** Grafana dashboard ([`monitoring/dashboards/golden-signals-dashboard.json`](../monitoring/dashboards/golden-signals-dashboard.json)), including an SLO compliance gauge.
- Burn-rate alerts notify via Alertmanager email routing (see [`monitoring/alerts/alertmanager-config.yaml`](../monitoring/alerts/alertmanager-config.yaml)).
- App and alert metrics are additionally shipped off-cluster to Grafana Cloud via `remote_write` (see [`monitoring/values.yaml`](../monitoring/values.yaml) and [`monitoring/remote-write-secret.yaml`](../monitoring/remote-write-secret.yaml)) so 30-day SLO history survives past the 7-day local Prometheus retention.
- Incident response steps for each alert are documented in [`docs/RUNBOOK.md`](RUNBOOK.md).

## 7. Out of scope

- Multi-region failover SLOs (single-region architecture; see README cost guidance).
- Data durability / backup SLOs (service is stateless).
- Third-party dependency SLOs (ECR, Terraform Cloud, GitHub availability are assumed and not separately tracked here).
