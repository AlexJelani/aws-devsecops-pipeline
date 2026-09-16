# Load Test Results — awsome-fastapi

Template for recording k6 load test runs against [`loadtest/loadtest.js`](../loadtest/loadtest.js). Copy the table below for each run and fill in observed values.

## Run metadata

| Field | Value |
|---|---|
| Date | YYYY-MM-DD |
| Target (`BASE_URL`) | `http://<load-balancer-dns>` |
| Cluster / node group size | e.g. `dsb-devsecops-cluster`, 2x t3.medium |
| App replica count at start | e.g. 2 |
| k6 version | `k6 version` output |
| Command | `BASE_URL=http://<lb-dns> k6 run loadtest/loadtest.js` |

## Stage-by-stage observations

| Stage (target RPS) | Duration | p50 latency | p95 latency | p99 latency | Error rate | Notes |
|---|---|---|---|---|---|---|
| 0 → 100 | 2m | | | | | |
| 100 (hold) | 3m | | | | | |
| 100 → 400 | 2m | | | | | |
| 400 (hold) | 3m | | | | | |
| 400 → 800 | 2m | | | | | |
| 800 (hold) | 3m | | | | | |
| 800 → 0 | 1m | | | | | |

## SLO threshold breach point

- **RPS at which p95 latency first exceeded 500ms:** _fill in_
- **RPS at which error rate first exceeded 1%:** _fill in_
- **k6 threshold result (`http_req_duration p(95)<500`, `http_req_failed rate<0.01`):** PASS / FAIL

## Autoscaling behavior

- **Did an HPA scale the deployment during the test?** yes / no
- **Replica count over time:** _e.g. 2 → 4 → 6 pods as RPS increased_
- **Command used to observe scaling:**
  ```bash
  kubectl -n default get hpa awsome-fastapi --watch
  kubectl -n default get pods -l app=awsome-fastapi --watch
  ```
- **Time to scale up from breach detection to new pods Ready:** _fill in_

## Node-level observations

- **Node CPU/memory utilization at peak RPS:**
  ```bash
  kubectl top nodes
  ```
  _paste output or summary here_
- **Any `NodePressure` alerts fired?** yes / no

## Follow-up actions

- [ ] File ticket to tune HPA thresholds / min-max replicas if scale-up was too slow.
- [ ] Adjust resource requests/limits if CPU throttling observed below expected RPS.
- [ ] Update `docs/SLO.md` error budget policy if this test revealed the SLO target is unrealistic for current infrastructure sizing.
- [ ] Re-run after any mitigation to confirm improvement.
