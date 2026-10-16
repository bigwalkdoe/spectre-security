#!/bin/bash
# Setup automated backup cron jobs
set -euo pipefail
# Resolve the invoking user's home and this repository's root. Under sudo,
# $HOME is /root, so fall back to $SUDO_USER before trusting it. Both may be
# overridden: SPECTRE_HOME=/srv/secure SPECTRE_REPO=/opt/spectre-security
_spectre_here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SPECTRE_HOME="${SPECTRE_HOME:-$(getent passwd "${SUDO_USER:-$USER}" 2>/dev/null | cut -d: -f6)}"
SPECTRE_HOME="${SPECTRE_HOME:-$HOME}"
SPECTRE_REPO="${SPECTRE_REPO:-$(git -C "$_spectre_here" rev-parse --show-toplevel 2>/dev/null || echo "$_spectre_here")}"

echo "=== Automated Backup Cron Setup ==="
echo ""

CRON_ENTRIES=(
"# Automated Database Backups - Daily at 1:00 AM"
"0 1 * * * ${SPECTRE_REPO}/backups/backup-databases.sh"
""
"# Weekly Full Backups - Saturday at 2:00 AM"
"0 2 * * 6 ${SPECTRE_REPO}/backups/backup-all.sh"
""
"# Daily Docker Volume Backups - at 3:00 AM"
"0 3 * * * ${SPECTRE_REPO}/backups/backup-docker-volumes.sh"
)

CURRENT_CRON=$(crontab -l 2>/dev/null || echo "")

if echo "$CURRENT_CRON" | grep -q "backup-databases.sh"; then
    echo "Backup cron jobs already exist. Updating..."
    (echo "$CURRENT_CRON" | grep -v "backup-databases.sh\|backup-all.sh\|backup-docker-volumes.sh")
fi

NEW_CRON="$CURRENT_CRON

# === System Maintenance Backup Schedule ===
# Daily database backups at 1:00 AM
0 1 * * * ${SPECTRE_REPO}/backups/backup-databases.sh

# Weekly full backups on Saturday at 2:00 AM
0 2 * * 6 ${SPECTRE_REPO}/backups/backup-all.sh

# Daily Docker volume backups at 3:00 AM
0 3 * * * ${SPECTRE_REPO}/backups/backup-docker-volumes.sh
"

echo "$NEW_CRON" | crontab -

echo "Backup cron jobs installed successfully!"
echo ""
echo "Schedule:"
echo "  - Database backups: Daily at 1:00 AM"
echo "  - Full backups: Saturday at 2:00 AM"
echo "  - Docker volume backups: Daily at 3:00 AM"
echo ""
echo "Current crontab:"
echo "----------------------------------------"
crontab -l
echo "----------------------------------------"
