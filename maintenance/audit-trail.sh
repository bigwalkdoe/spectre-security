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
