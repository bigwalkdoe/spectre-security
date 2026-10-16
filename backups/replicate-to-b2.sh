#!/bin/bash
# Replicate backups to Backblaze B2
set -uo pipefail
# Resolve the invoking user's home and this repository's root. Under sudo,
# $HOME is /root, so fall back to $SUDO_USER before trusting it. Both may be
# overridden: SPECTRE_HOME=/srv/secure SPECTRE_REPO=/opt/spectre-security
_spectre_here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SPECTRE_HOME="${SPECTRE_HOME:-$(getent passwd "${SUDO_USER:-$USER}" 2>/dev/null | cut -d: -f6)}"
SPECTRE_HOME="${SPECTRE_HOME:-$HOME}"
SPECTRE_REPO="${SPECTRE_REPO:-$(git -C "$_spectre_here" rev-parse --show-toplevel 2>/dev/null || echo "$_spectre_here")}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_DIR="$SCRIPT_DIR/../logs"
LOG_FILE="$LOG_DIR/backup-b2-replication.log"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p "$LOG_DIR"

CONFIG_FILE="${SPECTRE_HOME}/.secrets/backup-config.env"
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
