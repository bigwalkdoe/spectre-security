#!/bin/bash
# Security Baseline Fast Prometheus Exporter
# Reads cached metrics from latest baseline run instead of re-running everything

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
METRICS_FILE="/tmp/security-baseline-metrics.prom"
TMP_FILE="${METRICS_FILE}.tmp"
LOG_DIR="$SCRIPT_DIR/logs"

# Generate metrics from latest logs (fast)
generate_fast_metrics() {
    echo "# Security Baseline Metrics (cached)" > "$TMP_FILE"
    echo "# Generated at $(date -Iseconds)" >> "$TMP_FILE"
    echo "" >> "$TMP_FILE"
    
    # OPA Tests - from latest test log
    if [ -f "$LOG_DIR/opa-tests.log" ]; then
        if grep -q "ALL TESTS PASSED" "$LOG_DIR/opa-tests.log"; then
            echo "security_baseline_opa_tests_passing 1" >> "$TMP_FILE"
            echo "security_baseline_opa_tests_failing 0" >> "$TMP_FILE"
        else
            echo "security_baseline_opa_tests_passing 0" >> "$TMP_FILE"
            echo "security_baseline_opa_tests_failing 1" >> "$TMP_FILE"
        fi
        local opa_total=$(grep -c -E "PASS|FAIL" "$LOG_DIR/opa-tests.log" 2>/dev/null | head -1 || echo 42)
        echo "security_baseline_opa_tests_total $opa_total" >> "$TMP_FILE"
    else
        echo "security_baseline_opa_tests_total 42" >> "$TMP_FILE"
        echo "security_baseline_opa_tests_passing 0" >> "$TMP_FILE"
        echo "security_baseline_opa_tests_failing 0" >> "$TMP_FILE"
    fi
    
    # Drift Detection - from latest drift report
    local latest_drift=$(ls -1t "$LOG_DIR"/drift-report-*.json 2>/dev/null | head -1)
    if [ -n "$latest_drift" ] && [ -f "$latest_drift" ]; then
        local drift_count=$(jq -r '.categories | to_entries | map(.value | length) | add // 0' "$latest_drift" 2>/dev/null || echo 0)
        local drift_detected=$(jq -r '.drift_detected // false' "$latest_drift" 2>/dev/null || echo false)
        
        echo "security_baseline_drift_total $drift_count" >> "$TMP_FILE"
        echo "security_baseline_drift_detected $([ "$drift_detected" = "true" ] && echo 1 || echo 0)" >> "$TMP_FILE"
        
        # Per-category drift
        jq -r '.categories | to_entries[] | "\(.key) \(.value | length)"' "$latest_drift" 2>/dev/null | while read cat count; do
            echo "security_baseline_drift_by_category{category=\"$cat\"} $count" >> "$TMP_FILE"
        done
    else
        echo "security_baseline_drift_total 0" >> "$TMP_FILE"
        echo "security_baseline_drift_detected 0" >> "$TMP_FILE"
    fi
    
    # Trivy Scan - from latest scan log
    local latest_trivy=$(ls -1t "$LOG_DIR"/trivy-scan*.log 2>/dev/null | head -1)
    if [ -n "$latest_trivy" ] && [ -f "$latest_trivy" ]; then
        local vuln_critical
        vuln_critical=$(grep -c "CRITICAL" "$latest_trivy" 2>/dev/null || true)
        vuln_critical=$(printf "%s" "$vuln_critical")
        local vuln_high
        vuln_high=$(grep -c "HIGH" "$latest_trivy" 2>/dev/null || true)
        vuln_high=$(printf "%s" "$vuln_high")
        local vuln_medium
        vuln_medium=$(grep -c "MEDIUM" "$latest_trivy" 2>/dev/null || true)
        vuln_medium=$(printf "%s" "$vuln_medium")
        local vuln_low
        vuln_low=$(grep -c "LOW" "$latest_trivy" 2>/dev/null || true)
        vuln_low=$(printf "%s" "$vuln_low")
        
        printf "security_baseline_trivy_vulns_critical %s\n" "$vuln_critical" >> "$TMP_FILE"
        printf "security_baseline_trivy_vulns_high %s\n" "$vuln_high" >> "$TMP_FILE"
        printf "security_baseline_trivy_vulns_medium %s\n" "$vuln_medium" >> "$TMP_FILE"
        printf "security_baseline_trivy_vulns_low %s\n" "$vuln_low" >> "$TMP_FILE"
    else
        printf "security_baseline_trivy_vulns_critical 0\n" >> "$TMP_FILE"
        printf "security_baseline_trivy_vulns_high 0\n" >> "$TMP_FILE"
        printf "security_baseline_trivy_vulns_medium 0\n" >> "$TMP_FILE"
        printf "security_baseline_trivy_vulns_low 0\n" >> "$TMP_FILE"
    fi
    
    # Gitleaks - from latest scan log
    local latest_gitleaks=$(ls -1t "$LOG_DIR"/gitleaks-scan*.log 2>/dev/null | head -1)
    if [ -n "$latest_gitleaks" ] && [ -f "$latest_gitleaks" ]; then
        # Check for "no leaks found" first (clean), then check for actual leaks
        if grep -q "no leaks found" "$latest_gitleaks" 2>/dev/null; then
            local leaks=0
        else
            local leaks=$(grep -c "leaks found:" "$latest_gitleaks" 2>/dev/null | head -1 || echo 0)
        fi
        echo "security_baseline_gitleaks_leaks $leaks" >> "$TMP_FILE"
        echo "security_baseline_gitleaks_clean $([ "$leaks" -eq 0 ] && echo 1 || echo 0)" >> "$TMP_FILE"
    else
        echo "security_baseline_gitleaks_leaks 0" >> "$TMP_FILE"
        echo "security_baseline_gitleaks_clean 1" >> "$TMP_FILE"
    fi
    
    # AIDE Status
    local latest_aide=$(ls -1t "$LOG_DIR"/aide/aide.log 2>/dev/null | head -1)
    if [ -n "$latest_aide" ] && [ -f "$latest_aide" ]; then
        local aide_status=$(grep -q "PASSED" "$latest_aide" 2>/dev/null && echo 1 || echo 0)
        echo "security_baseline_aide_status $aide_status" >> "$TMP_FILE"
    else
        echo "security_baseline_aide_status 0" >> "$TMP_FILE"
    fi
    
    # Overall baseline run timestamp
    local latest_baseline=$(ls -1t "$LOG_DIR"/baseline.log 2>/dev/null | head -1)
    if [ -n "$latest_baseline" ] && [ -f "$latest_baseline" ]; then
        local last_run=$(grep "Security baseline run completed" "$latest_baseline" | tail -1 | sed -E 's/\[([^]]+)\].*/\1/' | xargs -I{} date -d {} +%s 2>/dev/null || echo 0)
        echo "security_baseline_last_run_timestamp $last_run" >> "$TMP_FILE"
    fi
    
    # Compliance status from latest drift report
    if [ -n "$latest_drift" ] && [ -f "$latest_drift" ]; then
        local firewall_ok=$(jq -r '.categories.compliance // {} | .firewall_enabled // {} | .status == "OK"' "$latest_drift" 2>/dev/null)
        local audit_ok=$(jq -r '.categories.compliance // {} | .audit_logging_enabled // {} | .status == "OK"' "$latest_drift" 2>/dev/null)
        local ids_ok=$(jq -r '.categories.compliance // {} | .intrusion_detection_active // {} | .status == "OK"' "$latest_drift" 2>/dev/null)
        local aide_ok=$(jq -r '.categories.compliance // {} | .file_integrity_monitoring // {} | .status == "OK"' "$latest_drift" 2>/dev/null)
        
        # Convert boolean to 0/1
        firewall_ok=$([ "$firewall_ok" = "true" ] && echo 1 || echo 0)
        audit_ok=$([ "$audit_ok" = "true" ] && echo 1 || echo 0)
        ids_ok=$([ "$ids_ok" = "true" ] && echo 1 || echo 0)
        aide_ok=$([ "$aide_ok" = "true" ] && echo 1 || echo 0)
        
        echo "security_baseline_compliance_firewall $firewall_ok" >> "$TMP_FILE"
        echo "security_baseline_compliance_audit_logging $audit_ok" >> "$TMP_FILE"
        echo "security_baseline_compliance_intrusion_detection $ids_ok" >> "$TMP_FILE"
        echo "security_baseline_compliance_file_integrity $aide_ok" >> "$TMP_FILE"
    fi
}

# Main
echo "Generating fast metrics..."
generate_fast_metrics
mv "$TMP_FILE" "$METRICS_FILE"
echo "Fast metrics written to $METRICS_FILE"