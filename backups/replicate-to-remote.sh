#!/bin/bash
# Replicate backups to remote location via rsync
set -euo pipefail

REMOTE_HOST="165.227.87.180"
REMOTE_USER="root"
REMOTE_PATH="/backups/replica"
BACKUP_DIR="/backups"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_DIR="$SCRIPT_DIR/../logs"
LOG_FILE="$LOG_DIR/backup-replication.log"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p "$LOG_DIR"

{
    echo "=========================================="
    echo "Backup Replication - $DATE"
    echo "=========================================="

    rsync -avz --progress \
        --partial \
        --bwlimit=50000 \
        --delete \
        --delete-excluded \
        --exclude='*.tmp' \
        -e "ssh -i /home/deon/.ssh/backup_rsync -o StrictHostKeyChecking=accept-new" \
        "$BACKUP_DIR/" \
        "$REMOTE_USER@$REMOTE_HOST:$REMOTE_PATH/"

    RSYNC_EXIT=$?

    if [ $RSYNC_EXIT -eq 0 ]; then
        echo "Backup replication completed successfully"
        logger -p user.info "Off-site backup replication completed"
    else
        echo "Backup replication FAILED (exit: $RSYNC_EXIT)"
        logger -p user.error "Off-site backup replication failed"
    fi

    echo "Replication completed: $DATE"
} >> "$LOG_FILE" 2>&1
