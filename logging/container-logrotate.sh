#!/bin/bash
# Docker container log rotation and retention policy
set -euo pipefail
# Resolve the invoking user's home and this repository's root. Under sudo,
# $HOME is /root, so fall back to $SUDO_USER before trusting it. Both may be
# overridden: SPECTRE_HOME=/srv/secure SPECTRE_REPO=/opt/spectre-security
_spectre_here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SPECTRE_HOME="${SPECTRE_HOME:-$(getent passwd "${SUDO_USER:-$USER}" 2>/dev/null | cut -d: -f6)}"
SPECTRE_HOME="${SPECTRE_HOME:-$HOME}"
SPECTRE_REPO="${SPECTRE_REPO:-$(git -C "$_spectre_here" rev-parse --show-toplevel 2>/dev/null || echo "$_spectre_here")}"

echo "Configuring Docker container log rotation..."

# Apply global Docker daemon log config
if command -v docker >/dev/null 2>&1; then
    sudo bash -c 'cat > /etc/docker/daemon.json << "EOF"
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "live-restore": true,
  "userland-proxy": false,
  "no-new-privileges": true,
  "icc": false
}
EOF'
    systemctl restart docker
    echo "Docker daemon log rotation configured (10m max, 3 files)"
fi

# System log rotation for all maintenance logs
sudo bash -c 'cat > /etc/logrotate.d/system-maintenance << "EOF"
/var/log/system-maintenance/*.log
${SPECTRE_REPO}/logs/*.log
/var/log/backup.log
/var/log/security-hardening.log
/var/log/maintenance.log
${SPECTRE_HOME}/.local/share/network-monitor.log
${SPECTRE_HOME}/.local/share/api-security.log
{
    daily
    rotate 14
    compress
    delaycompress
    missingok
    notifempty
    create 0644 deon deon
    sharedscripts
    postrotate
        logger -p user.info "Log rotation completed for system-maintenance logs"
    endscript
}
EOF'

sudo bash -c 'cat > /etc/logrotate.d/docker-containers << "EOF"
/var/lib/docker/containers/*/*.log {
    rotate 7
    daily
    compress
    size 10M
    missingok
    delaycompress
    copytruncate
}
EOF'

echo "Container log rotation and retention configured:"
echo "  - Retention: 7 days (docker), 14 days (application)"
echo "  - Max size: 10MB per log file"
echo "  - Compression: enabled (delay compress)"
