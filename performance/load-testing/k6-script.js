// k6 load test script for API endpoint performance testing
// Run: k6 run --vus 10 --duration 30s k6-script.js

import http from 'k6/http';
import { sleep, check } from 'k6';
import { Rate, Trend } from 'k6/metrics';

// Custom metrics
const errorRate = new Rate('errors');
const responseTime = new Trend('response_time');

export const options = {
  stages: [
    { duration: '30s', target: 20 },   // Ramp up to 20 users
    { duration: '1m', target: 20 },    // Stay at 20 users
    { duration: '30s', target: 50 },   // Ramp up to 50 users
    { duration: '2m', target: 50 },    // Stay at 50 users
    { duration: '30s', target: 0 },    // Ramp down
  ],
  thresholds: {
    http_req_duration: ['p(95)<500'],  // 95% of requests under 500ms
    errors: ['rate<0.1'],              // Less than 10% error rate
  },
};

const BASE_URL = __ENV.BASE_URL || 'http://localhost:3000';

export default function () {
  const payload = JSON.stringify({
    query: 'test query',
    timestamp: Date.now(),
  });

  const params = {
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${__ENV.API_KEY || 'test-key'}`,
    },
    timeout: '10s',
  };

  // Test API health endpoint
  const healthResponse = http.get(`${BASE_URL}/health`, params);
  check(healthResponse, {
    'health endpoint responded with 200': (r) => r.status === 200,
  });
  responseTime.add(healthResponse.timings.duration);
  errorRate.add(healthResponse.status !== 200);

  // Test API query endpoint
  const queryResponse = http.post(`${BASE_URL}/api/query`, payload, params);
  check(queryResponse, {
    'query endpoint responded with 200': (r) => r.status === 200,
    'response time < 2s': (r) => r.timings.duration < 2000,
  });
  responseTime.add(queryResponse.timings.duration);
  errorRate.add(queryResponse.status !== 200);

  // Test static content
  const staticResponse = http.get(`${BASE_URL}/`);
  check(staticResponse, {
    'static content loaded': (r) => r.status === 200,
  });

  sleep(1);
}

export function handleSummary(data) {
  return {
    'stdout': textSummary(data, { indent: '  ', enableColors: true }),
    'reports/load-test-summary.json': JSON.stringify(data, null, 2),
  };
}

function textSummary(data, options) {
  const { metrics } = data;
  let report = '\n=== Load Test Results ===\n\n';
  
  report += `Test duration: ${data.state.testRunDurationMs / 1000}s\n`;
  report += `Virtual users: ${data.state.vusMax}\n\n`;
  
  for (const [name, metric] of Object.entries(metrics)) {
    if (metric.type === 'rate') {
      report += `${name}: ${(metric.values.rate * 100).toFixed(2)}%\n`;
    } else if (metric.type === 'trend') {
      report += `${name}:\n`;
      report += `  avg: ${metric.values.avg.toFixed(2)}ms\n`;
      report += `  p(95): ${metric.values['p(95)'].toFixed(2)}ms\n`;
      report += `  p(99): ${metric.values['p(99)'].toFixed(2)}ms\n`;
    }
  }
  
  report += '\n=== Test Complete ===\n';
  return report;
}
