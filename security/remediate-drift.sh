#!/bin/bash
# Drift Remediation Script
# Fixes security drift issues automatically where possible

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$SCRIPT_DIR/logs"
mkdir -p "$LOG_DIR"

DATE=$(date +%Y%m%d_%H%M%S)
REMEDIATION_LOG="$LOG_DIR/remediation-$DATE.log"

echo "=== Drift Remediation - $DATE ===" | tee "$REMEDIATION_LOG"
echo "" | tee -a "$REMEDIATION_LOG"

FIXED=0
FAILED=0
SKIPPED=0

log_fix() {
    echo "[FIX] $1" | tee -a "$REMEDIATION_LOG"
    FIXED=$((FIXED + 1))
}

log_fail() {
    echo "[FAIL] $1" | tee -a "$REMEDIATION_LOG"
    FAILED=$((FAILED + 1))
}

log_skip() {
    echo "[SKIP] $1" | tee -a "$REMEDIATION_LOG"
    SKIPPED=$((SKIPPED + 1))
}

# ============================================
# 1. FIX: Ports exposed on 0.0.0.0
# ============================================
echo "--- Fixing 0.0.0.0 port bindings ---" | tee -a "$REMEDIATION_LOG"

# Get containers with 0.0.0.0 bindings
UNEXPECTED_PORTS=$(docker ps --format '{{.Names}}|{{.Ports}}' 2>/dev/null | grep '0.0.0.0:' | while IFS='|' read -r NAME PORTS; do
    echo "$NAME|$PORTS"
done)

if [ -n "$UNEXPECTED_PORTS" ]; then
    echo "$UNEXPECTED_PORTS" | while IFS='|' read -r NAME PORTS; do
        echo "Container $NAME has 0.0.0.0 bindings: $PORTS" | tee -a "$REMEDIATION_LOG"
        echo "  ⚠️  Manual action required: Recreate container with -p 127.0.0.1:PORT:PORT" | tee -a "$REMEDIATION_LOG"
        log_skip "Container $NAME: 0.0.0.0 bindings require container recreation"
    done
else
    log_fix "No 0.0.0.0 bindings found"
fi

# ============================================
# 2. FIX: Enable auditd
# ============================================
echo "" | tee -a "$REMEDIATION_LOG"
echo "--- Enabling auditd ---" | tee -a "$REMEDIATION_LOG"

if command -v auditctl &> /dev/null; then
    if auditctl -s 2>/dev/null | grep -q "enabled=1"; then
        log_fix "auditd already enabled"
    else
        echo "Starting auditd..." | tee -a "$REMEDIATION_LOG"
        if systemctl start auditd 2>/dev/null && systemctl enable auditd 2>/dev/null; then
            log_fix "auditd started and enabled"
        else
            log_fail "Failed to start auditd (may need root)"
        fi
    fi
else
    log_skip "auditd not installed (install: apt install auditd)"
fi

# ============================================
# 3. FIX: Enable Fail2Ban
# ============================================
echo "" | tee -a "$REMEDIATION_LOG"
echo "--- Enabling Fail2Ban ---" | tee -a "$REMEDIATION_LOG"

if systemctl is-active --quiet fail2ban 2>/dev/null; then
    log_fix "Fail2Ban already running"
elif systemctl is-active --quiet crowdsec 2>/dev/null; then
    log_fix "CrowdSec already running (alternative to Fail2Ban)"
else
    if command -v fail2ban-server &> /dev/null; then
        echo "Starting Fail2Ban..." | tee -a "$REMEDIATION_LOG"
        if systemctl start fail2ban 2>/dev/null && systemctl enable fail2ban 2>/dev/null; then
            log_fix "Fail2Ban started and enabled"
        else
            log_fail "Failed to start Fail2Ban (may need root)"
        fi
    else
        log_skip "Fail2Ban not installed (install: apt install fail2ban)"
    fi
fi

# ============================================
# 4. FIX: Docker container healthchecks (informational)
# ============================================
echo "" | tee -a "$REMEDIATION_LOG"
echo "--- Container Healthchecks ---" | tee -a "$REMEDIATION_LOG"

NO_HEALTH=$(docker ps --format '{{.Names}}|{{.Image}}' | while IFS='|' read -r NAME IMAGE; do
    INSPECT=$(docker inspect "$NAME" 2>/dev/null | jq '.[0]')
    HEALTH=$(echo "$INSPECT" | jq -r '.Config.Healthcheck.Test // [] | length')
    if [ "$HEALTH" = "0" ] || [ "$HEALTH" = "null" ]; then
        echo "$NAME|$IMAGE"
    fi
done)

if [ -n "$NO_HEALTH" ]; then
    COUNT=$(echo "$NO_HEALTH" | wc -l)
    echo "$NO_HEALTH" | while IFS='|' read -r NAME IMAGE; do
        echo "  $NAME ($IMAGE): No healthcheck configured" | tee -a "$REMEDIATION_LOG"
    done
    echo "  ⚠️  $COUNT containers missing healthchecks - add HEALTHCHECK to Dockerfile or docker run --health-cmd" | tee -a "$REMEDIATION_LOG"
    log_skip "$COUNT containers missing healthchecks (requires image rebuild)"
else
    log_fix "All containers have healthchecks"
fi

# ============================================
# 5. FIX: Docker memory limits (informational)
# ============================================
echo "" | tee -a "$REMEDIATION_LOG"
echo "--- Container Memory Limits ---" | tee -a "$REMEDIATION_LOG"

NO_MEMORY=$(docker ps --format '{{.Names}}' | while read -r NAME; do
    INSPECT=$(docker inspect "$NAME" 2>/dev/null | jq '.[0]')
    MEMORY=$(echo "$INSPECT" | jq -r '.HostConfig.Memory')
    if [ "$MEMORY" = "0" ] || [ "$MEMORY" = "null" ]; then
        echo "$NAME"
    fi
done)

if [ -n "$NO_MEMORY" ]; then
    COUNT=$(echo "$NO_MEMORY" | wc -l)
    echo "$NO_MEMORY" | while read -r NAME; do
        echo "  $NAME: No memory limit" | tee -a "$REMEDIATION_LOG"
    done
    echo "  ⚠️  $COUNT containers without memory limits - add --memory flag" | tee -a "$REMEDIATION_LOG"
    log_skip "$COUNT containers without memory limits (requires container recreation)"
else
    log_fix "All containers have memory limits"
fi

# ============================================
# SUMMARY
# ============================================
echo "" | tee -a "$REMEDIATION_LOG"
echo "=== Remediation Summary ===" | tee -a "$REMEDIATION_LOG"
echo "Fixed:    $FIXED" | tee -a "$REMEDIATION_LOG"
echo "Failed:   $FAILED" | tee -a "$REMEDIATION_LOG"
echo "Skipped:  $SKIPPED (require manual intervention)" | tee -a "$REMEDIATION_LOG"
echo "" | tee -a "$REMEDIATION_LOG"
echo "Log: $REMEDIATION_LOG" | tee -a "$REMEDIATION_LOG"

# Create latest symlink
ln -sfn "$REMEDIATION_LOG" "$LOG_DIR/remediation-latest.log"

# Return non-zero if any failed
if [ $FAILED -gt 0 ]; then
    exit 1
fi
exit 0