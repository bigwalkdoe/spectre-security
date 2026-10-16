#!/bin/bash
set -euo pipefail
# Resolve the invoking user's home and this repository's root. Under sudo,
# $HOME is /root, so fall back to $SUDO_USER before trusting it. Both may be
# overridden: SPECTRE_HOME=/srv/secure SPECTRE_REPO=/opt/spectre-security
_spectre_here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SPECTRE_HOME="${SPECTRE_HOME:-$(getent passwd "${SUDO_USER:-$USER}" 2>/dev/null | cut -d: -f6)}"
SPECTRE_HOME="${SPECTRE_HOME:-$HOME}"
SPECTRE_REPO="${SPECTRE_REPO:-$(git -C "$_spectre_here" rev-parse --show-toplevel 2>/dev/null || echo "$_spectre_here")}"

echo "=== Setting up Centralized Logging with Loki Stack ==="
echo ""

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "Error: Docker is not running. Please start Docker first."
    exit 1
fi

# Create logs directory if it doesn't exist
mkdir -p ${SPECTRE_REPO}/logs

# Navigate to logging directory
cd ${SPECTRE_REPO}/logging

echo "Starting Loki stack containers..."
docker-compose -f docker-compose.loki.yml up -d

echo ""
echo "Waiting for services to be ready..."
sleep 10

echo ""
echo "=== Loki Stack Setup Complete ==="
echo ""
echo "Services available:"
echo "  - Loki: http://localhost:3100"
echo "  - Grafana: http://localhost:3003 (admin/changeme)"
echo "  - Promtail: running as container"
echo ""
echo "IMPORTANT: Change the default Grafana password!"
echo "Run: docker exec -it grafana-logging grafana-cli admin reset-admin-password"
echo ""
echo "Next steps:"
echo "1. Access Grafana at http://localhost:3003"
echo "2. Login with admin/changeme"
echo "3. Change the password immediately"
echo "4. Explore logs in the Loki datasource"
echo ""