#!/bin/bash
# Capacity planning based on load test metrics
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPORT_DIR="$SCRIPT_DIR/reports"

echo "=== Capacity Planning ==="

# Check system resources
TOTAL_MEM=$(free -m | awk '/Mem:/ {print $2}')
TOTAL_CPU=$(nproc)
DISK_SPACE=$(df -h / | tail -1 | awk '{print $4}')

echo "Current system capacity:"
echo "  CPU cores: $TOTAL_CPU"
echo "  Memory: ${TOTAL_MEM}MB"
echo "  Disk: $DISK_SPACE"

# Analyze load test results
LATEST_REPORT=$(ls -t "$REPORT_DIR"/k6-summary-*.json 2>/dev/null | head -1)
if [ -n "$LATEST_REPORT" ] && [ -f "$LATEST_REPORT" ]; then
    P95=$(jq '.metrics.http_req_duration.values."p(95)"' "$LATEST_REPORT" 2>/dev/null || echo 0)
    MAX_VUS=$(jq '.state.vusMax' "$LATEST_REPORT" 2>/dev/null || echo 0)
    REQ_RATE=$(jq '.metrics.http_reqs.values.rate' "$LATEST_REPORT" 2>/dev/null || echo 0)
    
    echo ""
    echo "Load test results from: $(basename $LATEST_REPORT)"
    echo "  Max virtual users: $MAX_VUS"
    echo "  Request rate: $(printf "%.0f" $REQ_RATE)/s"
    echo "  P95 response time: $(printf "%.0f" $P95)ms"
    
    # Capacity recommendations
    if (( $(echo "$P95 > 1000" | bc -l) )); then
        echo ""
        echo "RECOMMENDATION: Scale up - P95 response time exceeds 1s"
        echo "  Consider adding more application instances"
        echo "  Current capacity ($MAX_VUS concurrent users) may be insufficient"
    elif (( $(echo "$P95 > 500" | bc -l) )); then
        echo ""
        echo "RECOMMENDATION: Monitor - P95 response time approaching threshold"
        echo "  Current capacity (~$MAX_VUS concurrent users) is adequate"
    else
        echo ""
        echo "CAPACITY: Adequate for current load (~$MAX_VUS concurrent users)"
    fi
fi
