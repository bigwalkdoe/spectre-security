#!/bin/bash
# SBOM Generation Script
# Generates Software Bill of Materials in multiple formats

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LOG_DIR="$SCRIPT_DIR/logs"
mkdir -p "$LOG_DIR"

DATE=$(date +%Y%m%d_%H%M%S)
SBOM_DIR="$LOG_DIR/sbom-$DATE"
mkdir -p "$SBOM_DIR"

echo "=== SBOM Generation - $DATE ===" | tee "$LOG_DIR/sbom-generation.log"
echo "Repository: $REPO_ROOT" | tee -a "$LOG_DIR/sbom-generation.log"
echo "Output: $SBOM_DIR" | tee -a "$LOG_DIR/sbom-generation.log"
echo "" | tee -a "$LOG_DIR/sbom-generation.log"

# 1. Generate SBOM for the repository (source code dependencies)
echo "--- Generating Source SBOM (CycloneDX) ---" | tee -a "$LOG_DIR/sbom-generation.log"
if command -v trivy &> /dev/null; then
    trivy fs --format cyclonedx --output "$SBOM_DIR/sbom-source.cdx.json" "$REPO_ROOT" 2>&1 | tee -a "$LOG_DIR/sbom-generation.log"
    SBOM_SOURCE_EXIT=${PIPESTATUS[0]}
else
    echo "Trivy not available for source SBOM" | tee -a "$LOG_DIR/sbom-generation.log"
    SBOM_SOURCE_EXIT=1
fi

# 2. Generate SPDX format
echo "--- Generating Source SBOM (SPDX) ---" | tee -a "$LOG_DIR/sbom-generation.log"
if command -v trivy &> /dev/null; then
    trivy fs --format spdx-json --output "$SBOM_DIR/sbom-source.spdx.json" "$REPO_ROOT" 2>&1 | tee -a "$LOG_DIR/sbom-generation.log"
    SPDX_EXIT=${PIPESTATUS[0]}
fi

# 3. Generate SBOM for Docker images if available
if [ -n "${IMAGE_NAME:-}" ] && command -v trivy &> /dev/null; then
    echo "--- Generating Image SBOM for $IMAGE_NAME ---" | tee -a "$LOG_DIR/sbom-generation.log"
    trivy image --format cyclonedx --output "$SBOM_DIR/sbom-image-$IMAGE_NAME.cdx.json" "$IMAGE_NAME" 2>&1 | tee -a "$LOG_DIR/sbom-generation.log"
    IMAGE_SBOM_EXIT=${PIPESTATUS[0]}
    
    trivy image --format spdx-json --output "$SBOM_DIR/sbom-image-$IMAGE_NAME.spdx.json" "$IMAGE_NAME" 2>&1 | tee -a "$LOG_DIR/sbom-generation.log"
    IMAGE_SPDX_EXIT=${PIPESTATUS[0]}
fi

# 4. Generate dependency list (human-readable)
echo "--- Generating Dependency List ---" | tee -a "$LOG_DIR/sbom-generation.log"
if command -v trivy &> /dev/null; then
    trivy fs --format json "$REPO_ROOT" 2>/dev/null | jq -r '.Results[]?.Packages[]? | "\(.Name)\t\(.Version)\t\(.License // "unknown")\t\(.Type)"' 2>/dev/null | sort -u > "$SBOM_DIR/dependencies.txt" || true
    echo "Dependencies saved to: $SBOM_DIR/dependencies.txt" | tee -a "$LOG_DIR/sbom-generation.log"
fi

# 5. Summary
echo "" | tee -a "$LOG_DIR/sbom-generation.log"
echo "=== SBOM Generation Summary ===" | tee -a "$LOG_DIR/sbom-generation.log"
echo "Source CycloneDX: $([ ${SBOM_SOURCE_EXIT:-1} -eq 0 ] && echo "SUCCESS" || echo "FAILED/SKIPPED")" | tee -a "$LOG_DIR/sbom-generation.log"
echo "Source SPDX: $([ ${SPDX_EXIT:-1} -eq 0 ] && echo "SUCCESS" || echo "FAILED/SKIPPED")" | tee -a "$LOG_DIR/sbom-generation.log"
if [ -n "${IMAGE_NAME:-}" ]; then
    echo "Image CycloneDX: $([ ${IMAGE_SBOM_EXIT:-1} -eq 0 ] && echo "SUCCESS" || echo "FAILED/SKIPPED")" | tee -a "$LOG_DIR/sbom-generation.log"
    echo "Image SPDX: $([ ${IMAGE_SPDX_EXIT:-1} -eq 0 ] && echo "SUCCESS" || echo "FAILED/SKIPPED")" | tee -a "$LOG_DIR/sbom-generation.log"
fi
echo "Output directory: $SBOM_DIR" | tee -a "$LOG_DIR/sbom-generation.log"

# Create latest symlink
ln -sfn "$SBOM_DIR" "$LOG_DIR/sbom-latest"

exit 0