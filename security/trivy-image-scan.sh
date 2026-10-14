#!/bin/bash
# Trivy Docker Image Security Scan
# Scans Docker images for vulnerabilities and misconfigurations

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$SCRIPT_DIR/logs"
mkdir -p "$LOG_DIR"

IMAGE_NAME="${1:-}"
if [ -z "$IMAGE_NAME" ]; then
    echo "Usage: $0 <image_name>"
    echo "Example: $0 nginx:latest"
    echo "Example: $0 myregistry.com/myapp:v1.0.0"
    exit 1
fi

DATE=$(date +%Y%m%d_%H%M%S)
LOG_FILE="$LOG_DIR/trivy-image-scan-$DATE.log"

echo "=== Trivy Image Scan - $DATE ===" | tee "$LOG_FILE"
echo "Scanning image: $IMAGE_NAME" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# Scan for vulnerabilities
echo "--- Vulnerability Scan ---" | tee -a "$LOG_FILE"
trivy image --severity CRITICAL,HIGH,MEDIUM --ignore-unfixed --format table "$IMAGE_NAME" 2>&1 | tee -a "$LOG_FILE"
VULN_EXIT=${PIPESTATUS[0]}

# Scan for misconfigurations
echo "" | tee -a "$LOG_FILE"
echo "--- Misconfiguration Scan ---" | tee -a "$LOG_FILE"
trivy image --scanners misconfig --format table "$IMAGE_NAME" 2>&1 | tee -a "$LOG_FILE"
MISCONFIG_EXIT=${PIPESTATUS[0]}

# Scan for secrets
echo "" | tee -a "$LOG_FILE"
echo "--- Secret Scan ---" | tee -a "$LOG_FILE"
trivy image --scanners secret --format table "$IMAGE_NAME" 2>&1 | tee -a "$LOG_FILE"
SECRET_EXIT=${PIPESTATUS[0]}

# Generate SARIF for CI/CD
echo "" | tee -a "$LOG_FILE"
echo "--- Generating SARIF Report ---" | tee -a "$LOG_FILE"
trivy image --severity CRITICAL,HIGH --format sarif --output "$LOG_DIR/trivy-image-$DATE.sarif" "$IMAGE_NAME" 2>&1 | tee -a "$LOG_FILE"
SARIF_EXIT=${PIPESTATUS[0]}

# Summary
echo "" | tee -a "$LOG_FILE"
echo "=== Scan Summary ===" | tee -a "$LOG_FILE"
echo "Vulnerability scan: $([ $VULN_EXIT -eq 0 ] && echo "PASSED" || echo "FAILED (exit: $VULN_EXIT)")" | tee -a "$LOG_FILE"
echo "Misconfiguration scan: $([ $MISCONFIG_EXIT -eq 0 ] && echo "PASSED" || echo "FAILED (exit: $MISCONFIG_EXIT)")" | tee -a "$LOG_FILE"
echo "Secret scan: $([ $SECRET_EXIT -eq 0 ] && echo "PASSED" || echo "FAILED (exit: $SECRET_EXIT)")" | tee -a "$LOG_FILE"
echo "SARIF report: $([ $SARIF_EXIT -eq 0 ] && echo "Generated" || echo "Failed")" | tee -a "$LOG_FILE"
echo "Log file: $LOG_FILE" | tee -a "$LOG_FILE"
echo "SARIF file: $LOG_DIR/trivy-image-$DATE.sarif" | tee -a "$LOG_FILE"

# Exit with error if any scan failed
if [ $VULN_EXIT -ne 0 ] || [ $MISCONFIG_EXIT -ne 0 ] || [ $SECRET_EXIT -ne 0 ]; then
    exit 1
fi

exit 0