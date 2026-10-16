#!/bin/bash
# Network Monitoring Script

# Resolve the invoking user's home and this repository's root. Under sudo,
# $HOME is /root, so fall back to $SUDO_USER before trusting it. Both may be
# overridden: SPECTRE_HOME=/srv/secure SPECTRE_REPO=/opt/spectre-security
_spectre_here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SPECTRE_HOME="${SPECTRE_HOME:-$(getent passwd "${SUDO_USER:-$USER}" 2>/dev/null | cut -d: -f6)}"
SPECTRE_HOME="${SPECTRE_HOME:-$HOME}"
SPECTRE_REPO="${SPECTRE_REPO:-$(git -C "$_spectre_here" rev-parse --show-toplevel 2>/dev/null || echo "$_spectre_here")}"
NETWORK_LOG="${SPECTRE_HOME}/.local/share/network-monitor.log"
DATE=$(date +%Y%m%d_%H%M%S)
mkdir -p ${SPECTRE_HOME}/.local/share

echo "==========================================" >> "$NETWORK_LOG"
echo "Network Monitor - $DATE" >> "$NETWORK_LOG"
echo "==========================================" >> "$NETWORK_LOG"

# Check network interfaces
echo "Network Interfaces:" >> "$NETWORK_LOG"
ip addr show >> "$NETWORK_LOG"
echo "" >> "$NETWORK_LOG"

# Check network connectivity
echo "Network Connectivity:" >> "$NETWORK_LOG"
ping -c 3 8.8.8.8 >/dev/null 2>&1 && echo "Google DNS: OK" >> "$NETWORK_LOG" || echo "Google DNS: FAILED" >> "$NETWORK_LOG"
ping -c 3 1.1.1.1 >/dev/null 2>&1 && echo "Cloudflare DNS: OK" >> "$NETWORK_LOG" || echo "Cloudflare DNS: FAILED" >> "$NETWORK_LOG"
echo "" >> "$NETWORK_LOG"

# Check DNS resolution
echo "DNS Resolution:" >> "$NETWORK_LOG"
if nslookup google.com >/dev/null 2>&1; then
    echo "DNS resolution: OK" >> "$NETWORK_LOG"
else
    echo "DNS resolution: FAILED" >> "$NETWORK_LOG"
fi
echo "" >> "$NETWORK_LOG"

# Check network statistics
echo "Network Statistics:" >> "$NETWORK_LOG"
netstat -i >> "$NETWORK_LOG"
echo "" >> "$NETWORK_LOG"

# Check firewall status
echo "Firewall Status:" >> "$NETWORK_LOG"
firewall-cmd --state >> "$NETWORK_LOG" 2>&1 || echo "Firewall status check failed" >> "$NETWORK_LOG"
echo "" >> "$NETWORK_LOG"

# Check active connections
echo "Active Network Connections:" >> "$NETWORK_LOG"
ss -s >> "$NETWORK_LOG"
echo "" >> "$NETWORK_LOG"

# Check for suspicious connections
echo "External Connections:" >> "$NETWORK_LOG"
ss -tun | grep ESTABLISHED | awk '{print $5}' | cut -d':' -f1 | sort -u >> "$NETWORK_LOG"
echo "" >> "$NETWORK_LOG"

echo "Network monitoring completed: $DATE" >> "$NETWORK_LOG"
logger -p user.info "Network monitoring completed"
