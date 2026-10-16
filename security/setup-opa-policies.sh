#!/bin/bash
# Open Policy Agent (OPA) for policy-as-code
set -euo pipefail
# Resolve the invoking user's home and this repository's root. Under sudo,
# $HOME is /root, so fall back to $SUDO_USER before trusting it. Both may be
# overridden: SPECTRE_HOME=/srv/secure SPECTRE_REPO=/opt/spectre-security
_spectre_here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SPECTRE_HOME="${SPECTRE_HOME:-$(getent passwd "${SUDO_USER:-$USER}" 2>/dev/null | cut -d: -f6)}"
SPECTRE_HOME="${SPECTRE_HOME:-$HOME}"
SPECTRE_REPO="${SPECTRE_REPO:-$(git -C "$_spectre_here" rev-parse --show-toplevel 2>/dev/null || echo "$_spectre_here")}"

echo "=== Open Policy Agent Setup ==="
echo ""

OPA_DIR="${SPECTRE_REPO}/security/opa"
mkdir -p "$OPA_DIR/policies"

setup_opa() {
    echo "Installing OPA..."
    if ! command -v opa >/dev/null 2>&1; then
        wget -q https://openpolicyagent.org/downloads/latest/opa_linux_amd64 -O /tmp/opa
        sudo mv /tmp/opa /usr/local/bin/opa
        sudo chmod +x /usr/local/bin/opa
        echo "  OPA installed"
    fi
}

create_policies() {
    echo "Creating OPA policies..."

    # Docker security policy
    cat > "$OPA_DIR/policies/docker-security.rego" << 'DOCKER_POLICY'
package docker.security

# Deny containers running with privileged mode
deny[msg] {
    input.privileged == true
    msg = sprintf("Container %s is running in privileged mode", [input.name])
}

# Deny containers with bind mounts to sensitive paths
deny[msg] {
    mount := input.mounts[_]
    sensitive_paths := ["/etc", "/var/run", "/proc", "/sys", "/dev"]
    startswith(mount.source, sensitive_paths[_])
    msg = sprintf("Container %s has sensitive bind mount: %s", [input.name, mount.source])
}

# Deny containers without resource limits
deny[msg] {
    input.memory_limit == 0
    msg = sprintf("Container %s has no memory limit", [input.name])
}

# Deny containers exposed on all interfaces (0.0.0.0)
deny[msg] {
    port := input.ports[_]
    port.host_ip == "0.0.0.0"
    msg = sprintf("Container %s exposes port %d on all interfaces", [input.name, port.host_port])
}

# Require healthcheck
deny[msg] {
    input.healthcheck == ""
    msg = sprintf("Container %s has no healthcheck configured", [input.name])
}
DOCKER_POLICY

    # Backup policy
    cat > "$OPA_DIR/policies/backup-policy.rego" << 'BACKUP_POLICY'
package backup.policy

# Backups must be encrypted
deny[msg] {
    not input.encrypted
    msg = "Backups must be encrypted at rest"
}

# Backups must be retained for minimum 7 days
deny[msg] {
    input.retention_days < 7
    msg = sprintf("Backup retention (%d days) is less than minimum 7 days", [input.retention_days])
}

# Backups must have off-site replication
deny[msg] {
    not input.offsite_replication
    msg = "Backups must be replicated off-site"
}

# Backup must complete within 24 hours
deny[msg] {
    input.last_success_age > 86400
    msg = "Last successful backup is more than 24 hours old"
}
BACKUP_POLICY

    # Security compliance policy
    cat > "$OPA_DIR/policies/security-compliance.rego" << 'SEC_POLICY'
package security.compliance

# Firewall must be enabled
deny[msg] {
    not input.firewall_enabled
    msg = "Firewall must be enabled on all systems"
}

# SSH must use key-based auth
deny[msg] {
    input.ssh_password_auth == true
    msg = "SSH password authentication must be disabled"
}

# Audit logging must be enabled
deny[msg] {
    not input.audit_logging_enabled
    msg = "Audit logging must be enabled"
}

# Intrusion detection must be active
deny[msg] {
    not input.intrusion_detection_active
    msg = "Intrusion detection (Fail2Ban) must be active"
}

# File integrity monitoring
deny[msg] {
    not input.file_integrity_monitoring
    msg = "File integrity monitoring (AIDE) must be active"
}

# Automated security scanning
deny[msg] {
    not input.security_scanning_enabled
    msg = "Automated security scanning must be enabled"
}
SEC_POLICY

    # Network security policy
    cat > "$OPA_DIR/policies/network-security.rego" << 'NET_POLICY'
package network.security

# VPN required for remote access
deny[msg] {
    input.remote_access == true
    not input.vpn_enabled
    msg = "Remote access requires VPN"
}

# Container networks should be isolated
deny[msg] {
    input.container_network == "host"
    msg = "Container host networking is not allowed"
}

# Unused ports must be closed
deny[msg] {
    port := input.open_ports[_]
    port > 10000
    not allowed_port(port)
    msg = sprintf("Port %d is open but not in allowed list", [port])
}

allowed_port(port) {
    port == 22    # SSH
    port == 80    # HTTP
    port == 443   # HTTPS
    port == 3002  # Grafana
    port == 9090  # Prometheus
    port == 9093  # Alertmanager
    port == 8081  # Web Dashboard
    port == 3100  # Loki
}
NET_POLICY
    echo "  OPA policies created in $OPA_DIR/policies/"
}

create_evaluation_script() {
    echo "Creating OPA evaluation script..."

    cat > "$OPA_DIR/evaluate-policies.sh" << 'EVAL'
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
EVAL
    chmod +x "$OPA_DIR/evaluate-policies.sh"
    echo "  Evaluation script created"
}

create_kubernetes_admission() {
    # Skip K8s admission controller but document it
    cat > "$OPA_DIR/kubernetes-admission/README.md" << 'K8S_ADMIT'
# Kubernetes Admission Controller with OPA

To use OPA as an admission controller in Kubernetes:

1. Deploy OPA as a webhook:
```yaml
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingWebhookConfiguration
metadata:
  name: opa-validating-webhook
webhooks:
  - name: validating-webhook.openpolicyagent.org
    rules:
      - operations: ["CREATE", "UPDATE"]
        apiGroups: ["*"]
        apiVersions: ["*"]
        resources: ["pods", "deployments", "services"]
    clientConfig:
      service:
        name: opa
        namespace: opa
        path: /v1/admit
    admissionReviewVersions: ["v1"]
```

2. Deploy OPA service with policies mounted as ConfigMap

3. Use `kube-mgmt` to replicate Kubernetes data into OPA
K8S_ADMIT
    echo "  Kubernetes admission controller documentation created"
}

# Run all
setup_opa
echo ""
create_policies
echo ""
create_evaluation_script
echo ""
create_kubernetes_admission

# Schedule weekly policy evaluation
if ! crontab -l 2>/dev/null | grep -q "evaluate-policies"; then
    (crontab -l 2>/dev/null
     echo "# OPA policy evaluation - Weekly"
     echo "0 10 * * 1 ${SPECTRE_REPO}/security/opa/evaluate-policies.sh"
    ) | crontab -
    echo "Weekly policy evaluation scheduled"
fi

echo ""
echo "=== OPA Policy-as-Code Setup Complete ==="
echo ""
echo "Policy files: $OPA_DIR/policies/"
echo "  - docker-security.rego"
echo "  - backup-policy.rego"
echo "  - security-compliance.rego"
echo "  - network-security.rego"
echo ""
echo "Evaluate policies: $OPA_DIR/evaluate-policies.sh"
echo ""
echo "Example input JSON for OPA:"
echo '{"firewall_enabled": true, "ssh_password_auth": false}'
