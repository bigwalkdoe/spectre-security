#!/bin/bash
# Automated cleanup of unused resources
set -euo pipefail

LOG_FILE="/var/log/resource-cleanup.log"
DATE=$(date +%Y%m%d_%H%M%S)

echo "==========================================" >> "$LOG_FILE"
echo "Resource Cleanup - $DATE" >> "$LOG_FILE"
echo "==========================================" >> "$LOG_FILE"

# 1. Docker cleanup
echo "Cleaning Docker resources..." >> "$LOG_FILE"

# Remove unused containers
CONTAINERS_REMOVED=$(docker container prune -f 2>/dev/null | grep -oP 'Total reclaimed space: \K[0-9.]+[A-Z]?' || echo 0)
echo "  Removed stopped containers" >> "$LOG_FILE"

# Remove unused images
IMAGES_REMOVED=$(docker image prune -af 2>/dev/null | grep -oP 'Total reclaimed space: \K[0-9.]+[A-Z]?' || echo 0)
echo "  Removed unused Docker images" >> "$LOG_FILE"

# Remove unused volumes
VOLUMES_REMOVED=$(docker volume prune -f 2>/dev/null | grep -oP 'Total reclaimed space: \K[0-9.]+[A-Z]?' || echo 0)
echo "  Removed unused Docker volumes" >> "$LOG_FILE"

# Remove unused build cache
BUILD_CACHE=$(docker builder prune -af 2>/dev/null | grep -oP 'Total reclaimed space: \K[0-9.]+[A-Z]?' || echo 0)
echo "  Cleaned Docker build cache" >> "$LOG_FILE"

# 2. Old backup cleanup
echo "Cleaning old backups..." >> "$LOG_FILE"
for dir in databases docker-volumes configurations projects; do
    if [ -d "/backups/$dir" ]; then
        OLD_FILES=$(find "/backups/$dir" -type f -mtime +30 -delete -print | wc -l)
        echo "  Removed $OLD_FILES old files from /backups/$dir" >> "$LOG_FILE"
    fi
done

# 3. Log cleanup
echo "Cleaning old logs..." >> "$LOG_FILE"
find /var/log -name "*.gz" -mtime +7 -delete -print 2>/dev/null | wc -l | xargs -I{} echo "  Removed {} old log archives"

# 4. System cache cleanup
echo "Cleaning system caches..." >> "$LOG_FILE"
sudo dnf clean all 2>/dev/null || sudo apt-get clean 2>/dev/null || true

# Calculate total space reclaimed
TOTAL_SPACE=$(df -h / | tail -1 | awk '{print $4}')
echo "" >> "$LOG_FILE"
echo "Cleanup complete. Available disk: $TOTAL_SPACE" >> "$LOG_FILE"
logger -p user.info "Resource cleanup completed. Available: $TOTAL_SPACE"

echo "Resource cleanup completed: $DATE"
echo "Available disk: $TOTAL_SPACE"
