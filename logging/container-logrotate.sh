#!/bin/bash
# Docker container log rotation and retention policy
set -euo pipefail

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
[REDACTED_PATH]/scripts/logs/*.log
/var/log/backup.log
/var/log/security-hardening.log
/var/log/maintenance.log
[REDACTED_PATH]/.local/share/network-monitor.log
[REDACTED_PATH]/.local/share/api-security.log
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
