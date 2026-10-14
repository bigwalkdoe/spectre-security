#!/bin/bash
# Regular compliance report generator
set -euo pipefail

REPORT_DIR="[REDACTED_PATH]/scripts/maintenance/reports"
mkdir -p "$REPORT_DIR"
DATE=$(date +%Y%m%d)

echo "=== Compliance Report - $DATE ===" > "$REPORT_DIR/compliance-$DATE.md"

# 1. Backup verification
echo "" >> "$REPORT_DIR/compliance-$DATE.md"
echo "## Backup Status" >> "$REPORT_DIR/compliance-$DATE.md"
echo "- Last database backup: $(ls -t /backups/databases/ 2>/dev/null | head -1)" >> "$REPORT_DIR/compliance-$DATE.md"
echo "- Last full backup: $(ls -t /backups/docker-volumes/ 2>/dev/null | head -1)" >> "$REPORT_DIR/compliance-$DATE.md"
echo "- Backup size: $(du -sh /backups 2>/dev/null | cut -f1)" >> "$REPORT_DIR/compliance-$DATE.md"

# 2. Security status
echo "" >> "$REPORT_DIR/compliance-$DATE.md"
echo "## Security Status" >> "$REPORT_DIR/compliance-$DATE.md"
echo "- Fail2Ban status: $(sudo fail2ban-client status 2>/dev/null | head -1 || echo 'not running')" >> "$REPORT_DIR/compliance-$DATE.md"
echo "- AIDE last check: $(ls -t /var/log/aide/ 2>/dev/null | head -1)" >> "$REPORT_DIR/compliance-$DATE.md"
echo "- Running containers: $(docker ps -q 2>/dev/null | wc -l)" >> "$REPORT_DIR/compliance-$DATE.md"

# 3. System health
echo "" >> "$REPORT_DIR/compliance-$DATE.md"
echo "## System Health" >> "$REPORT_DIR/compliance-$DATE.md"
echo "- Uptime: $(uptime -p)" >> "$REPORT_DIR/compliance-$DATE.md"
echo "- CPU: $(top -bn1 | grep 'Cpu(s)' | awk '{print $2}')% used" >> "$REPORT_DIR/compliance-$DATE.md"
echo "- Memory: $(free -h | grep Mem | awk '{print $3 "/" $2}')" >> "$REPORT_DIR/compliance-$DATE.md"
echo "- Disk: $(df -h / | tail -1 | awk '{print $5}') used" >> "$REPORT_DIR/compliance-$DATE.md"

# 4. Monitoring status
echo "" >> "$REPORT_DIR/compliance-$DATE.md"
echo "## Monitoring Status" >> "$REPORT_DIR/compliance-$DATE.md"
for svc in prometheus grafana alertmanager; do
    if docker ps --format "{{.Names}}" 2>/dev/null | grep -q "$svc"; then
        echo "- $svc: Running" >> "$REPORT_DIR/compliance-$DATE.md"
    else
        echo "- $svc: NOT RUNNING" >> "$REPORT_DIR/compliance-$DATE.md"
    fi
done

# 5. Recent security events
echo "" >> "$REPORT_DIR/compliance-$DATE.md"
echo "## Recent Security Events (24h)" >> "$REPORT_DIR/compliance-$DATE.md"
sudo journalctl -u fail2ban --since "24 hours ago" --no-pager 2>/dev/null | tail -20 >> "$REPORT_DIR/compliance-$DATE.md" || true

echo "" >> "$REPORT_DIR/compliance-$DATE.md"
echo "---" >> "$REPORT_DIR/compliance-$DATE.md"
echo "Report generated: $(date)" >> "$REPORT_DIR/compliance-$DATE.md"

echo "Compliance report: $REPORT_DIR/compliance-$DATE.md"
