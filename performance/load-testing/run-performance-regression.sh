#!/bin/bash
# Automated performance regression testing
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPORT_DIR="$SCRIPT_DIR/reports"
BASELINE_FILE="$SCRIPT_DIR/.baseline-metrics"

DATE=$(date +%Y%m%d_%H%M%S)
TARGET_URL="${1:-http://localhost:3000}"

echo "=== Performance Regression Test - $DATE ==="

# Run k6 test
echo "Running baseline load test..."
k6 run \
    --vus 5 \
    --duration 30s \
    --summary-export="$REPORT_DIR/regression-$DATE.json" \
    -e BASE_URL="$TARGET_URL" \
    "$SCRIPT_DIR/k6-script.js" > /dev/null 2>&1

# Extract key metrics
P95=$(jq '.metrics.http_req_duration.values."p(95)"' "$REPORT_DIR/regression-$DATE.json" 2>/dev/null || echo 0)
ERROR_RATE=$(jq '.metrics.errors.values.rate' "$REPORT_DIR/regression-$DATE.json" 2>/dev/null || echo 0)

echo "P95 Response Time: ${P95}ms"
echo "Error Rate: $(echo "$ERROR_RATE * 100" | bc -l)%"

# Compare with baseline
if [ -f "$BASELINE_FILE" ]; then
    source "$BASELINE_FILE"
    echo ""
    echo "Comparing with baseline..."
    
    if (( $(echo "$P95 > $BASELINE_P95 * 1.2" | bc -l) )); then
        echo "FAIL: P95 response time degraded (${P95}ms vs baseline ${BASELINE_P95}ms)"
        exit 1
    fi
    
    if (( $(echo "$ERROR_RATE > $BASELINE_ERROR_RATE * 1.5" | bc -l) )); then
        echo "FAIL: Error rate increased ($(echo "$ERROR_RATE * 100" | bc -l)% vs baseline $(echo "$BASELINE_ERROR_RATE * 100" | bc -l)%)"
        exit 1
    fi
    
    echo "PASS: All metrics within baseline thresholds"
else
    echo "No baseline found. Saving current metrics as baseline."
    echo "BASELINE_P95=$P95" > "$BASELINE_FILE"
    echo "BASELINE_ERROR_RATE=$ERROR_RATE" >> "$BASELINE_FILE"
fi

echo "Regression test completed"
