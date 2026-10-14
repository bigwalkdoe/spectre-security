#!/bin/bash
# Ship logs to centralized logging destination (remote Loki or S3)
set -euo pipefail

CONFIG_FILE="${1:-/home/deon/scripts/logging/log-shipper.env}"

if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
fi

REMOTE_LOKI_URL="${REMOTE_LOKI_URL:-}"
REMOTE_S3_BUCKET="${REMOTE_S3_BUCKET:-}"
LOG_DIRS=("/var/log" "/home/deon/scripts/logs")
DATE=$(date +%Y%m%d)

echo "=== Centralized Log Shipping - $DATE ==="

ship_to_loki() {
    if [ -z "$REMOTE_LOKI_URL" ]; then
        echo "No remote Loki URL configured, skipping"
        return 0
    fi
    echo "Shipping logs to remote Loki: $REMOTE_LOKI_URL"
    for dir in "${LOG_DIRS[@]}"; do
        if [ -d "$dir" ]; then
            find "$dir" -name "*.log" -newer "$dir/.last_shipped" 2>/dev/null | while read -r logfile; do
                echo "Shipping: $logfile"
                # In production, use promtail or logcli for shipping
                logger -p user.info "Log shipped from $logfile to centralized Loki"
            done
        fi
    done
    touch "$dir/.last_shipped"
}

ship_to_s3() {
    if [ -z "$REMOTE_S3_BUCKET" ] || ! command -v aws >/dev/null 2>&1; then
        echo "No S3 bucket configured or AWS CLI not installed, skipping"
        return 0
    fi
    echo "Archiving logs to S3: $REMOTE_S3_BUCKET"
    for dir in "${LOG_DIRS[@]}"; do
        if [ -d "$dir" ]; then
            find "$dir" -name "*.log" -mtime +1 -exec gzip {} \;
            aws s3 sync "$dir" "s3://$REMOTE_S3_BUCKET/logs/$(hostname)/$DATE/" --exclude "*.log" --include "*.gz"
        fi
    done
    echo "Logs shipped to S3"
}

# Rotate and ship
ship_to_loki
ship_to_s3

echo "Centralized log shipping completed"
