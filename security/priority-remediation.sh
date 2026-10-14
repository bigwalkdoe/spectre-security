#!/bin/bash
# Prioritized Remediation Execution
# Runs fixes in order of security criticality

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$SCRIPT_DIR/logs"
mkdir -p "$LOG_DIR"

DATE=$(date +%Y%m%d_%H%M%S)
EXEC_LOG="$LOG_DIR/priority-remediation-$DATE.log"

echo "=== Prioritized Remediation Execution - $DATE ===" | tee "$EXEC_LOG"
echo "" | tee -a "$EXEC_LOG"

run_cmd() {
    local desc="$1"
    local cmd="$2"
    echo "[EXEC] $desc" | tee -a "$EXEC_LOG"
    echo "Command: $cmd" | tee -a "$EXEC_LOG"
    if eval "$cmd" 2>&1 | tee -a "$EXEC_LOG"; then
        echo "[OK] $desc" | tee -a "$EXEC_LOG"
        return 0
    else
        echo "[FAIL] $desc" | tee -a "$EXEC_LOG"
        return 1
    fi
}

# ============================================
# PRIORITY 1: CRITICAL - System Security Controls
# ============================================
echo "" | tee -a "$EXEC_LOG"
echo "=== PRIORITY 1: CRITICAL SYSTEM CONTROLS ===" | tee -a "$EXEC_LOG"

# 1.1 Enable Firewall
run_cmd "Enable UFW Firewall" "sudo ufw --force enable"

# 1.2 Enable Auditd
run_cmd "Install auditd" "sudo apt update && sudo apt install -y auditd"
run_cmd "Enable auditd service" "sudo systemctl enable --now auditd"
run_cmd "Verify auditd running" "sudo auditctl -s"

# 1.3 Enable Fail2Ban
run_cmd "Install Fail2Ban" "sudo apt install -y fail2ban"
run_cmd "Enable Fail2Ban service" "sudo systemctl enable --now fail2ban"
run_cmd "Verify Fail2Ban status" "sudo systemctl status fail2ban --no-pager"

# ============================================
# PRIORITY 2: HIGH - Network Exposure (0.0.0.0 bindings)
# ============================================
echo "" | tee -a "$EXEC_LOG"
echo "=== PRIORITY 2: NETWORK EXPOSURE ===" | tee -a "$EXEC_LOG"

# Get containers with 0.0.0.0 bindings
UNEXPECTED=$(docker ps --format '{{.Names}}|{{.Ports}}' 2>/dev/null | grep '0.0.0.0:')

if [ -n "$UNEXPECTED" ]; then
    echo "Containers with 0.0.0.0 bindings:" | tee -a "$EXEC_LOG"
    echo "$UNEXPECTED" | tee -a "$EXEC_LOG"
    echo "" | tee -a "$EXEC_LOG"
    echo "These require container recreation with localhost binding." | tee -a "$EXEC_LOG"
    echo "Run for each: docker run -p 127.0.0.1:PORT:PORT <image>" | tee -a "$EXEC_LOG"
else
    echo "No 0.0.0.0 bindings found" | tee -a "$EXEC_LOG"
fi

# ============================================
# PRIORITY 3: MEDIUM - Container Hardening
# ============================================
echo "" | tee -a "$EXEC_LOG"
echo "=== PRIORITY 3: CONTAINER HARDENING ===" | tee -a "$EXEC_LOG"

# Check for missing healthchecks
NO_HEALTH=$(docker ps --format '{{.Names}}' | while read -r NAME; do
    INSPECT=$(docker inspect "$NAME" 2>/dev/null | jq '.[0]')
    HEALTH=$(echo "$INSPECT" | jq -r '.Config.Healthcheck.Test // [] | length')
    if [ "$HEALTH" = "0" ] || [ "$HEALTH" = "null" ]; then
        echo "$NAME"
    fi
done)

if [ -n "$NO_HEALTH" ]; then
    echo "Containers missing healthchecks:" | tee -a "$EXEC_LOG"
    echo "$NO_HEALTH" | tee -a "$EXEC_LOG"
    echo "Add --health-cmd to docker run or HEALTHCHECK to Dockerfile" | tee -a "$EXEC_LOG"
fi

# Check for missing memory limits
NO_MEMORY=$(docker ps --format '{{.Names}}' | while read -r NAME; do
    INSPECT=$(docker inspect "$NAME" 2>/dev/null | jq '.[0]')
    MEMORY=$(echo "$INSPECT" | jq -r '.HostConfig.Memory')
    if [ "$MEMORY" = "0" ] || [ "$MEMORY" = "null" ]; then
        echo "$NAME"
    fi
done)

if [ -n "$NO_MEMORY" ]; then
    echo "Containers without memory limits:" | tee -a "$EXEC_LOG"
    echo "$NO_MEMORY" | tee -a "$EXEC_LOG"
    echo "Add --memory=2g to docker run" | tee -a "$EXEC_LOG"
fi

# ============================================
# PRIORITY 4: SSH Hardening
# ============================================
echo "" | tee -a "$EXEC_LOG"
echo "=== PRIORITY 4: SSH HARDENING ===" | tee -a "$EXEC_LOG"

if [ -r /etc/ssh/sshd_config ]; then
    if grep -q "^PasswordAuthentication yes" /etc/ssh/sshd_config; then
        run_cmd "Disable SSH password auth" "sudo sed -i 's/^PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config && sudo systemctl reload sshd"
    else
        echo "SSH password auth already disabled" | tee -a "$EXEC_LOG"
    fi
else
    echo "Cannot read /etc/ssh/sshd_config (permission)" | tee -a "$EXEC_LOG"
fi

# ============================================
# SUMMARY
# ============================================
echo "" | tee -a "$EXEC_LOG"
echo "=== REMEDIATION COMPLETE ===" | tee -a "$EXEC_LOG"
echo "Log: $EXEC_LOG" | tee -a "$EXEC_LOG"
echo "" | tee -a "$EXEC_LOG"
echo "Next: Run drift detection to verify fixes:" | tee -a "$EXEC_LOG"
echo "  ./security/drift-detection.sh" | tee -a "$EXEC_LOG"

# Create latest symlink
ln -sfn "$EXEC_LOG" "$LOG_DIR/priority-remediation-latest.log"