#!/bin/bash
# Inject secrets into environment and configuration files
set -euo pipefail
# Resolve the invoking user's home and this repository's root. Under sudo,
# $HOME is /root, so fall back to $SUDO_USER before trusting it. Both may be
# overridden: SPECTRE_HOME=/srv/secure SPECTRE_REPO=/opt/spectre-security
_spectre_here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SPECTRE_HOME="${SPECTRE_HOME:-$(getent passwd "${SUDO_USER:-$USER}" 2>/dev/null | cut -d: -f6)}"
SPECTRE_HOME="${SPECTRE_HOME:-$HOME}"
SPECTRE_REPO="${SPECTRE_REPO:-$(git -C "$_spectre_here" rev-parse --show-toplevel 2>/dev/null || echo "$_spectre_here")}"

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
