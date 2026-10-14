#!/bin/bash
# Inject secrets into environment and configuration files
set -euo pipefail

SECRETS_FILE="[REDACTED_PATH]/.secrets/environment"
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
    inject_env_file "[REDACTED_PATH]/projects/$project/.env" 2>/dev/null || true
done

# Update docker-compose files with secrets
for compose_file in [REDACTED_PATH]/projects/example-project/dk-compose.yml [REDACTED_PATH]/dev/github/system-maintenance/docker-compose.monitoring.yml; do
    if [ -f "$compose_file" ]; then
        echo "Processing $compose_file for secrets injection..."
    fi
done

echo "Secret injection completed"
