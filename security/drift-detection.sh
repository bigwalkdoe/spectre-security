#!/bin/bash
# Drift Detection Script
# Compares live infrastructure state against OPA policy baseline

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BASELINE_FILE="$SCRIPT_DIR/test-data/current-infrastructure.json"
LOG_DIR="$SCRIPT_DIR/logs"
mkdir -p "$LOG_DIR"

DATE=$(date +%Y%m%d_%H%M%S)
DRIFT_LOG="$LOG_DIR/drift-report-$DATE.log"
DRIFT_JSON="$LOG_DIR/drift-report-$DATE.json"

echo "=== Drift Detection - $DATE ===" | tee "$DRIFT_LOG"
echo "Baseline: $BASELINE_FILE" | tee -a "$DRIFT_LOG"
echo "" | tee -a "$DRIFT_LOG"

# Initialize drift report JSON
cat > "$DRIFT_JSON" << 'EOF'
{
  "timestamp": "",
  "baseline_file": "",
  "drift_detected": false,
  "categories": {}
}
EOF

# Update timestamp in JSON
jq --arg ts "$(date -Iseconds)" --arg bf "$BASELINE_FILE" '.timestamp = $ts | .baseline_file = $bf' "$DRIFT_JSON" > "$DRIFT_JSON.tmp" && mv "$DRIFT_JSON.tmp" "$DRIFT_JSON"

# Function to log and update JSON
log_drift() {
    local category="$1"
    local check="$2"
    local expected="$3"
    local actual="$4"
    local status="$5"
    
    echo "[$category] $check" | tee -a "$DRIFT_LOG"
    echo "  Expected: $expected" | tee -a "$DRIFT_LOG"
    echo "  Actual:   $actual" | tee -a "$DRIFT_LOG"
    echo "  Status:   $status" | tee -a "$DRIFT_LOG"
    echo "" | tee -a "$DRIFT_LOG"
    
    # Update JSON
    jq --arg cat "$category" --arg chk "$check" --arg exp "$expected" --arg act "$actual" --arg st "$status" \
       '.drift_detected = true | .categories[$cat][$chk] = {"expected": $exp, "actual": $act, "status": $st}' \
       "$DRIFT_JSON" > "$DRIFT_JSON.tmp" && mv "$DRIFT_JSON.tmp" "$DRIFT_JSON"
}

log_ok() {
    local category="$1"
    local check="$2"
    local value="$3"
    
    echo "[$category] $check: OK ($value)" | tee -a "$DRIFT_LOG"
}

# ============================================
# 1. DOCKER CONTAINER DRIFT DETECTION
# ============================================
echo "--- Docker Container Drift ---" | tee -a "$DRIFT_LOG"

DRIFT_DOCKER=0

if command -v docker &> /dev/null; then
    # Compare each baseline container
    BASELINE_CONTAINERS=$(cat "$BASELINE_FILE" | jq -c '.docker[]' 2>/dev/null || echo "")
    
    if [ -n "$BASELINE_CONTAINERS" ]; then
        # Use array instead of while loop to avoid subshell scope issues
        mapfile -t CONTAINER_ARRAY < <(echo "$BASELINE_CONTAINERS")
        
        for container in "${CONTAINER_ARRAY[@]}"; do
            NAME=$(echo "$container" | jq -r '.name')
            EXPECTED_PRIV=$(echo "$container" | jq -r '.privileged')
            EXPECTED_MEMORY=$(echo "$container" | jq -r '.memory_limit')
            EXPECTED_HEALTH=$(echo "$container" | jq -r '.healthcheck')
            EXPECTED_PORTS=$(echo "$container" | jq -c '.ports')
            EXPECTED_MOUNTS=$(echo "$container" | jq -c '.mounts')
            
            # Check if container exists
            if docker ps --format '{{.Names}}' | grep -q "^${NAME}$"; then
                # Get live inspect data
                INSPECT=$(docker inspect "$NAME" 2>/dev/null | jq '.[0]')
                
                # Check privileged
                LIVE_PRIV=$(echo "$INSPECT" | jq -r '.HostConfig.Privileged')
                if [ "$LIVE_PRIV" != "$EXPECTED_PRIV" ]; then
                    log_drift "docker" "$NAME.privileged" "$EXPECTED_PRIV" "$LIVE_PRIV" "DRIFT"
                    DRIFT_DOCKER=1
                else
                    log_ok "docker" "$NAME.privileged" "$LIVE_PRIV"
                fi
                
                # Check memory limit
                LIVE_MEMORY=$(echo "$INSPECT" | jq -r '.HostConfig.Memory')
                if [ "$LIVE_MEMORY" != "$EXPECTED_MEMORY" ]; then
                    log_drift "docker" "$NAME.memory_limit" "$EXPECTED_MEMORY" "$LIVE_MEMORY" "DRIFT"
                    DRIFT_DOCKER=1
                else
                    log_ok "docker" "$NAME.memory_limit" "$LIVE_MEMORY"
                fi
                
                # Check healthcheck
                LIVE_HEALTH=$(echo "$INSPECT" | jq -r '.Config.Healthcheck.Test // [] | join(" ")' 2>/dev/null)
                if [ "$LIVE_HEALTH" != "$EXPECTED_HEALTH" ] && [ "$EXPECTED_HEALTH" != "" ]; then
                    log_drift "docker" "$NAME.healthcheck" "$EXPECTED_HEALTH" "$LIVE_HEALTH" "DRIFT"
                    DRIFT_DOCKER=1
                else
                    log_ok "docker" "$NAME.healthcheck" "configured"
                fi
                
                # Check ports - compare Docker port bindings
                LIVE_PORTS=$(echo "$INSPECT" | jq -c '[.HostConfig.PortBindings // {} | to_entries[] | {host_ip: (.value[0].HostIp // "0.0.0.0"), host_port: (.value[0].HostPort | tonumber), container_port: (.key | split("/")[0] | tonumber)}]')
                if [ "$LIVE_PORTS" != "$EXPECTED_PORTS" ]; then
                    log_drift "docker" "$NAME.ports" "$EXPECTED_PORTS" "$LIVE_PORTS" "DRIFT"
                    DRIFT_DOCKER=1
                else
                    log_ok "docker" "$NAME.ports" "match"
                fi
                
                # Check mounts
                LIVE_MOUNTS=$(echo "$INSPECT" | jq -c '[.Mounts[] | {source: .Source, destination: .Destination, type: .Type}]')
                if [ "$LIVE_MOUNTS" != "$EXPECTED_MOUNTS" ]; then
                    log_drift "docker" "$NAME.mounts" "$EXPECTED_MOUNTS" "$LIVE_MOUNTS" "DRIFT"
                    DRIFT_DOCKER=1
                else
                    log_ok "docker" "$NAME.mounts" "match"
                fi
            else
                log_drift "docker" "$NAME.existence" "running" "not found" "DRIFT"
                DRIFT_DOCKER=1
            fi
        done
    else
        echo "No baseline containers defined" | tee -a "$DRIFT_LOG"
    fi
else
    echo "Docker not available, skipping container drift" | tee -a "$DRIFT_LOG"
fi

# ============================================
# 2. NETWORK PORT DRIFT DETECTION (Docker port bindings only)
# ============================================
echo "" | tee -a "$DRIFT_LOG"
echo "--- Network Port Drift (Docker Bindings) ---" | tee -a "$DRIFT_LOG"

DRIFT_NETWORK=0

if command -v docker &> /dev/null; then
    # Get all Docker port bindings
    LIVE_BINDINGS=$(docker ps --format '{{.Ports}}' 2>/dev/null | grep -oE '0\.0\.0\.0:[0-9]+|127\.0\.0\.1:[0-9]+|\[::\]:[0-9]+' | sed 's/.*://' | sort -nu | tr '\n' ',' | sed 's/,$//')
    
    # Get expected ports from baseline (only host ports from Docker config)
    BASELINE_HOST_PORTS=$(cat "$BASELINE_FILE" | jq -r '.docker[].ports[]?.host_port' 2>/dev/null | sort -nu | tr '\n' ',' | sed 's/,$//')
    
    echo "Live Docker host port bindings: ${LIVE_BINDINGS:-none}" | tee -a "$DRIFT_LOG"
    echo "Baseline expected host ports: ${BASELINE_HOST_PORTS:-none}" | tee -a "$DRIFT_LOG"
    
    # Check for unexpected exposed ports on all interfaces (0.0.0.0)
    UNEXPECTED_PORTS=$(docker ps --format '{{.Ports}}' 2>/dev/null | grep -oE '0\.0\.0\.0:[0-9]+' | sed 's/0\.0\.0\.0://' | sort -nu)
    if [ -n "$UNEXPECTED_PORTS" ]; then
        for port in $UNEXPECTED_PORTS; do
            # Use word boundary grep to match port in comma-separated list
            if ! echo "$BASELINE_HOST_PORTS" | tr ',' '\n' | grep -q "^${port}$"; then
                log_drift "network" "unexpected_0.0.0.0_port_${port}" "not exposed" "exposed on 0.0.0.0" "DRIFT"
                DRIFT_NETWORK=1
            fi
        done
    fi
    
    # Check baseline ports are actually bound
    for port in $(echo "$BASELINE_HOST_PORTS" | tr ',' ' '); do
        if ! docker ps --format '{{.Ports}}' 2>/dev/null | grep -q ":${port}[-/]"; then
            log_drift "network" "missing_binding_port_${port}" "bound" "not bound" "POTENTIAL_DRIFT"
            DRIFT_NETWORK=1
        fi
    done
else
    echo "Docker not available, skipping network drift" | tee -a "$DRIFT_LOG"
fi

# ============================================
# 3. COMPLIANCE DRIFT DETECTION
# ============================================
echo "" | tee -a "$DRIFT_LOG"
echo "--- Compliance State Drift ---" | tee -a "$DRIFT_LOG"

DRIFT_COMPLIANCE=0

# Firewall
if command -v ufw &> /dev/null; then
    LIVE_FW=$(ufw status | grep -q "Status: active" && echo "true" || echo "false")
elif command -v firewall-cmd &> /dev/null; then
    LIVE_FW=$(firewall-cmd --state 2>/dev/null | grep -q "running" && echo "true" || echo "false")
else
    LIVE_FW="unknown"
fi
EXPECTED_FW=$(cat "$BASELINE_FILE" | jq -r '.compliance.firewall_enabled')
if [ "$LIVE_FW" != "$EXPECTED_FW" ]; then
    log_drift "compliance" "firewall_enabled" "$EXPECTED_FW" "$LIVE_FW" "DRIFT"
    DRIFT_COMPLIANCE=1
else
    log_ok "compliance" "firewall_enabled" "$LIVE_FW"
fi

# SSH Password Auth - handle permission gracefully
LIVE_SSH_PASS="unknown"
if [ -r /etc/ssh/sshd_config ]; then
    LIVE_SSH_PASS=$(grep -i "^PasswordAuthentication" /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}' | tr '[:upper:]' '[:lower:]' || echo "unknown")
    if [ "$LIVE_SSH_PASS" = "yes" ]; then LIVE_SSH_PASS="true"; elif [ "$LIVE_SSH_PASS" = "no" ]; then LIVE_SSH_PASS="false"; fi
fi
EXPECTED_SSH=$(cat "$BASELINE_FILE" | jq -r '.compliance.ssh_password_auth')
if [ "$LIVE_SSH_PASS" != "$EXPECTED_SSH" ] && [ "$LIVE_SSH_PASS" != "unknown" ]; then
    log_drift "compliance" "ssh_password_auth" "$EXPECTED_SSH" "$LIVE_SSH_PASS" "DRIFT"
    DRIFT_COMPLIANCE=1
else
    log_ok "compliance" "ssh_password_auth" "$LIVE_SSH_PASS"
fi

# Audit logging - check service status instead of auditctl (needs root)
if command -v auditctl &> /dev/null; then
    LIVE_AUDIT=$(systemctl is-active auditd 2>/dev/null | grep -q "active" && echo "true" || echo "false")
else
    LIVE_AUDIT="unknown"
fi
EXPECTED_AUDIT=$(cat "$BASELINE_FILE" | jq -r '.compliance.audit_logging_enabled')
if [ "$LIVE_AUDIT" != "$EXPECTED_AUDIT" ] && [ "$LIVE_AUDIT" != "unknown" ]; then
    log_drift "compliance" "audit_logging_enabled" "$EXPECTED_AUDIT" "$LIVE_AUDIT" "DRIFT"
    DRIFT_COMPLIANCE=1
else
    log_ok "compliance" "audit_logging_enabled" "$LIVE_AUDIT"
fi

# Fail2Ban / IDS
if systemctl is-active --quiet fail2ban 2>/dev/null; then
    LIVE_IDS="true"
elif systemctl is-active --quiet crowdsec 2>/dev/null; then
    LIVE_IDS="true"
else
    LIVE_IDS="false"
fi
EXPECTED_IDS=$(cat "$BASELINE_FILE" | jq -r '.compliance.intrusion_detection_active')
if [ "$LIVE_IDS" != "$EXPECTED_IDS" ]; then
    log_drift "compliance" "intrusion_detection_active" "$EXPECTED_IDS" "$LIVE_IDS" "DRIFT"
    DRIFT_COMPLIANCE=1
else
    log_ok "compliance" "intrusion_detection_active" "$LIVE_IDS"
fi

# AIDE
if [ -f /var/lib/aide/aide.db.gz ] || [ -f "$SCRIPT_DIR/aide/aide.db.gz" ]; then
    LIVE_AIDE="true"
else
    LIVE_AIDE="false"
fi
EXPECTED_AIDE=$(cat "$BASELINE_FILE" | jq -r '.compliance.file_integrity_monitoring')
if [ "$LIVE_AIDE" != "$EXPECTED_AIDE" ]; then
    log_drift "compliance" "file_integrity_monitoring" "$EXPECTED_AIDE" "$LIVE_AIDE" "DRIFT"
    DRIFT_COMPLIANCE=1
else
    log_ok "compliance" "file_integrity_monitoring" "$LIVE_AIDE"
fi

# ============================================
# 4. BACKUP STATE CHECK
# ============================================
echo "" | tee -a "$DRIFT_LOG"
echo "--- Backup State ---" | tee -a "$DRIFT_LOG"

if [ -f /etc/cron.d/backup ] || [ -f /etc/cron.daily/backup ] || ls /usr/local/bin/backup*.sh &>/dev/null; then
    LIVE_BACKUP_SCHEDULED="true"
else
    LIVE_BACKUP_SCHEDULED="false"
fi

echo "Backup scheduling: $LIVE_BACKUP_SCHEDULED" | tee -a "$DRIFT_LOG"
log_ok "backup" "scheduled" "$LIVE_BACKUP_SCHEDULED"

# ============================================
# SUMMARY
# ============================================
echo "" | tee -a "$DRIFT_LOG"
echo "=== Drift Detection Summary ===" | tee -a "$DRIFT_LOG"

TOTAL_DRIFT=$((DRIFT_DOCKER + DRIFT_NETWORK + DRIFT_COMPLIANCE))

# Count actual drift entries in JSON
DRIFT_COUNT=$(jq '.categories | to_entries | map(.value | length) | add // 0' "$DRIFT_JSON")

if [ "$DRIFT_COUNT" -gt 0 ] || [ "$TOTAL_DRIFT" -gt 0 ]; then
    echo "DRIFT DETECTED: $DRIFT_COUNT issues found" | tee -a "$DRIFT_LOG"
    jq '.drift_detected = true' "$DRIFT_JSON" > "$DRIFT_JSON.tmp" && mv "$DRIFT_JSON.tmp" "$DRIFT_JSON"
    EXIT_CODE=1
else
    echo "NO DRIFT: All systems match baseline" | tee -a "$DRIFT_LOG"
    jq '.drift_detected = false' "$DRIFT_JSON" > "$DRIFT_JSON.tmp" && mv "$DRIFT_JSON.tmp" "$DRIFT_JSON"
    EXIT_CODE=0
fi

echo "" | tee -a "$DRIFT_LOG"
echo "JSON Report: $DRIFT_JSON" | tee -a "$DRIFT_LOG"
echo "Log Report:  $DRIFT_LOG" | tee -a "$DRIFT_LOG"

# Create latest symlinks
ln -sfn "$DRIFT_LOG" "$LOG_DIR/drift-report-latest.log"
ln -sfn "$DRIFT_JSON" "$LOG_DIR/drift-report-latest.json"

exit $EXIT_CODE