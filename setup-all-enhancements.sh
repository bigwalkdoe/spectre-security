#!/bin/bash
# Master setup script for all system maintenance enhancements
set -euo pipefail

echo "================================================================="
echo "  System Maintenance - Complete Enhancement Suite"
echo "================================================================="
echo ""
echo "This script will install and configure all enhancement items."
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

run_section() {
    local section="$1"
    local script="$2"
    echo ""
    echo "================================================================="
    echo "  [$section] $script"
    echo "================================================================="
    if [ -f "$script" ]; then
        bash "$script"
    else
        echo "  SKIP: Script not found: $script"
    fi
    echo ""
}

# ============================================================
# Section 1: Automated Backup Scheduling
# ============================================================
echo "Section 1: Automated Backup Scheduling"
run_section "1" "$SCRIPT_DIR/setup-backup-cron.sh"

# ============================================================
# Section 2: Centralized Logging
# ============================================================
echo "Section 2: Centralized Logging"
run_section "2" "$SCRIPT_DIR/logging/container-logrotate.sh"
echo "  - Loki stack configured at $SCRIPT_DIR/logging/docker-compose.loki.yml"
echo "  - Start with: docker-compose -f $SCRIPT_DIR/logging/docker-compose.loki.yml up -d"

# ============================================================
# Section 3: Enhanced Monitoring
# ============================================================
echo "Section 3: Enhanced Monitoring"
echo "  - Alertmanager configured with Slack/Email/PagerDuty"
echo "  - Blackbox exporter config at dev/github/system-maintenance/prometheus/"
echo "  - Business metrics exporter created"
echo "  - Uptime monitoring rules added"
if [ -f "$SCRIPT_DIR/../dev/github/system-maintenance/scripts/deploy-enhanced-monitoring.sh" ]; then
    run_section "3a" "$SCRIPT_DIR/../dev/github/system-maintenance/scripts/deploy-enhanced-monitoring.sh"
fi

# ============================================================
# Section 4: Secrets Management
# ============================================================
echo "Section 4: Secrets Management"
run_section "4" "$SCRIPT_DIR/security/setup-secrets-management.sh"

# ============================================================
# Section 5: Intrusion Detection
# ============================================================
echo "Section 5: Intrusion Detection"
run_section "5" "$SCRIPT_DIR/security/setup-intrusion-detection.sh"

# ============================================================
# Section 6: Automated Security Scanning
# ============================================================
echo "Section 6: Automated Security Scanning"
run_section "6" "$SCRIPT_DIR/security/setup-security-scanning.sh"

# ============================================================
# Section 7: Network Security
# ============================================================
echo "Section 7: Network Security"
run_section "7" "$SCRIPT_DIR/network/setup-vpn.sh"

# ============================================================
# Section 10: Off-site Backup Replication
# ============================================================
echo "Section 10: Off-site Backup Replication"
run_section "10" "$SCRIPT_DIR/backups/setup-offsite-backup.sh"

# ============================================================
# Section 12: Database Optimization
# ============================================================
echo "Section 12: Database Optimization"
run_section "12" "$SCRIPT_DIR/maintenance/setup-database-optimization.sh"

# ============================================================
# Section 13: Audit Logging
# ============================================================
echo "Section 14: Audit Logging"
run_section "14" "$SCRIPT_DIR/maintenance/setup-audit-logging.sh"

# ============================================================
# Section 14: Policy Enforcement (OPA)
# ============================================================
echo "Section 15: Policy Enforcement"
run_section "15" "$SCRIPT_DIR/security/setup-opa-policies.sh"

# ============================================================
# Section 16: Resource Monitoring
# ============================================================
echo "Section 16: Resource Monitoring & Cost Optimization"
run_section "16" "$SCRIPT_DIR/maintenance/setup-resource-monitoring.sh"

# ============================================================
# Load Testing
# ============================================================
echo "Section 12: Load Testing"
if [ -d "$SCRIPT_DIR/performance/load-testing" ]; then
    run_section "12" "$SCRIPT_DIR/performance/load-testing/setup-load-testing.sh"
fi

# ============================================================
# Verify all cron jobs
# ============================================================
echo ""
echo "================================================================="
echo "  Current Crontab"
echo "================================================================="
crontab -l 2>/dev/null || echo "No crontab configured"

echo ""
echo "================================================================="
echo "  Summary of Scheduled Tasks"
echo "================================================================="
echo ""
echo "Time            | Task"
echo "----------------|------------------------------------------------"
echo "00:00 (daily)   | Disk space check"
echo "01:00 (daily)   | Database backup (backup-databases.sh)"
echo "02:00 (daily)   | Full backup (backup-all.sh)"
echo "02:30 (daily)   | PostgreSQL vacuum/analyze"
echo "03:00 (daily)   | Docker volume backup (backup-docker-volumes.sh)"
echo "04:00 (daily)   | Temp cleanup"
echo "04:30 (daily)   | Off-site replication"
echo "05:00 (daily)   | AIDE integrity check"
echo "06:00 (weekly Sun) | Trivy security scan"
echo "07:00 (weekly Sun) | OWASP ZAP scan"
echo "08:00 (weekly Mon) | Compliance report"
echo "09:00 (weekly Mon) | Access review"
echo "10:00 (weekly Mon) | OPA policy evaluation"
echo "Hourly          | Performance check, network monitor"
echo "Every 5 min     | Business metrics export"
echo "Every 6 hours   | Audit trail generation"
echo ""

echo "================================================================="
echo "  Enhancements deployed!"
echo "================================================================="
echo ""
echo "Quick reference:"
echo "  - Setup guide:  [REDACTED_PATH]/dev/github/system-maintenance/install.sh"
echo "  - DR docs:      [REDACTED_PATH]/dev/github/system-maintenance/docs/DISASTER_RECOVERY.md"
echo "  - Runbooks:     [REDACTED_PATH]/dev/github/system-maintenance/docs/RUNBOOKS.md"
echo "  - Monitoring:   docker-compose -f docker-compose.monitoring.yml up -d"
echo "  - Logging:      docker-compose -f logging/docker-compose.loki.yml up -d"
