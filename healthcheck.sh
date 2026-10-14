#!/bin/bash

echo "===== SYSTEM HEALTH REPORT ====="
echo

echo "Hostname: $(hostname)"
echo "Date: $(date)"
echo

echo "===== CPU LOAD ====="
uptime
echo

echo "===== MEMORY ====="
free -h
echo

echo "===== DISK USAGE ====="
df -h /
echo

echo "===== TOP MEMORY CONSUMERS ====="
ps aux --sort=-%mem | head -10
echo

echo "===== TOP CPU CONSUMERS ====="
ps aux --sort=-%cpu | head -10
echo

echo "===== PODMAN CONTAINERS ====="
podman ps
echo

echo "===== DOCKER CONTAINERS ====="
docker ps 2>/dev/null
echo

echo "===== POSTGRESQL ====="
systemctl is-active postgresql
echo

echo "===== RABBITMQ ====="
systemctl is-active rabbitmq-server
echo

echo "===== FAILED SERVICES ====="
systemctl --failed
echo

echo "===== OPEN PORTS ====="
ss -tulpn | head -20
echo

echo "===== SELINUX STATUS ====="
getenforce
echo

echo "===== SYSTEM UPDATES AVAILABLE ====="
dnf check-update 2>/dev/null | head -20
echo

echo "===== REPORT COMPLETE ====="
