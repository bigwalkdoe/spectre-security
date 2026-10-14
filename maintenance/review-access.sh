#!/bin/bash
# Review user access and activity
set -euo pipefail

echo "=== Access Review ==="
echo ""

echo "Users with shell access:"
awk -F: '($3 >= 1000) && ($7 !~ /nologin|false/) {print $1 " (uid=" $3 ", shell=" $7 ")"}' /etc/passwd

echo ""
echo "Sudo users:"
getent group wheel 2>/dev/null || getent group sudo 2>/dev/null || echo "No sudo group found"

echo ""
echo "Docker group members:"
getent group docker 2>/dev/null | cut -d: -f4 || echo "No docker group"

echo ""
echo "Last logins (10 most recent):"
last -10 2>/dev/null || echo "No login records"

echo ""
echo "Currently logged in:"
who

echo ""
echo "Failed SSH attempts (last 50):"
sudo journalctl -u sshd --since "7 days ago" 2>/dev/null | grep "Failed password" | tail -50 || echo "No failed attempts recorded"
