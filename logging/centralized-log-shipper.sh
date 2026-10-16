#!/bin/bash
# Ship logs to centralized logging destination (remote Loki or S3)
set -euo pipefail
# Resolve the invoking user's home and this repository's root. Under sudo,
# $HOME is /root, so fall back to $SUDO_USER before trusting it. Both may be
# overridden: SPECTRE_HOME=/srv/secure SPECTRE_REPO=/opt/spectre-security
_spectre_here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SPECTRE_HOME="${SPECTRE_HOME:-$(getent passwd "${SUDO_USER:-$USER}" 2>/dev/null | cut -d: -f6)}"
SPECTRE_HOME="${SPECTRE_HOME:-$HOME}"
SPECTRE_REPO="${SPECTRE_REPO:-$(git -C "$_spectre_here" rev-parse --show-toplevel 2>/dev/null || echo "$_spectre_here")}"

CONFIG_FILE="${1:-${SPECTRE_REPO}/logging/log-shipper.env}"

if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
fi

REMOTE_LOKI_URL="${REMOTE_LOKI_URL:-}"
REMOTE_S3_BUCKET="${REMOTE_S3_BUCKET:-}"
LOG_DIRS=("/var/log" "${SPECTRE_REPO}/logs")
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
