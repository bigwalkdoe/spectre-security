#!/bin/bash
# Security Baseline HTTP Exporter
# Serves Prometheus metrics on HTTP endpoint

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PORT="${PORT:-9100}"
METRICS_FILE="/tmp/security-baseline-metrics.prom"

# Start the exporter loop
echo "Starting Security Baseline HTTP Exporter on port $PORT..."

while true; do
    # Run the exporter to generate metrics
    "$SCRIPT_DIR/security-baseline-exporter.sh" > /dev/null 2>&1 || true
    
    # Serve metrics via netcat (simple HTTP server)
    if [ -f /tmp/security-baseline-metrics.prom ]; then
        cat << EOF | nc -l -p "$PORT" -q 1 > /dev/null 2>&1 || true
HTTP/1.1 200 OK
Content-Type: text/plain; version=0.0.4
Content-Length: $(wc -c < /tmp/security-baseline-metrics.prom)

$(cat /tmp/security-baseline-metrics.prom)
EOF
    else
        cat << EOF | nc -l -p "$PORT" -q 1 > /dev/null 2>&1 || true
HTTP/1.1 200 OK
Content-Type: text/plain; version=0.0.4
Content-Length: 0

EOF
    fi
    
    sleep 5
done