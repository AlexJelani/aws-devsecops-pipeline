// loadtest.js
//
// k6 load test for the awsome-fastapi service, ramping RPS to validate the
// SLOs defined in docs/SLO.md (p95 latency < 500ms, error rate < 1%).
//
// Usage:
//   BASE_URL=http://<load-balancer-dns> k6 run loadtest/loadtest.js
//
// Notes:
//   - "Main endpoints" here means the app's root ("/") health/hello endpoint,
//     since awsome-fastapi is currently a minimal FastAPI app. Add more
//     endpoints to the `endpoints` array below as the app grows.
//   - Stages ramp 0 -> 100 -> 400 -> 800 RPS using the "ramping-arrival-rate"
//     executor so load is defined in requests/sec rather than VUs, which
//     maps directly onto the SLO's request-rate-based SLIs.

import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate, Trend } from 'k6/metrics';

// --- Configuration -----------------------------------------------------
const BASE_URL = __ENV.BASE_URL || 'http://localhost:8080';

// Endpoints exercised by the test. Extend this list as the app grows beyond
// a single hello-world route.
const ENDPOINTS = ['/'];

// Custom metrics surfaced in the k6 summary alongside the built-ins.
const errorRate = new Rate('app_error_rate');
const latencyTrend = new Trend('app_latency_ms', true);

// --- Test configuration -------------------------------------------------
export const options = {
  scenarios: {
    ramping_traffic: {
      executor: 'ramping-arrival-rate',
      startRate: 0,
      timeUnit: '1s',
      preAllocatedVUs: 200,
      maxVUs: 1000,
      stages: [
        { target: 100, duration: '2m' }, // ramp 0 -> 100 RPS
        { target: 100, duration: '3m' }, // hold at 100 RPS
        { target: 400, duration: '2m' }, // ramp 100 -> 400 RPS
        { target: 400, duration: '3m' }, // hold at 400 RPS
        { target: 800, duration: '2m' }, // ramp 400 -> 800 RPS
        { target: 800, duration: '3m' }, // hold at 800 RPS
        { target: 0, duration: '1m' },   // ramp down
      ],
    },
  },
  // Thresholds tied directly to docs/SLO.md targets. k6 exits non-zero if
  // these are violated, so this test can gate a CI job if desired.
  thresholds: {
    http_req_duration: ['p(95)<500'], // SLO: p95 latency < 500ms
    http_req_failed: ['rate<0.01'],   // SLO: error rate < 1%
    app_error_rate: ['rate<0.01'],
  },
};

export default function () {
  const endpoint = ENDPOINTS[Math.floor(Math.random() * ENDPOINTS.length)];
  const res = http.get(`${BASE_URL}${endpoint}`, {
    tags: { endpoint },
  });

  const success = check(res, {
    'status is 200': (r) => r.status === 200,
    'no 5xx error': (r) => r.status < 500,
  });

  errorRate.add(!success);
  latencyTrend.add(res.timings.duration);

  // Small think-time to avoid unrealistic back-to-back requests per VU;
  // arrival-rate executor controls overall throughput regardless.
  sleep(0.1);
}

// Summary handler prints a concise pass/fail against the SLO thresholds when
// the run completes, in addition to k6's default end-of-test summary.
export function handleSummary(data) {
  const p95 = data.metrics.http_req_duration.values['p(95)'];
  const errRate = data.metrics.http_req_failed.values.rate;

  console.log('\n--- SLO Summary ---');
  console.log(`p95 latency: ${p95.toFixed(1)}ms (SLO: < 500ms) -> ${p95 < 500 ? 'PASS' : 'FAIL'}`);
  console.log(`error rate: ${(errRate * 100).toFixed(2)}% (SLO: < 1%) -> ${errRate < 0.01 ? 'PASS' : 'FAIL'}`);

  return {
    stdout: JSON.stringify(data, null, 2),
  };
}
