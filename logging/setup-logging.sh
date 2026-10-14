#!/bin/bash
set -euo pipefail

echo "=== Setting up Centralized Logging with Loki Stack ==="
echo ""

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "Error: Docker is not running. Please start Docker first."
    exit 1
fi

# Create logs directory if it doesn't exist
mkdir -p [REDACTED_PATH]/scripts/logs

# Navigate to logging directory
cd [REDACTED_PATH]/scripts/logging

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