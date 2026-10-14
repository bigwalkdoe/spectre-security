#!/bin/bash
# Evaluate all OPA policies
set -euo pipefail

OPA_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
POLICIES_DIR="$OPA_DIR/policies"

echo "=== OPA Policy Evaluation ==="
echo ""

# Build input data from current system state
INPUT=$(cat << EOF
{
  "firewall_enabled": $(systemctl is-active firewalld >/dev/null 2>&1 && echo true || echo false),
  "ssh_password_auth": $(grep -q "^PasswordAuthentication yes" /etc/ssh/sshd_config 2>/dev/null && echo true || echo false),
  "audit_logging_enabled": $(systemctl is-active auditd >/dev/null 2>&1 && echo true || echo false),
  "intrusion_detection_active": $(systemctl is-active fail2ban >/dev/null 2>&1 && echo true || echo false),
  "file_integrity_monitoring": $(command -v aide >/dev/null 2>&1 && echo true || echo false),
  "security_scanning_enabled": $(command -v trivy >/dev/null 2>&1 && echo true || echo false),
  "vpn_enabled": $(systemctl is-active wg-quick@wg0 >/dev/null 2>&1 && echo true || echo false),
  "remote_access": true,
  "container_network": "bridge",
  "open_ports": [22, 80, 443, 3002, 8081, 9090, 9093, 3100]
}
EOF
)

# Evaluate each policy
for policy in "$POLICIES_DIR"/*.rego; do
    policy_name=$(basename "$policy" .rego)
    echo "Policy: $policy_name"
    echo "----------------------------------------"
    
    RESULT=$(echo "$INPUT" | opa eval --format pretty \
        --data "$policy" \
        --input /dev/stdin \
        "data.$(echo "$policy_name" | tr '-' '.')" 2>/dev/null || echo "Error evaluating policy")
    
    if echo "$RESULT" | grep -q "deny"; then
        echo "VIOLATIONS:"
        echo "$RESULT" | while read line; do
            if [[ "$line" == *"Container"* ]] || [[ "$line" == *"Backup"* ]] || [[ "$line" == *"must"* ]]; then
                echo "  ✗ $line"
            fi
        done
    else
        echo "  ✓ All checks passed"
    fi
    echo ""
done

echo "=== Policy Evaluation Complete ==="

# Check for any violations and log
VIOLATIONS=$(opa eval --format json --data "$POLICIES_DIR" --input <(echo "$INPUT") "data" 2>/dev/null | grep -c "deny" || echo 0)
if [ "$VIOLATIONS" -gt 0 ]; then
    logger -p user.warning "OPA policy evaluation found $VIOLATIONS violations"
fi
