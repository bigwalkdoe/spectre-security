#!/bin/bash
# System Cleanup Script
# Performs regular system maintenance tasks

echo "Starting system maintenance cleanup..."

# Clean package cache
echo "Cleaning DNF package cache..."
sudo dnf clean all

# Clean old journal logs (keep last 7 days)
echo "Cleaning old journal logs..."
sudo journalctl --vacuum-time=7d

# Clean temporary files (be careful with /tmp and /var/tmp)
echo "Cleaning temporary files..."
sudo rm -rf /tmp/*/cache 2>/dev/null || true
sudo rm -rf /var/tmp/*/cache 2>/dev/null || true

# Clean user cache (safe directories only)
echo "Cleaning user cache..."
rm -rf ~/.cache/thumbnails/* 2>/dev/null || true
rm -rf ~/.cache/evolution/* 2>/dev/null || true

# Clean old downloads (older than 30 days, safer pattern)
echo "Cleaning old downloads..."
find ~/Downloads -type f -mtime +30 -name "*tmp*" -delete 2>/dev/null || true

# Clean trash (empty only if older than 7 days)
echo "Emptying trash..."
find ~/.local/share/Trash -type f -mtime +7 -delete 2>/dev/null || true

# Docker system cleanup (safe prune without volumes flag)
echo "Cleaning Docker system..."
docker system prune -f 2>/dev/null || true

# Clean Docker build cache
echo "Cleaning Docker build cache..."
docker builder prune -f 2>/dev/null || true

echo "System cleanup completed!"
logger -p user.info "System maintenance cleanup completed"
