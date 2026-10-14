#!/bin/bash
# Setup automated backup cron jobs
set -euo pipefail

echo "=== Automated Backup Cron Setup ==="
echo ""

CRON_ENTRIES=(
"# Automated Database Backups - Daily at 1:00 AM"
"0 1 * * * [REDACTED_PATH]/scripts/backups/backup-databases.sh"
""
"# Weekly Full Backups - Saturday at 2:00 AM"
"0 2 * * 6 [REDACTED_PATH]/scripts/backups/backup-all.sh"
""
"# Daily Docker Volume Backups - at 3:00 AM"
"0 3 * * * [REDACTED_PATH]/scripts/backups/backup-docker-volumes.sh"
)

CURRENT_CRON=$(crontab -l 2>/dev/null || echo "")

if echo "$CURRENT_CRON" | grep -q "backup-databases.sh"; then
    echo "Backup cron jobs already exist. Updating..."
    (echo "$CURRENT_CRON" | grep -v "backup-databases.sh\|backup-all.sh\|backup-docker-volumes.sh")
fi

NEW_CRON="$CURRENT_CRON

# === System Maintenance Backup Schedule ===
# Daily database backups at 1:00 AM
0 1 * * * [REDACTED_PATH]/scripts/backups/backup-databases.sh

# Weekly full backups on Saturday at 2:00 AM
0 2 * * 6 [REDACTED_PATH]/scripts/backups/backup-all.sh

# Daily Docker volume backups at 3:00 AM
0 3 * * * [REDACTED_PATH]/scripts/backups/backup-docker-volumes.sh
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
