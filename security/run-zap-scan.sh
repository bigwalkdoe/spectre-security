#!/bin/bash
# OWASP ZAP automated security scan
set -euo pipefail

ZAP_URL="http://localhost:8080"
REPORT_DIR="[REDACTED_PATH]/scripts/security/reports"
DATE=$(date +%Y%m%d_%H%M%S)
mkdir -p "$REPORT_DIR"

TARGET_URL="${1:-http://localhost:3000}"

echo "=== OWASP ZAP Security Scan ==="
echo "Target: $TARGET_URL"
echo ""

# Wait for ZAP to be ready
echo "Waiting for ZAP to be ready..."
for i in $(seq 1 30); do
    if curl -s "$ZAP_URL" >/dev/null 2>&1; then
        echo "ZAP is ready"
        break
    fi
    sleep 2
done

# Run spider scan
echo "Running spider scan on $TARGET_URL..."
curl -s "$ZAP_URL/JSON/spider/action/scan/?url=$TARGET_URL&maxChildren=10" >/dev/null

# Run active scan
echo "Running active scan..."
curl -s "$ZAP_URL/JSON/ascan/action/scan/?url=$TARGET_URL&recurse=true" >/dev/null

# Wait for scan to complete
echo "Waiting for scan to complete..."
sleep 30

# Generate HTML report
echo "Generating report..."
curl -s "$ZAP_URL/OTHER/core/other/htmlreport/" > "$REPORT_DIR/zap_report_$DATE.html"

# Generate JSON report
curl -s "$ZAP_URL/JSON/core/view/alerts/" > "$REPORT_DIR/zap_alerts_$DATE.json"

# Get alert summary
ALERT_COUNT=$(curl -s "$ZAP_URL/JSON/core/view/numberOfAlerts/" | python3 -c "import sys,json;print(json.load(sys.stdin).get('numberOfAlerts',0))" 2>/dev/null || echo 0)
echo ""
echo "=== Scan Summary ==="
echo "Alerts found: $ALERT_COUNT"
echo "Report saved: $REPORT_DIR/zap_report_$DATE.html"
echo ""
if [ "$ALERT_COUNT" -gt 0 ]; then
    echo "High risk alerts:"
    curl -s "$ZAP_URL/JSON/core/view/alerts/?risk=High" | python3 -m json.tool 2>/dev/null | grep -A2 '"alert"' || true
fi

echo "ZAP scan completed: $DATE"
