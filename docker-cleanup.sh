#!/bin/bash
# Docker Maintenance Cleanup Script
# Run this script periodically to clean up unused Docker resources

set -e

echo "=== Docker Maintenance Cleanup ==="
echo "Starting cleanup at $(date)"

# Clean up unused images (dangling and unused)
echo "🧹 Cleaning up unused images..."
docker image prune -a -f

# Clean up build cache
echo "🧹 Cleaning up build cache..."
docker builder prune -a -f

# Clean up unused containers (stopped)
echo "🧹 Cleaning up stopped containers..."
docker container prune -f

# Clean up unused volumes (safe cleanup only)
echo "🧹 Cleaning up unused volumes..."
docker volume prune -f

# Display current Docker usage
echo "📊 Current Docker usage after cleanup:"
docker system df

echo "=== Cleanup completed at $(date) ==="