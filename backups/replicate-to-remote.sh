#!/bin/bash
# Replicate backups to remote location via rsync
set -euo pipefail
# Resolve the invoking user's home and this repository's root. Under sudo,
# $HOME is /root, so fall back to $SUDO_USER before trusting it. Both may be
# overridden: SPECTRE_HOME=/srv/secure SPECTRE_REPO=/opt/spectre-security
_spectre_here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SPECTRE_HOME="${SPECTRE_HOME:-$(getent passwd "${SUDO_USER:-$USER}" 2>/dev/null | cut -d: -f6)}"
SPECTRE_HOME="${SPECTRE_HOME:-$HOME}"
SPECTRE_REPO="${SPECTRE_REPO:-$(git -C "$_spectre_here" rev-parse --show-toplevel 2>/dev/null || echo "$_spectre_here")}"

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
        -e "ssh -i ${SPECTRE_HOME}/.ssh/backup_rsync -o StrictHostKeyChecking=accept-new" \
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
