#!/bin/bash
# System Performance Optimization Script

# Resolve the invoking user's home and this repository's root. Under sudo,
# $HOME is /root, so fall back to $SUDO_USER before trusting it. Both may be
# overridden: SPECTRE_HOME=/srv/secure SPECTRE_REPO=/opt/spectre-security
_spectre_here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SPECTRE_HOME="${SPECTRE_HOME:-$(getent passwd "${SUDO_USER:-$USER}" 2>/dev/null | cut -d: -f6)}"
SPECTRE_HOME="${SPECTRE_HOME:-$HOME}"
SPECTRE_REPO="${SPECTRE_REPO:-$(git -C "$_spectre_here" rev-parse --show-toplevel 2>/dev/null || echo "$_spectre_here")}"
echo "Optimizing system performance..."

# Enable tuned performance profile
if command -v tuned-adm >/dev/null 2>&1; then
    echo "Configuring tuned for virtual-machine profile..."
    sudo tuned-adm profile virtual-host
else
    echo "tuned not installed, skipping..."
fi

# Optimize swappiness
echo "Optimizing swappiness..."
CURRENT_SWAPPINESS=$(cat /proc/sys/vm/swappiness)
if [ "$CURRENT_SWAPPINESS" -gt 20 ]; then
    echo "Current swappiness: $CURRENT_SWAPPINESS, setting to 10..."
    sudo sysctl vm.swappiness=10
    echo "vm.swappiness=10" | sudo tee -a /etc/sysctl.conf
else
    echo "Swappiness already optimized: $CURRENT_SWAPPINESS"
fi

# Optimize I/O scheduler
echo "Optimizing I/O scheduler..."
if [ -f /sys/block/nvme0n1/queue/scheduler ]; then
    CURRENT_SCHEDULER=$(cat /sys/block/nvme0n1/queue/scheduler)
    echo "Current I/O scheduler: $CURRENT_SCHEDULER"
    # noop or deadline is good for SSD/NVMe
    echo deadline | sudo tee /sys/block/nvme0n1/queue/scheduler
    echo "nvme0n1/queue/scheduler = deadline" | sudo tee -a /etc/sysctl.conf
fi

# Optimize network settings
echo "Optimizing network settings..."
sudo sysctl net.core.rmem_max=16777216
sudo sysctl net.core.wmem_max=16777216
sudo sysctl net.ipv4.tcp_rmem='4096 87380 16777216'
sudo sysctl net.ipv4.tcp_wmem='4096 65536 16777216'

echo "Network optimizations:
- rmem_max: 16MB
- wmem_max: 16MB
- tcp_rmem: 4KB 85KB 16MB
- tcp_wmem: 4KB 64KB 16MB" | sudo tee -a /etc/sysctl.conf

# Increase file descriptor limits
echo "Optimizing file descriptor limits..."
sudo bash -c 'cat > /etc/security/limits.d/99-performance.conf << "EOF"
* soft nofile 65536
* hard nofile 65536
* soft nproc 65536
* hard nproc 65536
EOF'

# Create performance monitoring dashboard alerts
echo "Setting up performance alerts..."
mkdir -p ${SPECTRE_REPO}/performance

cat > ${SPECTRE_REPO}/performance/check-performance.sh << 'EOF'
#!/bin/bash
# Performance monitoring script

THRESHOLD_CPU=80
THRESHOLD_MEM=85
THRESHOLD_DISK=90

# Check CPU usage
CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
if (( $(echo "$CPU_USAGE > $THRESHOLD_CPU" | bc -l) )); then
    logger -p user.warning "High CPU usage: ${CPU_USAGE}%"
fi

# Check memory usage
MEM_USAGE=$(free | grep Mem | awk '{printf "%.0f", $3/$2 * 100.0}')
if [ "$MEM_USAGE" -gt "$THRESHOLD_MEM" ]; then
    logger -p user.warning "High memory usage: ${MEM_USAGE}%"
fi

# Check disk usage
DISK_USAGE=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
if [ "$DISK_USAGE" -gt "$THRESHOLD_DISK" ]; then
    logger -p user.warning "High disk usage: ${DISK_USAGE}%"
fi

echo "Performance check completed - CPU: ${CPU_USAGE}%, MEM: ${MEM_USAGE}%, DISK: ${DISK_USAGE}%"
EOF

chmod +x ${SPECTRE_REPO}/performance/check-performance.sh

# Create systemd timer for performance monitoring
sudo bash -c 'cat > /etc/systemd/system/performance-check.timer << "EOF"
[Unit]
Description=Performance Monitoring Timer

[Timer]
OnCalendar=hourly
Persistent=true

[Install]
WantedBy=timers.target
EOF'

# ${SPECTRE_REPO} must expand in this shell, not in sudo's: env_reset strips the
# environment and the variable is never exported, so inside sudo bash -c the
# placeholder expands to nothing; the old quoted-delimiter form instead wrote
# the literal `${SPECTRE_REPO}`, which systemd rejects with
# "Neither a valid executable name nor an absolute path" on every timer tick.
# Here the outer shell expands it and sudo only performs the write.
sudo tee /etc/systemd/system/performance-check.service > /dev/null << EOF
[Unit]
Description=Performance Monitoring Service

[Service]
Type=oneshot
ExecStart=${SPECTRE_REPO}/performance/check-performance.sh
User=deon
EOF

sudo systemctl enable --now performance-check.timer

echo "Performance optimization completed!"
echo "Performance monitoring is now running hourly"
logger -p user.info "System performance optimization completed"
