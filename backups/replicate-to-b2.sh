#!/bin/bash
# Replicate backups to Backblaze B2
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_DIR="$SCRIPT_DIR/../logs"
LOG_FILE="$LOG_DIR/backup-b2-replication.log"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p "$LOG_DIR"

CONFIG_FILE="/home/deon/.secrets/backup-config.env"
[ -f "$CONFIG_FILE" ] && source "$CONFIG_FILE"

{
    if [ -z "${B2_BUCKET:-}" ]; then
        echo "ERROR: B2_BUCKET not configured. Edit $CONFIG_FILE and set B2_BUCKET."
        echo "B2 replication not attempted"
        exit 1
    fi

    echo "=========================================="
    echo "B2 Backup Replication - $DATE"
    echo "=========================================="

    /usr/local/bin/b2 sync --delete /backups/ "b2://$B2_BUCKET/backups/"

    B2_EXIT=$?
    if [ $B2_EXIT -eq 0 ]; then
        echo "B2 replication completed successfully"
        logger -p user.info "B2 backup replication completed"
    else
        echo "B2 replication FAILED (exit: $B2_EXIT)"
        logger -p user.error "B2 backup replication failed"
    fi

    echo "B2 replication completed: $DATE"
} >> "$LOG_FILE" 2>&1
