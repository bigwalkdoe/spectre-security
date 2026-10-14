#!/bin/bash
# Security Baseline Prometheus Exporter
# Exposes baseline metrics for Prometheus scraping

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
METRICS_FILE="/tmp/security-baseline-metrics.prom"
TMP_FILE="${METRICS_FILE}.tmp"

# Run baseline and capture metrics
run_baseline_metrics() {
    local start_time=$(date +%s)
    
    # Phase 1: OPA Policy Tests
    local opa_start=$(date +%s%N)
    if [ -x "$SCRIPT_DIR/test-opa-policies.sh" ]; then
        "$SCRIPT_DIR/test-opa-policies.sh" > /dev/null 2>&1
        local opa_exit=$?
        local opa_duration=$((($(date +%s%N) - opa_start) / 1000000))
        if [ $opa_exit -eq 0 ]; then
            echo "security_baseline_opa_tests_passing 1" >> "$TMP_FILE"
            echo "security_baseline_opa_tests_failing 0" >> "$TMP_FILE"
        else
            echo "security_baseline_opa_tests_passing 0" >> "$TMP_FILE"
            echo "security_baseline_opa_tests_failing 1" >> "$TMP_FILE"
        fi
    else
        echo "security_baseline_opa_tests_passing 0" >> "$TMP_FILE"
        echo "security_baseline_opa_tests_failing 0" >> "$TMP_FILE"
    fi
    echo "security_baseline_opa_tests_total 42" >> "$TMP_FILE"
    echo "security_baseline_phase_duration_seconds{phase=\"opa_tests\"} $opa_duration" >> "$TMP_FILE"

    # Phase 2: Security Hardening
    local hardening_start=$(date +%s%N)
    if [ -x "$SCRIPT_DIR/run-security-hardening.sh" ]; then
        "$SCRIPT_DIR/run-security-hardening.sh" > /dev/null 2>&1
        local hardening_exit=$?
        local hardening_duration=$((($(date +%s%N) - hardening_start) / 1000000))
        echo "security_baseline_hardening_status $([ $hardening_exit -eq 0 ] && echo 1 || echo 0)" >> "$TMP_FILE"
        echo "security_baseline_phase_duration_seconds{phase=\"hardening\"} $hardening_duration" >> "$TMP_FILE"
    fi

    # Phase 3: Trivy FS Scan
    local trivy_start=$(date +%s%N)
    if command -v trivy &> /dev/null; then
        local trivy_output=$(timeout 300 trivy fs "$SCRIPT_DIR/.." --quiet --format json 2>/dev/null || echo '{}')
        local vuln_critical=$(echo "$trivy_output" | jq -r '.Results[]?.Vulnerabilities[]? | select(.Severity=="CRITICAL") | .VulnerabilityID' 2>/dev/null | wc -l)
        local vuln_high=$(echo "$trivy_output" | jq -r '.Results[]?.Vulnerabilities[]? | select(.Severity=="HIGH") | .VulnerabilityID' 2>/dev/null | wc -l)
        local vuln_medium=$(echo "$trivy_output" | jq -r '.Results[]?.Vulnerabilities[]? | select(.Severity=="MEDIUM") | .VulnerabilityID' 2>/dev/null | wc -l)
        local vuln_low=$(echo "$trivy_output" | jq -r '.Results[]?.Vulnerabilities[]? | select(.Severity=="LOW") | .VulnerabilityID' 2>/dev/null | wc -l)
        local secrets=$(echo "$trivy_output" | jq -r '.Results[]?.Secrets[]? | .RuleID' 2>/dev/null | wc -l)
        
        echo "security_baseline_trivy_vulns_critical $vuln_critical" >> "$TMP_FILE"
        echo "security_baseline_trivy_vulns_high $vuln_high" >> "$TMP_FILE"
        echo "security_baseline_trivy_vulns_medium $vuln_medium" >> "$TMP_FILE"
        echo "security_baseline_trivy_vulns_low $vuln_low" >> "$TMP_FILE"
        echo "security_baseline_trivy_secrets $secrets" >> "$TMP_FILE"
    fi
    local trivy_duration=$((($(date +%s%N) - trivy_start) / 1000000))
    echo "security_baseline_phase_duration_seconds{phase=\"trivy_fs\"} $trivy_duration" >> "$TMP_FILE"

    # Phase 4: Wazuh Status
    if [ -x "$SCRIPT_DIR/check-wazuh-status.sh" ]; then
        local wazuh_output=$("$SCRIPT_DIR/check-wazuh-status.sh" 2>/dev/null || echo "")
        local wazuh_status=$(echo "$wazuh_output" | grep -q "not installed" && echo 0 || echo 1)
        echo "security_baseline_wazuh_status $wazuh_status" >> "$TMP_FILE"
    fi

    # Phase 5: AIDE File Integrity
    if [ -x "$SCRIPT_DIR/check-file-integrity-local.sh" ]; then
        local aide_start=$(date +%s%N)
        "$SCRIPT_DIR/check-file-integrity-local.sh" > /dev/null 2>&1
        local aide_exit=$?
        local aide_duration=$((($(date +%s%N) - aide_start) / 1000000))
        echo "security_baseline_aide_status $([ $aide_exit -eq 0 ] && echo 1 || echo 0)" >> "$TMP_FILE"
        echo "security_baseline_phase_duration_seconds{phase=\"aide\"} $aide_duration" >> "$TMP_FILE"
    fi

    # Phase 6: Gitleaks Secret Scan
    local gitleaks_start=$(date +%s%N)
    if command -v gitleaks &> /dev/null || [ -x "$HOME/go/bin/gitleaks" ]; then
        GITLEAKS_CMD="${GITLEAKS_CMD:-gitleaks}"
        [ -x "$HOME/go/bin/gitleaks" ] && GITLEAKS_CMD="$HOME/go/bin/gitleaks"
        
        local gitleaks_output=$($GITLEAKS_CMD detect --source "$SCRIPT_DIR/.." --no-banner --no-git --config "$SCRIPT_DIR/../.gitleaks.toml" --report-format json 2>/dev/null || echo '[]')
        local leaks=$(echo "$gitleaks_output" | jq 'length' 2>/dev/null || echo 0)
        echo "security_baseline_gitleaks_leaks $leaks" >> "$TMP_FILE"
        echo "security_baseline_gitleaks_clean $([ $leaks -eq 0 ] && echo 1 || echo 0)" >> "$TMP_FILE"
    fi
    local gitleaks_duration=$((($(date +%s%N) - gitleaks_start) / 1000000))
    echo "security_baseline_phase_duration_seconds{phase=\"gitleaks\"} $gitleaks_duration" >> "$TMP_FILE"

    # Phase 7: Trivy Image Scan (if IMAGE_NAME set)
    if [ -n "${IMAGE_NAME:-}" ] && [ -x "$SCRIPT_DIR/trivy-image-scan.sh" ]; then
        local image_start=$(date +%s%N)
        "$SCRIPT_DIR/trivy-image-scan.sh" "$IMAGE_NAME" > /dev/null 2>&1
        local image_exit=$?
        local image_duration=$((($(date +%s%N) - image_start) / 1000000))
        echo "security_baseline_trivy_image_status $([ $image_exit -eq 0 ] && echo 1 || echo 0)" >> "$TMP_FILE"
        echo "security_baseline_phase_duration_seconds{phase=\"trivy_image\"} $image_duration" >> "$TMP_FILE"
    fi

    # Phase 8: SBOM Generation
    if [ -x "$SCRIPT_DIR/generate-sbom.sh" ]; then
        local sbom_start=$(date +%s%N)
        "$SCRIPT_DIR/generate-sbom.sh" > /dev/null 2>&1
        local sbom_exit=$?
        local sbom_duration=$((($(date +%s%N) - sbom_start) / 1000000))
        echo "security_baseline_sbom_status $([ $sbom_exit -eq 0 ] && echo 1 || echo 0)" >> "$TMP_FILE"
        echo "security_baseline_phase_duration_seconds{phase=\"sbom\"} $sbom_duration" >> "$TMP_FILE"
    fi

    # Phase 9: Drift Detection
    local drift_start=$(date +%s%N)
    if [ -x "$SCRIPT_DIR/drift-detection.sh" ]; then
        "$SCRIPT_DIR/drift-detection.sh" > /dev/null 2>&1
        local drift_exit=$?
        local drift_duration=$((($(date +%s%N) - drift_start) / 1000000))
        
        # Parse drift JSON
        local drift_json="$SCRIPT_DIR/logs/drift-report-latest.json"
        if [ -f "$drift_json" ]; then
            local drift_count=$(jq -r '.categories | to_entries | map(.value | length) | add // 0' "$drift_json" 2>/dev/null || echo 0)
            local drift_detected=$(jq -r '.drift_detected' "$drift_json" 2>/dev/null || echo false)
            
            echo "security_baseline_drift_total $drift_count" >> "$TMP_FILE"
            echo "security_baseline_drift_detected $([ "$drift_detected" = "true" ] && echo 1 || echo 0)" >> "$TMP_FILE"
            
            # Per-category drift
            jq -r '.categories | to_entries[] | "\(.key) \(.value | length)"' "$drift_json" 2>/dev/null | while read cat count; do
                echo "security_baseline_drift_by_category{category=\"$cat\"} $count" >> "$TMP_FILE"
            done
        fi
        
        echo "security_baseline_drift_status $([ $drift_exit -eq 0 ] && echo 1 || echo 0)" >> "$TMP_FILE"
        echo "security_baseline_phase_duration_seconds{phase=\"drift\"} $drift_duration" >> "$TMP_FILE"
    fi

    # Phase 10: Alerting (if configured)
    local alert_start=$(date +%s%N)
    if [ -x "$SCRIPT_DIR/alerting.sh" ]; then
        "$SCRIPT_DIR/alerting.sh" info "Test" "Exporter test" > /dev/null 2>&1
        local alert_exit=$?
        local alert_duration=$((($(date +%s%N) - alert_start) / 1000000))
        echo "security_baseline_alerting_status $([ $alert_exit -eq 0 ] && echo 1 || echo 0)" >> "$TMP_FILE"
        echo "security_baseline_phase_duration_seconds{phase=\"alerting\"} $alert_duration" >> "$TMP_FILE"
    fi

    # Overall status
    local total_duration=$((($(date +%s%N) - start_time) / 1000000))
    echo "security_baseline_total_duration_seconds $total_duration" >> "$TMP_FILE"
    echo "security_baseline_last_run_timestamp $(date +%s)" >> "$TMP_FILE"
}

# Main
echo "# Security Baseline Metrics" > "$TMP_FILE"
echo "# Generated at $(date -Iseconds)" >> "$TMP_FILE"
echo "" >> "$TMP_FILE"

run_baseline_metrics

mv "$TMP_FILE" "$METRICS_FILE"
echo "Metrics written to $METRICS_FILE"