#!/bin/bash
# Security Baseline Runner
# Orchestrates security checks and enforces OPA policies

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
POLICY_DIR="$SCRIPT_DIR/../security/opa/policies"
SCAN_DIR="$SCRIPT_DIR/.."
LOG_DIR="$SCRIPT_DIR/logs"

mkdir -p "$LOG_DIR"

# Initialize log
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_DIR/baseline.log"
}

log "Starting security baseline run..."

# 1. Run OPA policy validation
OPA_CMD="${OPA_CMD:-opa}"
if [ -x "$HOME/.local/bin/opa" ]; then
    OPA_CMD="$HOME/.local/bin/opa"
fi

if $OPA_CMD version &> /dev/null; then
    log "Validating OPA policies..."
    for policy in "$POLICY_DIR"/*.rego; do
        if [ -f "$policy" ]; then
            log "Validating $policy..."
            $OPA_CMD check "$policy" || log "ERROR: OPA validation failed for $policy"
        fi
    done
    
    # 1b. Run OPA policy tests against current infrastructure
    log "Running OPA policy tests against infrastructure data..."
    if [ -x "$SCRIPT_DIR/test-opa-policies.sh" ]; then
        OPA_CMD="$OPA_CMD" "$SCRIPT_DIR/test-opa-policies.sh" 2>&1 | tee "$LOG_DIR/opa-tests.log"
        OPA_TEST_EXIT=${PIPESTATUS[0]}
        if [ $OPA_TEST_EXIT -eq 0 ]; then
            log "OPA policy tests: ALL PASSED"
        else
            log "WARNING: OPA policy tests FAILED (exit code: $OPA_TEST_EXIT)"
        fi
    else
        log "Warning: test-opa-policies.sh not found"
    fi
else
    log "Warning: OPA not installed or not working, skipping policy validation"
fi

# 2. Run security hardening checks
log "Running security hardening checks..."
if [ -x "$SCRIPT_DIR/run-security-hardening.sh" ]; then
    "$SCRIPT_DIR/run-security-hardening.sh"
else
    log "Warning: run-security-hardening.sh not found or not executable"
fi

# 3. Run Trivy scan (filesystem scan for this repo)
log "Running Trivy scan..."
if command -v trivy &> /dev/null; then
    timeout 300 trivy fs "$SCAN_DIR" --quiet 2>&1 | tee "$LOG_DIR/trivy-scan.log"
else
    log "Warning: Trivy not installed, skipping scan"
fi

# 4. Run Wazuh status check
log "Checking Wazuh agent status..."
if [ -x "./security/check-wazuh-status.sh" ]; then
    ./security/check-wazuh-status.sh
else
    log "Warning: Wazuh status script not found"
fi

# 5. Run file integrity check
log "Running AIDE file integrity check..."
if [ -x "$SCRIPT_DIR/check-file-integrity-local.sh" ]; then
    "$SCRIPT_DIR/check-file-integrity-local.sh" || log "WARNING: AIDE check unavailable on this runner"
else
    log "Warning: AIDE check script not found"
fi

# 6. Run Gitleaks secret scanning
log "Running Gitleaks secret scan..."
if command -v gitleaks &> /dev/null || [ -x "$HOME/go/bin/gitleaks" ]; then
    GITLEAKS_CMD="${GITLEAKS_CMD:-gitleaks}"
    if [ -x "$HOME/go/bin/gitleaks" ]; then
        GITLEAKS_CMD="$HOME/go/bin/gitleaks"
    fi
    $GITLEAKS_CMD detect --source "$SCAN_DIR" --no-banner --no-git --config "$SCAN_DIR/.gitleaks.toml" 2>&1 | tee "$LOG_DIR/gitleaks-scan.log"
    GITLEAKS_EXIT=${PIPESTATUS[0]}
    if [ $GITLEAKS_EXIT -eq 0 ]; then
        log "Gitleaks scan: No secrets found"
    else
        log "WARNING: Gitleaks found potential secrets (exit code: $GITLEAKS_EXIT)"
    fi
else
    log "Warning: Gitleaks not installed, skipping secret scan"
fi

# 7. Run Trivy Docker Image Scan (optional - requires IMAGE_NAME env var)
if [ -n "${IMAGE_NAME:-}" ]; then
    log "Running Trivy Docker image scan for: $IMAGE_NAME"
    if [ -x "$SCRIPT_DIR/trivy-image-scan.sh" ]; then
        "$SCRIPT_DIR/trivy-image-scan.sh" "$IMAGE_NAME" 2>&1 | tee "$LOG_DIR/trivy-image-scan.log"
        IMAGE_SCAN_EXIT=${PIPESTATUS[0]}
        if [ $IMAGE_SCAN_EXIT -eq 0 ]; then
            log "Trivy image scan: PASSED"
        else
            log "WARNING: Trivy image scan FAILED (exit code: $IMAGE_SCAN_EXIT)"
        fi
    else
        log "Warning: trivy-image-scan.sh not found"
    fi
else
    log "Skipping Trivy image scan (set IMAGE_NAME to enable)"
fi

# 8. Generate SBOM (Software Bill of Materials)
log "Generating SBOM..."
if [ -x "$SCRIPT_DIR/generate-sbom.sh" ]; then
    "$SCRIPT_DIR/generate-sbom.sh" 2>&1 | tee "$LOG_DIR/sbom-generation.log"
    SBOM_EXIT=${PIPESTATUS[0]}
    if [ $SBOM_EXIT -eq 0 ]; then
        log "SBOM generation: COMPLETED"
    else
        log "WARNING: SBOM generation had issues (exit code: $SBOM_EXIT)"
    fi
else
    log "Warning: generate-sbom.sh not found"
fi

# 9. Run Drift Detection (compare live state vs baseline)
log "Running drift detection..."
if [ -x "$SCRIPT_DIR/drift-detection.sh" ]; then
    "$SCRIPT_DIR/drift-detection.sh" 2>&1 | tee "$LOG_DIR/drift-detection.log"
    DRIFT_EXIT=${PIPESTATUS[0]}
    if [ $DRIFT_EXIT -eq 0 ]; then
        log "Drift detection: NO DRIFT"
    else
        log "WARNING: Drift detected (exit code: $DRIFT_EXIT)"
    fi
else
    log "Warning: drift-detection.sh not found"
fi

# 10. Send alerts if configured
log "Sending alerts..."
if [ -x "$SCRIPT_DIR/alerting.sh" ]; then
    # Check if any phase failed
    ALERT_LEVEL="info"
    ALERT_MSG="Security baseline completed successfully"
    
    # Check for failures
    if [ "${DRIFT_EXIT:-0}" -ne 0 ] || [ "${OPA_TEST_EXIT:-0}" -ne 0 ] || [ "${GITLEAKS_EXIT:-0}" -ne 0 ] || [ "${IMAGE_SCAN_EXIT:-0}" -ne 0 ] || [ "${SBOM_EXIT:-0}" -ne 0 ]; then
        ALERT_LEVEL="warning"
        ALERT_MSG="Security baseline completed with warnings"
    fi
    
    # Build details
    DETAILS="Drift: ${DRIFT_EXIT:-0}
OPA Tests: ${OPA_TEST_EXIT:-0}
Gitleaks: ${GITLEAKS_EXIT:-0}
Trivy Image: ${IMAGE_SCAN_EXIT:-0}
SBOM: ${SBOM_EXIT:-0}"
    
    "$SCRIPT_DIR/alerting.sh" "$ALERT_LEVEL" "$ALERT_MSG" "$DETAILS" 2>&1 | tee -a "$LOG_DIR/alerting.log" || log "Warning: Alerting failed"
else
    log "Warning: alerting.sh not found"
fi

log "Security baseline run completed."
