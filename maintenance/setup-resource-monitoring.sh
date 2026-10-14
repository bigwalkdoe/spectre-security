#!/bin/bash
# Resource Monitoring & Cost Optimization
set -euo pipefail

echo "=== Resource Monitoring & Cost Optimization Setup ==="
echo ""

# 1. Cost tracking
setup_cost_tracking() {
    echo "[1/4] Setting up cost tracking..."
    
    # Create cloud cost tracker
    cat > /home/deon/scripts/performance/cloud-cost-tracker.sh << 'COST'
#!/bin/bash
# Track cloud resource costs
set -euo pipefail

REPORT_DIR="/home/deon/scripts/performance/reports"
mkdir -p "$REPORT_DIR"
DATE=$(date +%Y%m%d)

echo "=== Cloud Cost Report - $DATE ===" > "$REPORT_DIR/cost-report-$DATE.md"

# AWS Cost (if AWS CLI configured)
if command -v aws >/dev/null 2>&1; then
    echo "## AWS Costs" >> "$REPORT_DIR/cost-report-$DATE.md"
    aws ce get-cost-and-usage \
        --time-period Start=$(date -d "-30 days" +%Y-%m-%d),End=$(date +%Y-%m-%d) \
        --granularity MONTHLY \
        --metrics BlendedCost \
        --output text 2>/dev/null >> "$REPORT_DIR/cost-report-$DATE.md" || \
        echo "AWS cost data not available (configure aws CLI)" >> "$REPORT_DIR/cost-report-$DATE.md"
fi

# Docker resource costs (estimated)
echo "" >> "$REPORT_DIR/cost-report-$DATE.md"
echo "## Docker Resource Usage" >> "$REPORT_DIR/cost-report-$DATE.md"
docker stats --no-stream 2>/dev/null >> "$REPORT_DIR/cost-report-$DATE.md" || true

# Disk usage by service
echo "" >> "$REPORT_DIR/cost-report-$DATE.md"
echo "## Disk Usage by Directory" >> "$REPORT_DIR/cost-report-$DATE.md"
du -sh /home/deon/scripts/ /home/deon/projects/ /backups/ /var/log/ 2>/dev/null >> "$REPORT_DIR/cost-report-$DATE.md"

echo "Cost report: $REPORT_DIR/cost-report-$DATE.md"
COST
    chmod +x /home/deon/scripts/performance/cloud-cost-tracker.sh
    echo "  Cost tracking script created"
}

# 2. Resource rightsizing
setup_rightsizing() {
    echo "[2/4] Setting up resource rightsizing..."
    
    cat > /home/deon/scripts/performance/resource-rightsizing.sh << 'RIGHTSIZE'
#!/bin/bash
# Analyze resource usage and recommend rightsizing
set -euo pipefail

echo "=== Resource Rightsizing Analysis ==="
echo ""

# Memory analysis
echo "Memory Usage by Process (top 10):"
ps aux --sort=-%mem | head -11 | awk '{printf "%-30s %-10s %-10s %-10s\n", $11, $6"KB", $4"%", $3"%"}'

echo ""
echo "Container Resource Usage:"
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}" 2>/dev/null || true

# CPU analysis
echo ""
echo "CPU Usage by Process (top 10):"
ps aux --sort=-%cpu | head -11 | awk '{printf "%-30s %-10s %-10s\n", $11, $3"%", $6"KB"}'

# Recommendations
echo ""
echo "Rightsizing Recommendations:"
echo "----------------------------------------"

# Check containers with low CPU usage
docker stats --no-stream --format "{{.Name}}\t{{.CPUPerc}}\t{{.MemPerc}}" 2>/dev/null | while read name cpu mem; do
    cpu_val=${cpu%\%}
    mem_val=${mem%\%}
    
    if [ -n "$cpu_val" ] && [ -n "$mem_val" ]; then
        if (( $(echo "$cpu_val < 5" | bc -l) )) && (( $(echo "$mem_val < 20" | bc -l) )); then
            echo "  $name: Consider reducing resources (CPU: ${cpu_val}%, Memory: ${mem_val}%)"
        elif (( $(echo "$cpu_val > 80" | bc -l) )); then
            echo "  $name: Consider increasing CPU (currently ${cpu_val}%)"
        elif (( $(echo "$mem_val > 80" | bc -l) )); then
            echo "  $name: Consider increasing memory (currently ${mem_val}%)"
        fi
    fi
done

# Disk analysis
echo ""
echo "Disk Usage Analysis:"
TOTAL_DISK=$(df / | tail -1 | awk '{print $2}')
USED_DISK=$(df / | tail -1 | awk '{print $3}')
AVAIL_DISK=$(df / | tail -1 | awk '{print $4}')
USED_PCT=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')

echo "  Total: $(numfmt --to=iec $((TOTAL_DISK * 1024)))"
echo "  Used: $(numfmt --to=iec $((USED_DISK * 1024))) ($USED_PCT%)"
echo "  Available: $(numfmt --to=iec $((AVAIL_DISK * 1024)))"

if [ "$USED_PCT" -gt 80 ]; then
    echo "  WARNING: Disk usage above 80%, consider cleanup or expansion"
fi
RIGHTSIZE
    chmod +x /home/deon/scripts/performance/resource-rightsizing.sh
    echo "  Resource rightsizing script created"
}

# 3. Automated cleanup of unused resources
setup_cleanup() {
    echo "[3/4] Setting up automated cleanup..."
    
    cat > /home/deon/scripts/maintenance/cleanup-unused-resources.sh << 'CLEANUP'
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
CLEANUP
    chmod +x /home/deon/scripts/maintenance/cleanup-unused-resources.sh
    echo "  Cleanup script created"

    # Schedule weekly cleanup
    if ! crontab -l 2>/dev/null | grep -q "cleanup-unused-resources"; then
        (crontab -l 2>/dev/null
         echo "# Weekly resource cleanup - Sunday at 4:00 AM"
         echo "0 4 * * 0 /home/deon/scripts/maintenance/cleanup-unused-resources.sh"
        ) | crontab -
        echo "  Weekly cleanup scheduled (Sunday 4:00 AM)"
    fi
}

# 4. Dashboard integration
setup_dashboard() {
    echo "[4/4] Setting up resource monitoring dashboard..."
    
    # Create Grafana dashboard JSON for resource monitoring
    cat > /home/deon/dev/github/system-maintenance/grafana-dashboards/resource-monitoring.json << 'DASHBOARD'
{
  "title": "Resource Monitoring & Cost",
  "uid": "resource-monitoring",
  "version": 1,
  "timezone": "browser",
  "panels": [
    {
      "title": "Cost by Provider",
      "type": "graph",
      "datasource": "Prometheus",
      "targets": [
        {
          "expr": "sum(aws_cost_estimated) by (service)",
          "legendFormat": "{{service}}"
        }
      ]
    },
    {
      "title": "Container Resource Usage",
      "type": "table",
      "datasource": "Prometheus",
      "targets": [
        {
          "expr": "container_memory_usage_bytes{container!=\"\"}",
          "legendFormat": "{{container}}"
        }
      ]
    },
    {
      "title": "Disk Usage Trend",
      "type": "graph",
      "datasource": "Prometheus",
      "targets": [
        {
          "expr": "100 - (node_filesystem_avail_bytes{mountpoint=\"/\"} / node_filesystem_size_bytes{mountpoint=\"/\"} * 100)",
          "legendFormat": "Disk used %"
        }
      ]
    },
    {
      "title": "Unused Resources",
      "type": "stat",
      "datasource": "Prometheus",
      "targets": [
        {
          "expr": "count(container_last_seen > (time() - 86400)) by (container_name)",
          "legendFormat": "Active containers"
        }
      ]
    }
  ],
  "tags": ["resource", "cost", "monitoring"],
  "schemaVersion": 27
}
DASHBOARD
    echo "  Resource monitoring dashboard created"
}

# Schedule cost tracking
schedule_monitoring() {
    if ! crontab -l 2>/dev/null | grep -q "cloud-cost-tracker"; then
        (crontab -l 2>/dev/null
         echo "# Resource monitoring"
         echo "0 9 * * 1 /home/deon/scripts/performance/cloud-cost-tracker.sh"
         echo "0 */4 * * * /home/deon/scripts/performance/resource-rightsizing.sh"
        ) | crontab -
        echo "  Resource monitoring scheduled"
    fi
}

# Run all
setup_cost_tracking
echo ""
setup_rightsizing
echo ""
setup_cleanup
echo ""
setup_dashboard
echo ""
schedule_monitoring

echo ""
echo "=== Resource Monitoring & Cost Optimization Setup Complete ==="
echo ""
echo "Components:"
echo "  - Cloud cost tracking (weekly)"
echo "  - Resource rightsizing analysis (every 4 hours)"
echo "  - Automated cleanup of unused resources (weekly)"
echo "  - Grafana dashboard for resource monitoring"
echo ""
echo "Scripts:"
echo "  - /home/deon/scripts/performance/cloud-cost-tracker.sh"
echo "  - /home/deon/scripts/performance/resource-rightsizing.sh"
echo "  - /home/deon/scripts/maintenance/cleanup-unused-resources.sh"
