#!/bin/bash
# Secrets Management - HashiCorp Vault / Env-based secret injection
set -euo pipefail
# Resolve the invoking user's home and this repository's root. Under sudo,
# $HOME is /root, so fall back to $SUDO_USER before trusting it. Both may be
# overridden: SPECTRE_HOME=/srv/secure SPECTRE_REPO=/opt/spectre-security
_spectre_here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SPECTRE_HOME="${SPECTRE_HOME:-$(getent passwd "${SUDO_USER:-$USER}" 2>/dev/null | cut -d: -f6)}"
SPECTRE_HOME="${SPECTRE_HOME:-$HOME}"
SPECTRE_REPO="${SPECTRE_REPO:-$(git -C "$_spectre_here" rev-parse --show-toplevel 2>/dev/null || echo "$_spectre_here")}"

echo "=== Secrets Management Setup ==="

VAULT_MODE="${1:-env}"  # 'env' or 'vault'
SECRETS_DIR="${SPECTRE_HOME}/.secrets"
ENV_FILE="${SPECTRE_HOME}/.secrets/environment"

mkdir -p "$SECRETS_DIR"
chmod 700 "$SECRETS_DIR"

setup_env_secrets() {
    echo "Setting up environment-based secret injection..."
    
    # Create env file template with secure permissions
    if [ ! -f "$ENV_FILE" ]; then
        cat > "$ENV_FILE" << 'ENV_TEMPLATE'
# Environment-specific secrets
# Source this file before running services: source ${SPECTRE_HOME}/.secrets/environment
# IMPORTANT: Replace placeholder values with real secrets

# Database
export DB_PASSWORD="changeme"
export DB_USER="postgres"
export DB_NAME="guardrail"
export DB_HOST="localhost"
export DB_PORT="5432"

# Redis
export REDIS_PASSWORD="changeme"
export REDIS_HOST="localhost"
export REDIS_PORT="6379"

# API Keys
export API_KEY="changeme"
export JWT_SECRET="changeme"

# External Services
export SLACK_WEBHOOK_URL="https://hooks.slack.com/services/YOUR/WEBHOOK"
export PAGERDUTY_ROUTING_KEY="changeme"
export SMTP_USERNAME="changeme"
export SMTP_PASSWORD="changeme"
export ALERT_EMAIL_TO="admin@example.com"

# Cloud (AWS/Azure/GCP)
export AWS_ACCESS_KEY_ID=""
export AWS_SECRET_ACCESS_KEY=""
export AWS_REGION="us-east-1"
export AZURE_TENANT_ID=""
export AZURE_CLIENT_ID=""
export AZURE_CLIENT_SECRET=""

# Backup
export BACKUP_ENCRYPTION_KEY="changeme"
export REMOTE_LOKI_URL=""
export REMOTE_S3_BUCKET=""

# Monitoring
export GF_SECURITY_ADMIN_PASSWORD="changeme"
ENV_TEMPLATE
        chmod 600 "$ENV_FILE"
        echo "Created secret template at $ENV_FILE"
    fi

    # Create a secure injection script
    cat > ${SPECTRE_REPO}/security/inject-secrets.sh << 'INJECT_SCRIPT'
#!/bin/bash
# Inject secrets into environment and configuration files
set -euo pipefail

SECRETS_FILE="${SPECTRE_HOME}/.secrets/environment"
if [ -f "$SECRETS_FILE" ]; then
    source "$SECRETS_FILE"
    echo "Secrets loaded from $SECRETS_FILE"
else
    echo "WARNING: Secrets file not found at $SECRETS_FILE"
    return 1
fi

# Inject into .env files
inject_env_file() {
    local target="$1"
    if [ -f "$target" ]; then
        cp "$target" "${target}.bak"
        envsubst < "$target" > "${target}.tmp"
        mv "${target}.tmp" "$target"
        echo "Secrets injected into $target (backup at ${target}.bak)"
    fi
}

# Inject secrets into project .env files
for project in example-project Modelink; do
    inject_env_file "${SPECTRE_HOME}/projects/$project/.env" 2>/dev/null || true
done

# Update docker-compose files with secrets
for compose_file in ${SPECTRE_HOME}/projects/example-project/dk-compose.yml ${SPECTRE_HOME}/dev/github/system-maintenance/docker-compose.monitoring.yml; do
    if [ -f "$compose_file" ]; then
        echo "Processing $compose_file for secrets injection..."
    fi
done

echo "Secret injection completed"
INJECT_SCRIPT
    chmod +x ${SPECTRE_REPO}/security/inject-secrets.sh
    echo "Created secret injection script"
}

setup_vault() {
    echo "Setting up HashiCorp Vault..."
    
    if ! command -v vault >/dev/null 2>&1; then
        echo "Installing Vault..."
        wget -qO- https://releases.hashicorp.com/vault/1.16.0/vault_1.16.0_linux_amd64.zip | gunzip > /tmp/vault
        sudo mv /tmp/vault /usr/local/bin/vault
        sudo chmod +x /usr/local/bin/vault
    fi

    # Create Vault configuration
    sudo mkdir -p /etc/vault
    
    cat > /tmp/vault-config.hcl << 'VAULT_CFG'
storage "file" {
  path = "/var/lib/vault/data"
}

listener "tcp" {
  address     = "127.0.0.1:8200"
  tls_disable = true
}

ui = true
api_addr = "http://127.0.0.1:8200"
VAULT_CFG

    sudo mv /tmp/vault-config.hcl /etc/vault/config.hcl
    
    # Create Vault systemd service
    sudo bash -c 'cat > /etc/systemd/system/vault.service << "SYSTEMD"
[Unit]
Description=HashiCorp Vault
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/vault server -config=/etc/vault/config.hcl
Restart=always
RestartSec=10
User=deon
Group=deon

[Install]
WantedBy=multi-user.target
SYSTEMD'
    
    # Create Vault secrets script
    cat > ${SPECTRE_REPO}/security/vault-secrets.sh << 'VAULT_SCRIPT'
#!/bin/bash
# Vault-based secret management
set -euo pipefail

VAULT_ADDR="${VAULT_ADDR:-http://127.0.0.1:8200}"
VAULT_TOKEN="${VAULT_TOKEN:-}"

export VAULT_ADDR

vault_login() {
    if [ -z "$VAULT_TOKEN" ]; then
        echo "Please set VAULT_TOKEN or login manually: vault login"
        exit 1
    fi
    vault login "$VAULT_TOKEN" >/dev/null 2>&1
}

store_secret() {
    local path="$1"
    local key="$2"
    local value="$3"
    vault kv put "secret/$path" "$key=$value"
}

get_secret() {
    local path="$1"
    local key="$2"
    vault kv get -field="$key" "secret/$path"
}

case "${1:-}" in
    store)
        store_secret "${2}" "${3}" "${4}"
        ;;
    get)
        get_secret "${2}" "${3}"
        ;;
    *)
        echo "Usage: $0 {store|get} <path> <key> [value]"
        echo ""
        echo "Examples:"
        echo "  $0 store database/postgres password my-secure-password"
        echo "  $0 get database/postgres password"
        ;;
esac
VAULT_SCRIPT
    chmod +x ${SPECTRE_REPO}/security/vault-secrets.sh
    echo "Vault configured. Start with: sudo systemctl start vault"
}

# Also create .gitignore for secrets
cat > ${SPECTRE_HOME}/.secrets/.gitignore << 'GI'
*
!.gitignore
GI

case "$VAULT_MODE" in
    vault)
        setup_vault
        ;;
    env)
        setup_env_secrets
        ;;
    both)
        setup_env_secrets
        setup_vault
        ;;
esac

echo ""
echo "=== Secrets Management Setup Complete ==="
echo ""
echo "Files created:"
echo "  - ${SPECTRE_HOME}/.secrets/environment (env-based secrets, chmod 600)"
echo "  - ${SPECTRE_REPO}/security/inject-secrets.sh (env injection)"
if [ "$VAULT_MODE" = "vault" ] || [ "$VAULT_MODE" = "both" ]; then
    echo "  - /etc/vault/config.hcl (Vault config)"
    echo "  - ${SPECTRE_REPO}/security/vault-secrets.sh (Vault CLI)"
fi
echo ""
echo "Next steps:"
echo "  1. Edit ${SPECTRE_HOME}/.secrets/environment with real secrets"
echo "  2. Source secrets: source ${SPECTRE_HOME}/.secrets/environment"
echo "  3. Run inject-secrets.sh to apply to project files"
