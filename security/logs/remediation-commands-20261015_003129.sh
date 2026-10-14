#!/bin/bash
# ============================================
# PRIORITIZED REMEDIATION COMMANDS
# Run with: sudo bash remediation-commands-*.sh
# ============================================

set -euo pipefail

echo "=== PRIORITIZED REMEDIATION COMMANDS ==="
echo "Run as root: sudo bash $0"
echo ""

# ============================================
# PRIORITY 1: CRITICAL - System Security Controls
# ============================================
echo ""
echo "=== PRIORITY 1: CRITICAL SYSTEM CONTROLS ==="

# 1.1 Enable Firewall
echo "[1.1] Enable UFW Firewall"
ufw --force enable

# 1.2 Enable Auditd
echo "[1.2] Install and enable auditd"
apt update && apt install -y auditd
systemctl enable --now auditd
auditctl -s

# 1.3 Enable Fail2Ban
echo "[1.3] Install and enable Fail2Ban"
apt install -y fail2ban
systemctl enable --now fail2ban
systemctl status fail2ban --no-pager

# ============================================
# PRIORITY 2: HIGH - Network Exposure
# ============================================
echo ""
echo "=== PRIORITY 2: NETWORK EXPOSURE (0.0.0.0 bindings) ==="

# List containers with 0.0.0.0 bindings
echo "Containers with 0.0.0.0 bindings:"
docker ps --format '{{.Names}}|{{.Ports}}' | grep '0.0.0.0:' || echo "None found"

echo ""
echo "For each container above, recreate with localhost binding:"
echo "  docker run -p 127.0.0.1:PORT:PORT <image>"
echo ""
echo "Example for port 3000:"
echo "  docker run -p 127.0.0.1:3000:3000 <image>"

# ============================================
# PRIORITY 3: MEDIUM - Container Hardening
# ============================================
echo ""
echo "=== PRIORITY 3: CONTAINER HARDENING ==="

echo "Containers missing healthchecks:"
docker ps --format '{{.Names}}' | while read -r NAME; do
    INSPECT=$(docker inspect "$NAME" 2>/dev/null | jq '.[0]')
    HEALTH=$(echo "$INSPECT" | jq -r '.Config.Healthcheck.Test // [] | length')
    if [ "$HEALTH" = "0" ] || [ "$HEALTH" = "null" ]; then
        echo "  $NAME"
    fi
done

echo ""
echo "Add healthcheck to container run:"
echo '  docker run --health-cmd="curl -f http://localhost:8080/health || exit 1" --health-interval=30s --health-timeout=10s --health-retries=3 <image>'

echo ""
echo "Containers without memory limits:"
docker ps --format '{{.Names}}' | while read -r NAME; do
    INSPECT=$(docker inspect "$NAME" 2>/dev/null | jq '.[0]')
    MEMORY=$(echo "$INSPECT" | jq -r '.HostConfig.Memory')
    if [ "$MEMORY" = "0" ] || [ "$MEMORY" = "null" ]; then
        echo "  $NAME"
    fi
done

echo ""
echo "Add memory limit to container run:"
echo "  docker run --memory=2g --memory-swap=4g <image>"

# ============================================
# PRIORITY 4: SSH Hardening
# ============================================
echo ""
echo "=== PRIORITY 4: SSH HARDENING ==="

if [ -r /etc/ssh/sshd_config ]; then
    if grep -q "^PasswordAuthentication yes" /etc/ssh/sshd_config; then
        echo "[4.1] Disable SSH password authentication"
        sed -i 's/^PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
        systemctl reload sshd
        echo "  Done"
    else
        echo "  SSH password auth already disabled"
    fi
else
    echo "  Cannot read /etc/ssh/sshd_config"
fi

# ============================================
# VERIFICATION
# ============================================
echo ""
echo "=== VERIFICATION ==="
echo "Run drift detection to verify fixes:"
echo "  ./security/drift-detection.sh"

echo ""
echo "=== ALL COMMANDS COMPLETE ==="
