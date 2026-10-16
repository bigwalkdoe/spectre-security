#!/bin/bash
# Main Maintenance Orchestration Script
# Runs all maintenance tasks and generates reports

# Resolve the invoking user's home and this repository's root. Under sudo,
# $HOME is /root, so fall back to $SUDO_USER before trusting it. Both may be
# overridden: SPECTRE_HOME=/srv/secure SPECTRE_REPO=/opt/spectre-security
_spectre_here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SPECTRE_HOME="${SPECTRE_HOME:-$(getent passwd "${SUDO_USER:-$USER}" 2>/dev/null | cut -d: -f6)}"
SPECTRE_HOME="${SPECTRE_HOME:-$HOME}"
SPECTRE_REPO="${SPECTRE_REPO:-$(git -C "$_spectre_here" rev-parse --show-toplevel 2>/dev/null || echo "$_spectre_here")}"
MAINTENANCE_LOG="/var/log/maintenance.log"
DATE=$(date +%Y%m%d_%H%M%S)

echo "==========================================" >> "$MAINTENANCE_LOG"
echo "Starting System Maintenance: $DATE" >> "$MAINTENANCE_LOG"
echo "==========================================" >> "$MAINTENANCE_LOG"

# Make scripts executable
chmod +x ${SPECTRE_REPO}/maintenance/*.sh

# Run system cleanup
echo "Running system cleanup..." >> "$MAINTENANCE_LOG"
${SPECTRE_REPO}/maintenance/cleanup-system.sh >> "$MAINTENANCE_LOG" 2>&1
CLEANUP_STATUS=$?

# Run log cleanup
echo "Running log cleanup..." >> "$MAINTENANCE_LOG"
sudo ${SPECTRE_REPO}/maintenance/cleanup-logs.sh >> "$MAINTENANCE_LOG" 2>&1
LOG_STATUS=$?

# Run health check
echo "Running system health check..." >> "$MAINTENANCE_LOG"
${SPECTRE_REPO}/maintenance/system-health-check.sh >> "$MAINTENANCE_LOG" 2>&1
HEALTH_STATUS=$?

# Generate summary
echo "==========================================" >> "$MAINTENANCE_LOG"
echo "Maintenance Summary - $DATE" >> "$MAINTENANCE_LOG"
echo "System cleanup: $([ $CLEANUP_STATUS -eq 0 ] && echo 'SUCCESS' || echo 'FAILED')" >> "$MAINTENANCE_LOG"
echo "Log cleanup: $([ $LOG_STATUS -eq 0 ] && echo 'SUCCESS' || echo 'FAILED')" >> "$MAINTENANCE_LOG"
echo "Health check: $([ $HEALTH_STATUS -eq 0 ] && echo 'SUCCESS' || echo 'FAILED')" >> "$MAINTENANCE_LOG"
echo "Current disk usage:" >> "$MAINTENANCE_LOG"
df -h / >> "$MAINTENANCE_LOG"
echo "==========================================" >> "$MAINTENANCE_LOG"

# Send notification if any maintenance failed
if [ $CLEANUP_STATUS -ne 0 ] || [ $LOG_STATUS -ne 0 ] || [ $HEALTH_STATUS -ne 0 ]; then
    logger -p user.error "System maintenance completed with errors - check $MAINTENANCE_LOG"
    if [ -n "$DISPLAY" ]; then
        notify-send "Maintenance Error" "Some maintenance tasks failed - check logs" -u critical
    fi
else
    logger -p user.info "System maintenance completed successfully"
    if [ -n "$DISPLAY" ]; then
        notify-send "Maintenance Complete" "All maintenance tasks completed successfully"
    fi
fi

echo "System maintenance completed: $DATE"
