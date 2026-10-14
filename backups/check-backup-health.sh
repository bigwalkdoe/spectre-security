#!/bin/bash
# Monitor backup replication health and alert on failures
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_DIR="$SCRIPT_DIR/../logs"
REPLICATION_LOG="$LOG_DIR/backup-replication.log"
ALERTMANAGER_URL="http://localhost:9093/api/v2/alerts"
HOSTNAME=$(hostname)

mkdir -p "$LOG_DIR"

check_replication_log() {
    if [ ! -f "$REPLICATION_LOG" ]; then
        echo "ERROR: Replication log not found at $REPLICATION_LOG"
        return 2
    fi

    local last_run
    last_run=$(tac "$REPLICATION_LOG" | grep -m1 "Backup Replication - \|Backup Replication completed\|Backup replication FAILED")
    local exit_failures
    exit_failures=$(grep -c "Backup replication FAILED" "$REPLICATION_LOG" 2>/dev/null || echo 0)
    local recent_failures
    recent_failures=$(tail -50 "$REPLICATION_LOG" | grep -c "Backup replication FAILED\|error.*failed\|rsync error" 2>/dev/null || echo 0)
    local last_status
    last_status=$(tac "$REPLICATION_LOG" | grep -m1 -E "completed successfully|FAILED" || echo "UNKNOWN")

    if echo "$last_status" | grep -q "FAILED"; then
        return 1
    fi

    return 0
}

send_alertmanager_alert() {
    local status="$1"
    local message="$2"

    local alert_data
    alert_data=$(cat <<ALERT
{
    "labels": {
        "alertname": "BackupReplication",
        "severity": "$status",
        "instance": "$HOSTNAME",
        "job": "backup"
    },
    "annotations": {
        "summary": "Backup replication $status",
        "description": "$message"
    },
    "generatorURL": "file://$REPLICATION_LOG"
}
ALERT
)

    if command -v curl &>/dev/null; then
        curl -sf -X POST -H "Content-Type: application/json" \
            -d "[$alert_data]" "$ALERTMANAGER_URL" 2>/dev/null && \
            echo "Alert posted to Alertmanager" || \
            echo "Warning: Could not reach Alertmanager at $ALERTMANAGER_URL"
    fi
}

notify_desktop() {
    local urgency="$1"
    local message="$2"
    if command -v notify-send &>/dev/null && [ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ]; then
        notify-send -u "$urgency" "Backup Health" "$message" 2>/dev/null || true
    fi
}

check_replication_log
RC=$?

case $RC in
    0)
        logger -p user.info "Backup replication health check passed"
        notify_desktop "normal" "Backup replication OK"
        send_alertmanager_alert "info" "Backup replication completed successfully"
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Health check: OK" >> "$LOG_DIR/backup-health.log"
        ;;
    1)
        logger -p user.error "Backup replication FAILED - alert sent"
        notify_desktop "critical" "Backup replication FAILED - check logs"
        send_alertmanager_alert "critical" "Backup replication failed. Check $REPLICATION_LOG for details."
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Health check: FAILED" >> "$LOG_DIR/backup-health.log"
        ;;
    2)
        logger -p user.warning "Backup replication log not found"
        send_alertmanager_alert "warning" "Backup replication log not found at $REPLICATION_LOG"
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Health check: LOG MISSING" >> "$LOG_DIR/backup-health.log"
        ;;
esac

exit $RC
