#!/bin/bash
# Comprehensive Trivy vulnerability scan
set -euo pipefail

REPORT_DIR="/home/deon/scripts/security/reports"
DATE=$(date +%Y%m%d_%H%M%S)
mkdir -p "$REPORT_DIR"

echo "=== Trivy Security Scan - $DATE ==="

# Scan Docker images
echo "Scanning Docker images..."
docker images --format "{{.Repository}}:{{.Tag}}" | grep -v "<none>" | sort -u | while read image; do
    echo "  Scanning: $image"
    trivy image --severity HIGH,CRITICAL --format json -o "$REPORT_DIR/trivy_image_$(echo $image | tr '/:' '__')_$DATE.json" "$image" 2>/dev/null || true
    trivy image --severity HIGH,CRITICAL "$image" 2>/dev/null | tail -20 || true
done

# Scan filesystem
echo "Scanning filesystem..."
trivy fs --severity HIGH,CRITICAL --format json -o "$REPORT_DIR/trivy_fs_$DATE.json" /home/deon/projects 2>/dev/null || true
trivy fs --severity HIGH,CRITICAL /home/deon/projects 2>/dev/null | tail -20 || true

# Scan Git repos
echo "Scanning Git repositories..."
for repo in /home/deon/projects/*/; do
    if [ -d "$repo/.git" ]; then
        echo "  Scanning: $(basename $repo)"
        trivy repo --severity HIGH,CRITICAL --format json -o "$REPORT_DIR/trivy_repo_$(basename $repo)_$DATE.json" "$repo" 2>/dev/null || true
    fi
done

# Generate summary
echo ""
echo "=== Scan Summary ==="
echo "Reports saved to: $REPORT_DIR/"
echo ""
echo "View JSON reports for detailed findings"
echo "Quick summary per image: trivy image --severity HIGH,CRITICAL <image>"

# Check for critical vulnerabilities
if ls "$REPORT_DIR"/trivy_image_*_"$DATE".json >/dev/null 2>&1; then
    TOTAL_CRITICAL=$(grep -o '"Severity":"CRITICAL"' "$REPORT_DIR"/trivy_*_"$DATE".json 2>/dev/null | wc -l || echo 0)
    TOTAL_HIGH=$(grep -o '"Severity":"HIGH"' "$REPORT_DIR"/trivy_*_"$DATE".json 2>/dev/null | wc -l || echo 0)
    echo ""
    echo "$TOTAL_CRITICAL CRITICAL, $TOTAL_HIGH HIGH vulnerabilities found"
    
    if [ "$TOTAL_CRITICAL" -gt 0 ]; then
        logger -p user.warning "Trivy scan found $TOTAL_CRITICAL critical vulnerabilities"
    fi
fi

echo ""
echo "Trivy scan completed: $DATE"
