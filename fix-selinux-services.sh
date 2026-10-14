#!/bin/bash
# Fix failed system services caused by mislabeled /usr/bin/python3.14
# Root cause: python3.14 carries SELinux context user_home_t instead of bin_t.
# All Python-script daemons (firewalld, fail2ban, setroubleshootd,
# me.proton.vpn.split_tunneling) fail at systemd step EXEC: "Permission denied"
# because SELinux denies confined daemons exec of user_home_t files.
# Fix: restore correct labels + relabel /etc/firewalld + restart services.
# Requires root: run with  sudo ~/scripts/fix-selinux-services.sh

LOG_FILE="$HOME/scripts/logs/fix-selinux-services.log"
mkdir -p "$(dirname "$LOG_FILE")"

log() { echo "[$(date '+%F %T')] $1" | tee -a "$LOG_FILE"; }

if [ "$EUID" -ne 0 ]; then
    echo "ERROR: must run as root (sudo $0)" >&2
    exit 1
fi

log "=== SELinux service fix started ==="

# 1. Verify and fix the mislabeled interpreter
if ls -Z /usr/bin/python3.14 | grep -q 'user_home_t'; then
    log "Confirmed mislabel on /usr/bin/python3.14, restoring bin_t"
    restorecon -v /usr/bin/python3.14
else
    log "python3.14 label OK (already bin_t or fixed)"
fi

# 2. Full relabel of firewalld config (rpm -V showed access errors there)
restorecon -Rv /etc/firewalld 2>&1 | tee -a "$LOG_FILE"

# 3. Belt-and-braces: verify nothing under /usr is mislabeled anymore
BAD=$(find /usr/bin /usr/sbin /usr/libexec -context '*user_home_t*' 2>/dev/null)
if [ -n "$BAD" ]; then
    log "Still mislabeled: $BAD — relabeling"
    restorecon -RvF $BAD
fi

# 4. Restart the affected services
for svc in firewalld fail2ban setroubleshootd me.proton.vpn.split_tunneling; do
    systemctl reset-failed "$svc" 2>/dev/null
    systemctl restart "$svc"
    if systemctl is-active --quiet "$svc"; then
        log "OK: $svc is running"
    else
        log "WARN: $svc still not running"
    fi
done

# 5. Final status
log "Remaining failed units:"
systemctl --failed --no-legend >> "$LOG_FILE" 2>&1
systemctl --failed --no-legend

log "=== SELinux service fix complete ==="
echo "Log saved to: $LOG_FILE"
