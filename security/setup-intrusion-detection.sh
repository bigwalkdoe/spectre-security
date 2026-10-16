#!/bin/bash
# Intrusion Detection Setup - Fail2Ban, Wazuh, AIDE
set -euo pipefail
# Resolve the invoking user's home and this repository's root. Under sudo,
# $HOME is /root, so fall back to $SUDO_USER before trusting it. Both may be
# overridden: SPECTRE_HOME=/srv/secure SPECTRE_REPO=/opt/spectre-security
_spectre_here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SPECTRE_HOME="${SPECTRE_HOME:-$(getent passwd "${SUDO_USER:-$USER}" 2>/dev/null | cut -d: -f6)}"
SPECTRE_HOME="${SPECTRE_HOME:-$HOME}"
SPECTRE_REPO="${SPECTRE_REPO:-$(git -C "$_spectre_here" rev-parse --show-toplevel 2>/dev/null || echo "$_spectre_here")}"

echo "=== Intrusion Detection Setup ==="
echo ""

# 1. Fail2Ban - Brute force protection
setup_fail2ban() {
    echo "[1/3] Setting up Fail2Ban for brute force protection..."
    
    if ! command -v fail2ban-client >/dev/null 2>&1; then
        echo "Installing Fail2Ban..."
        sudo dnf install -y fail2ban 2>/dev/null || sudo apt install -y fail2ban 2>/dev/null || true
    fi

    # Create comprehensive jail configuration
    sudo bash -c 'cat > /etc/fail2ban/jail.local << "F2B"
[DEFAULT]
ignoreip = 127.0.0.1/8 ::1 10.0.0.0/8 172.16.0.0/12 192.168.0.0/16
bantime = 1h
findtime = 10m
maxretry = 5
banaction = firewallcmd-ipset
action = %(action_mwl)s

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 24h

[sshd-ddos]
enabled = true
port = ssh
filter = sshd-ddos
logpath = /var/log/auth.log
maxretry = 2
findtime = 60
bantime = 24h

[docker]
enabled = true
port = 2375
filter = docker
logpath = /var/log/docker.log
maxretry = 3
bantime = 1h

[nginx-http-auth]
enabled = true
filter = nginx-http-auth
port = http,https
logpath = /var/log/nginx/error.log
maxretry = 5
bantime = 1h

[nginx-limit-req]
enabled = true
filter = nginx-limit-req
port = http,https
logpath = /var/log/nginx/error.log
maxretry = 5
findtime = 60
bantime = 1h

[postfix]
enabled = true
filter = postfix
logpath = /var/log/mail.log
maxretry = 3

[recidive]
enabled = true
filter = recidive
logpath = /var/log/fail2ban.log
maxretry = 3
findtime = 86400
bantime = 604800
F2B'

    # Create custom Docker filter
    sudo bash -c 'cat > /etc/fail2ban/filter.d/docker.conf << "DOCKER_FILTER"
[Definition]
failregex = ^.*Authentication failed.*from <HOST>.*$
            ^.*Unauthorized request from <HOST>.*$
ignoreregex =
DOCKER_FILTER'

    sudo systemctl enable fail2ban
    sudo systemctl restart fail2ban
    echo "Fail2Ban configured with SSHD, Docker, Nginx, and recidive jails"
}

# 2. AIDE - File integrity monitoring
setup_aide() {
    echo "[2/3] Setting up AIDE for file integrity monitoring..."
    
    if ! command -v aide >/dev/null 2>&1; then
        echo "Installing AIDE..."
        sudo dnf install -y aide 2>/dev/null || sudo apt install -y aide 2>/dev/null || true
    fi

    # Create AIDE configuration
    sudo bash -c 'cat > /etc/aide.conf << "AIDE_CONF"
# AIDE Configuration for System Maintenance
@@define DBDIR /var/lib/aide
@@define LOGDIR /var/log/aide

database=file:@@{DBDIR}/aide.db.gz
database_out=file:@@{DBDIR}/aide.db.new.gz
gzip_dbout=yes
verbose=5
report_url=file:@@{LOGDIR}/aide.log
report_url=stdout

# System binaries and libraries
/bin    CONTENT_EX
/sbin   CONTENT_EX
/lib    CONTENT_EX
/lib64  CONTENT_EX
/usr/bin CONTENT_EX
/usr/sbin CONTENT_EX
/usr/lib CONTENT_EX
/usr/lib64 CONTENT_EX

# Configuration files
/etc    CONTENT_EX
/boot   CONTENT_EX

# Critical system files
/etc/passwd CONTENT_EX
/etc/shadow CONTENT_EX
/etc/group CONTENT_EX
/etc/sudoers CONTENT_EX
/etc/ssh/sshd_config CONTENT_EX
/etc/hosts CONTENT_EX
/etc/hostname CONTENT_EX
/etc/fstab CONTENT_EX

# Docker configurations
/etc/docker CONTENT_EX

# Scripts and configurations
${SPECTRE_HOME}/scripts CONTENT_EX
${SPECTRE_HOME}/dev/github/system-maintenance CONTENT_EX

# Log files (check existence only)
/var/log PERMS

# Directories to ignore
!/proc
!/sys
!/dev
!/run
!/mnt
!/media
!/var/lib/docker
!/var/cache
!${SPECTRE_HOME}/.cache
AIDE_CONF'

    sudo mkdir -p /var/lib/aide /var/log/aide
    sudo aideinit 2>/dev/null || sudo aide --init 2>/dev/null || true
    
    # Create AIDE check script
    cat > ${SPECTRE_REPO}/security/check-file-integrity.sh << 'AIDE_CHECK'
#!/bin/bash
# AIDE File Integrity Check
set -euo pipefail

AIDE_CHECKSUM="/var/lib/aide/aide.db.gz"
AIDE_LOG="/var/log/aide/aide.log"
DATE=$(date +%Y%m%d_%H%M%S)

echo "=== AIDE File Integrity Check - $DATE ==="

if [ ! -f "$AIDE_CHECKSUM" ]; then
    echo "No AIDE database found. Running initialization..."
    sudo aide --init
    sudo cp /var/lib/aide/aide.db.new.gz /var/lib/aide/aide.db.gz
fi

echo "Checking file integrity..."
sudo aide --check > "$AIDE_LOG" 2>&1
AIDE_EXIT=$?

if [ $AIDE_EXIT -eq 0 ]; then
    echo "File integrity check PASSED"
    logger -p user.info "AIDE integrity check passed"
else
    echo "WARNING: File integrity changes detected!"
    echo "Check $AIDE_LOG for details"
    logger -p user.warning "AIDE integrity check failed - changes detected"
    cat "$AIDE_LOG"
fi

# Update database after successful check
if [ -f /var/lib/aide/aide.db.new.gz ]; then
    sudo cp /var/lib/aide/aide.db.new.gz /var/lib/aide/aide.db.gz
    echo "AIDE database updated"
fi

echo "AIDE check completed (exit code: $AIDE_EXIT)"
AIDE_CHECK
    chmod +x ${SPECTRE_REPO}/security/check-file-integrity.sh
    echo "AIDE configured and initialized"
}

# 3. Wazuh agent (lightweight OSSEC fork)
setup_wazuh() {
    echo "[3/3] Setting up Wazuh agent for host intrusion detection..."
    
    if [ ! -f /var/ossec/bin/wazuh-agent ]; then
        echo "Installing Wazuh agent..."
        # Add Wazuh repository
        curl -s https://packages.wazuh.com/key/GPG-KEY-WAZUH | sudo apt-key add - 2>/dev/null || true
        echo "deb https://packages.wazuh.com/4.x/apt/ stable main" | sudo tee /etc/apt/sources.list.d/wazuh.list 2>/dev/null || true
        sudo apt-get update 2>/dev/null && sudo apt-get install -y wazuh-agent 2>/dev/null || {
            echo "WARNING: Could not install Wazuh agent via package manager"
            echo "Manual installation may be required"
        }
    else
        echo "Wazuh agent already installed"
    fi

    # Create Wazuh configuration
    if [ -f /var/ossec/etc/ossec.conf ]; then
        sudo bash -c 'cat > /var/ossec/etc/ossec.conf << "OSSEC_CONF"
<ossec_config>
  <client>
    <server>
      <address>MANAGER_IP</address>
      <port>1514</port>
      <protocol>tcp</protocol>
    </server>
    <config-profile>linux</config-profile>
    <notify_time>10</notify_time>
    <time-reconnect>60</time-reconnect>
  </client>

  <syscheck>
    <frequency>3600</frequency>
    <scan_on_start>yes</scan_on_start>
    <directories check_all="yes">/etc,/usr/bin,/usr/sbin,/bin,/sbin,${SPECTRE_HOME}/scripts</directories>
    <directories check_all="yes">${SPECTRE_HOME}/dev/github/system-maintenance</directories>
    <ignore>/proc</ignore>
    <ignore>/sys</ignore>
    <ignore>/dev</ignore>
  </syscheck>

  <rootcheck>
    <rootkit_files>/var/ossec/etc/rootcheck/rootkit_files.txt</rootkit_files>
    <rootkit_trojans>/var/ossec/etc/rootcheck/rootkit_trojans.txt</rootkit_trojans>
    <frequency>86400</frequency>
  </rootcheck>

  <localfile>
    <log_format>syslog</log_format>
    <location>/var/log/auth.log</location>
  </localfile>

  <localfile>
    <log_format>syslog</log_format>
    <location>/var/log/syslog</location>
  </localfile>

  <localfile>
    <log_format>docker</log_format>
    <location>/var/lib/docker/containers</location>
  </localfile>
</ossec_config>
OSSEC_CONF'
        echo "Wazuh agent configured"
    fi

    # Create Wazuh status check script
    cat > ${SPECTRE_REPO}/security/check-wazuh-status.sh << 'WAZUH'
#!/bin/bash
# Check Wazuh agent status
echo "=== Wazuh Agent Status ==="
if [ -f /var/ossec/bin/wazuh-agent ]; then
    /var/ossec/bin/wazuh-agent -c 2>/dev/null || echo "Wazuh agent not connected"
    systemctl status wazuh-agent --no-pager 2>/dev/null || echo "Wazuh service not found"
else
    echo "Wazuh agent not installed"
fi
echo ""
echo "Agent logs: /var/ossec/logs/ossec.log"
echo "Active response: /var/ossec/active-response/bin/"
WAZUH
    chmod +x ${SPECTRE_REPO}/security/check-wazuh-status.sh
    echo "Wazuh agent configured (set MANAGER_IP in /var/ossec/etc/ossec.conf)"
}

# Run all setups
setup_fail2ban
echo ""
setup_aide
echo ""
setup_wazuh
echo ""

# Add AIDE check to cron
if ! crontab -l 2>/dev/null | grep -q "check-file-integrity"; then
    (crontab -l 2>/dev/null; echo "# AIDE file integrity check - Daily at 5:00 AM") | crontab -
    (crontab -l 2>/dev/null; echo "0 5 * * * ${SPECTRE_REPO}/security/check-file-integrity.sh") | crontab -
    echo "AIDE daily check scheduled (5:00 AM)"
fi

echo ""
echo "=== Intrusion Detection Setup Complete ==="
echo ""
echo "Components installed:"
echo "  - Fail2Ban (brute force protection)"
echo "  - AIDE (file integrity monitoring)"
echo "  - Wazuh agent (host intrusion detection)"
echo ""
echo "Configuration files:"
echo "  - /etc/fail2ban/jail.local"
echo "  - /etc/aide.conf"
echo "  - /var/ossec/etc/ossec.conf"
echo ""
echo "Next steps:"
echo "  1. Review and adjust Fail2Ban jails"
echo "  2. Set MANAGER_IP in Wazuh config for centralized SIEM"
echo "  3. Check AIDE database was initialized"
echo "  4. Run initial AIDE check: sudo aide --check"
