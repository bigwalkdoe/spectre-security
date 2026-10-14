#!/bin/bash
# Setup load testing infrastructure
set -euo pipefail

echo "=== Load Testing Setup ==="

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
mkdir -p "$SCRIPT_DIR/reports"

# Install k6
setup_k6() {
    echo "[1/3] Setting up k6..."
    if ! command -v k6 >/dev/null 2>&1; then
        sudo dnf install -y k6 2>/dev/null || {
            curl -s https://dl.k6.io/key.gpg | sudo apt-key add - 2>/dev/null || true
            echo "deb https://dl.k6.io/deb stable main" | sudo tee /etc/apt/sources.list.d/k6.list 2>/dev/null || true
            sudo apt-get update 2>/dev/null && sudo apt-get install -y k6 2>/dev/null || {
                echo "Installing k6 from GitHub..."
                wget -q https://github.com/grafana/k6/releases/download/v0.49.0/k6-v0.49.0-linux-amd64.tar.gz -O /tmp/k6.tar.gz
                tar -xzf /tmp/k6.tar.gz -C /tmp
                sudo mv /tmp/k6-v0.49.0-linux-amd64/k6 /usr/local/bin/
                chmod +x /usr/local/bin/k6
            }
        }
    fi
    echo "  k6 installed: $(k6 version 2>/dev/null || echo 'ok')"
}

# Install Locust
setup_locust() {
    echo "[2/3] Setting up Locust..."
    if ! command -v locust >/dev/null 2>&1; then
        pip install locust 2>/dev/null || pip3 install locust 2>/dev/null || true
    fi
    echo "  Locust installed: $(locust --version 2>/dev/null || echo 'ok')"
}

# Create run scripts
setup_scripts() {
    echo "[3/3] Creating load test scripts..."

    # k6 run script
    cat > "$SCRIPT_DIR/run-k6-test.sh" << 'K6_RUN'
#!/bin/bash
# Run k6 load test
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPORT_DIR="$SCRIPT_DIR/reports"
mkdir -p "$REPORT_DIR"

TARGET_URL="${1:-http://localhost:3000}"
VUS="${2:-10}"
DURATION="${3:-30s}"

DATE=$(date +%Y%m%d_%H%M%S)
REPORT_FILE="$REPORT_DIR/k6-report-$DATE.html"

echo "=== k6 Load Test ==="
echo "Target: $TARGET_URL"
echo "Virtual Users: $VUS"
echo "Duration: $DURATION"
echo ""

k6 run \
    --vus "$VUS" \
    --duration "$DURATION" \
    --out json="$REPORT_DIR/k6-results-$DATE.json" \
    --summary-export="$REPORT_DIR/k6-summary-$DATE.json" \
    -e BASE_URL="$TARGET_URL" \
    "$SCRIPT_DIR/k6-script.js"

echo ""
echo "Report saved: $REPORT_DIR/k6-report-$DATE.html"
K6_RUN
    chmod +x "$SCRIPT_DIR/run-k6-test.sh"

    # Locust run script
    cat > "$SCRIPT_DIR/run-locust-test.sh" << 'LOCUST_RUN'
#!/bin/bash
# Run Locust load test
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPORT_DIR="$SCRIPT_DIR/reports"
mkdir -p "$REPORT_DIR"

TARGET_URL="${1:-http://localhost:3000}"
USERS="${2:-10}"
SPAWN_RATE="${3:-1}"
RUN_TIME="${4:-60s}"

DATE=$(date +%Y%m%d_%H%M%S)

echo "=== Locust Load Test ==="
echo "Target: $TARGET_URL"
echo "Users: $USERS"
echo "Spawn Rate: $SPAWN_RATE/s"
echo "Run Time: $RUN_TIME"
echo ""

# Run in headless mode
locust \
    --headless \
    --host="$TARGET_URL" \
    --users="$USERS" \
    --spawn-rate="$SPAWN_RATE" \
    --run-time="$RUN_TIME" \
    --csv="$REPORT_DIR/locust-results-$DATE" \
    --html="$REPORT_DIR/locust-report-$DATE.html" \
    -f "$SCRIPT_DIR/locustfile.py"

echo ""
echo "Report saved: $REPORT_DIR/locust-report-$DATE.html"
LOCUST_RUN
    chmod +x "$SCRIPT_DIR/run-locust-test.sh"

    echo "  Run scripts created"
}

# Create performance regression test
cat > "$SCRIPT_DIR/run-performance-regression.sh" << 'REGRESSION'
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
REGRESSION
chmod +x "$SCRIPT_DIR/run-performance-regression.sh"

# Create capacity planning script
cat > "$SCRIPT_DIR/capacity-planning.sh" << 'CAPACITY'
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
CAPACITY
chmod +x "$SCRIPT_DIR/capacity-planning.sh"

# Run setups
setup_k6
setup_locust
setup_scripts

echo ""
echo "=== Load Testing Setup Complete ==="
echo ""
echo "Usage:"
echo "  k6 test:     $SCRIPT_DIR/run-k6-test.sh [url] [vus] [duration]"
echo "  Locust test: $SCRIPT_DIR/run-locust-test.sh [url] [users] [rate] [time]"
echo "  Regression:  $SCRIPT_DIR/run-performance-regression.sh [url]"
echo "  Capacity:    $SCRIPT_DIR/capacity-planning.sh"
echo ""
echo "Test scripts: k6-script.js, locustfile.py"
echo "Reports: $SCRIPT_DIR/reports/"
