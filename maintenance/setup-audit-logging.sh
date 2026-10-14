#!/bin/bash
# Centralized Audit Logging Setup
set -euo pipefail

echo "=== Centralized Audit Logging Setup ==="
echo ""

AUDIT_DIR="/var/log/audit"
mkdir -p "$AUDIT_DIR"
sudo chmod 750 "$AUDIT_DIR"

# 1. System audit logging
setup_auditd() {
    echo "[1/4] Configuring system audit logging..."
    
    if command -v auditd >/dev/null 2>&1; then
        sudo bash -c 'cat > /etc/audit/rules.d/system-maintenance.rules << "AUDIT_RULES"
# System Maintenance audit rules

# Monitor system administration
-w /etc/sudoers -p wa -k sudoers_changes
-w /etc/sudoers.d/ -p wa -k sudoers_changes

# Monitor user/group management
-w /etc/passwd -p wa -k user_changes
-w /etc/shadow -p wa -k user_changes
-w /etc/group -p wa -k group_changes

# Monitor SSH configuration
-w /etc/ssh/sshd_config -p wa -k sshd_config

# Monitor cron configuration
-w /etc/cron.d/ -p wa -k cron_changes
-w /etc/crontab -p wa -k cron_changes

# Monitor Docker daemon
-w /etc/docker/ -p wa -k docker_changes

# Monitor scripts
-w [REDACTED_PATH]/scripts/ -p wa -k script_changes

# Monitor system maintenance repo
-w [REDACTED_PATH]/dev/github/system-maintenance/ -p wa -k repo_changes

# Monitor system binaries
-w /usr/local/bin/ -p wa -k bin_changes

# Track all privileged commands
-a always,exit -F arch=b64 -S execve -F uid=0 -k root_commands

# Monitor network configuration changes
-w /etc/hosts -p wa -k hosts_changes
-w /etc/hostname -p wa -k hostname_changes

# Monitor firewall rules
-w /etc/firewalld/ -p wa -k firewall_changes
AUDIT_RULES'
        sudo systemctl restart auditd 2>/dev/null || echo "  auditd rules installed (restart auditd to apply)"
        echo "  System audit rules configured"
    else
        echo "  auditd not installed. On Fedora: sudo dnf install audit"
    fi
}

# 2. Centralized audit trail script
setup_audit_trail() {
    echo "[2/4] Creating centralized audit trail..."
    
    cat > [REDACTED_PATH]/scripts/maintenance/audit-trail.sh << 'AUDIT_TRAIL'
#!/bin/bash
# Centralized Audit Trail Generator
set -euo pipefail

AUDIT_LOG="/var/log/audit/audit-trail.log"
DATE=$(date +%Y%m%d_%H%M%S)

echo "==========================================" >> "$AUDIT_LOG"
echo "Audit Trail - $DATE" >> "$AUDIT_LOG"
echo "==========================================" >> "$AUDIT_LOG"

# System access log
echo "=== System Access ===" >> "$AUDIT_LOG"
last -10 >> "$AUDIT_LOG" 2>/dev/null || true

# Running processes
echo "=== Running Processes ===" >> "$AUDIT_LOG"
ps aux --sort=-%mem | head -20 >> "$AUDIT_LOG"

# Network connections
echo "=== Network Connections ===" >> "$AUDIT_LOG"
ss -tlnp >> "$AUDIT_LOG" 2>/dev/null || true

# Docker container status
echo "=== Docker Status ===" >> "$AUDIT_LOG"
docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}" >> "$AUDIT_LOG" 2>/dev/null || true

# File integrity
echo "=== Recent File Changes ===" >> "$AUDIT_LOG"
find /etc -mtime -1 -type f 2>/dev/null | head -20 >> "$AUDIT_LOG"

# Firewall status
echo "=== Firewall Status ===" >> "$AUDIT_LOG"
if command -v firewall-cmd >/dev/null 2>&1; then
    firewall-cmd --list-all >> "$AUDIT_LOG" 2>/dev/null || true
fi

# Audit logs from auditd (if available)
echo "=== Audit Events (last 100) ===" >> "$AUDIT_LOG"
sudo ausearch --start recent -ts recent 2>/dev/null | tail -100 >> "$AUDIT_LOG" 2>/dev/null || true

# System metrics
echo "=== System Metrics ===" >> "$AUDIT_LOG"
echo "Uptime: $(uptime)" >> "$AUDIT_LOG"
echo "Load: $(cat /proc/loadavg)" >> "$AUDIT_LOG"
echo "Memory: $(free -h | grep Mem)" >> "$AUDIT_LOG"
echo "Disk: $(df -h / | tail -1)" >> "$AUDIT_LOG"

echo "==========================================" >> "$AUDIT_LOG"

# Log shipping indicator
logger -p user.info "Audit trail generated: $DATE"
echo "Audit trail written to $AUDIT_LOG"
AUDIT_TRAIL
    chmod +x [REDACTED_PATH]/scripts/maintenance/audit-trail.sh
    echo "  Audit trail script created"
}

# 3. Compliance report generator
setup_compliance_reports() {
    echo "[3/4] Creating compliance report generator..."
    
    cat > [REDACTED_PATH]/scripts/maintenance/compliance-report.sh << 'COMPLIANCE'
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
COMPLIANCE
    chmod +x [REDACTED_PATH]/scripts/maintenance/compliance-report.sh
    echo "  Compliance report script created"
}

# 4. Access logging
setup_access_logging() {
    echo "[4/4] Setting up access logging..."
    
    # Configure sudo to log all commands
    sudo bash -c 'cat > /etc/sudoers.d/audit-sudo << "SUDO_AUDIT"
Defaults logfile=/var/log/sudo.log
Defaults log_input, log_output
Defaults iolog_dir=/var/log/sudo-io
Defaults passwd_tries=3
Defaults badpass_message="Incorrect password"
SUDO_AUDIT'
    sudo chmod 440 /etc/sudoers.d/audit-sudo
    echo "  Sudo command logging configured"

    # Create access review script
    cat > [REDACTED_PATH]/scripts/maintenance/review-access.sh << 'ACCESS'
#!/bin/bash
# Review user access and activity
set -euo pipefail

echo "=== Access Review ==="
echo ""

echo "Users with shell access:"
awk -F: '($3 >= 1000) && ($7 !~ /nologin|false/) {print $1 " (uid=" $3 ", shell=" $7 ")"}' /etc/passwd

echo ""
echo "Sudo users:"
getent group wheel 2>/dev/null || getent group sudo 2>/dev/null || echo "No sudo group found"

echo ""
echo "Docker group members:"
getent group docker 2>/dev/null | cut -d: -f4 || echo "No docker group"

echo ""
echo "Last logins (10 most recent):"
last -10 2>/dev/null || echo "No login records"

echo ""
echo "Currently logged in:"
who

echo ""
echo "Failed SSH attempts (last 50):"
sudo journalctl -u sshd --since "7 days ago" 2>/dev/null | grep "Failed password" | tail -50 || echo "No failed attempts recorded"
ACCESS
    chmod +x [REDACTED_PATH]/scripts/maintenance/review-access.sh
    echo "  Access review script created"
}

# Schedule audit trail and compliance reports
schedule_audit() {
    echo ""
    echo "Scheduling audit tasks..."
    
    if ! crontab -l 2>/dev/null | grep -q "audit-trail"; then
        (crontab -l 2>/dev/null
         echo "# Audit logging"
         echo "0 */6 * * * [REDACTED_PATH]/scripts/maintenance/audit-trail.sh"
         echo "0 8 * * 1 [REDACTED_PATH]/scripts/maintenance/compliance-report.sh"
         echo "0 9 * * 1 [REDACTED_PATH]/scripts/maintenance/review-access.sh"
        ) | crontab -
        echo "  Audit tasks scheduled"
    fi
}

# Run all
setup_auditd
echo ""
setup_audit_trail
echo ""
setup_compliance_reports
echo ""
setup_access_logging
echo ""
schedule_audit

echo ""
echo "=== Centralized Audit Logging Setup Complete ==="
echo ""
echo "Components installed:"
echo "  - System audit rules (auditd)"
echo "  - Centralized audit trail (every 6 hours)"
echo "  - Compliance reports (weekly)"
echo "  - Access review (weekly)"
echo "  - Sudo command logging"
echo ""
echo "Log locations:"
echo "  - Audit trail: /var/log/audit/audit-trail.log"
echo "  - Sudo commands: /var/log/sudo.log"
echo "  - Compliance: [REDACTED_PATH]/scripts/maintenance/reports/"
echo "  - Access review: run [REDACTED_PATH]/scripts/maintenance/review-access.sh"
