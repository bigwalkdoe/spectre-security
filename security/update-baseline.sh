#!/bin/bash
# Update Baseline Script
# Updates current-infrastructure.json to match live Docker state

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASELINE_FILE="${SPECTRE_BASELINE:-$SCRIPT_DIR/test-data/current-infrastructure.json}"
BACKUP_FILE="$SCRIPT_DIR/test-data/current-infrastructure.json.backup.$(date +%Y%m%d_%H%M%S)"

echo "=== Updating Infrastructure Baseline ==="
echo "Baseline: $BASELINE_FILE"
echo "Backup: $BACKUP_FILE"
echo ""

# Backup original
cp "$BASELINE_FILE" "$BACKUP_FILE"
echo "✅ Backed up original baseline"

# Get live Docker container data
if ! command -v docker &> /dev/null; then
    echo "❌ Docker not available"
    exit 1
fi

echo "🔍 Collecting live container data..."

# Build docker array using jq for proper JSON
DOCKER_JSON=$(docker ps --format '{{.Names}}' | while read -r CONTAINER; do
    INSPECT=$(docker inspect "$CONTAINER" 2>/dev/null | jq '.[0]')
    
    NAME=$(echo "$INSPECT" | jq -r '.Name | ltrimstr("/")')
    IMAGE=$(echo "$INSPECT" | jq -r '.Config.Image')
    PRIVILEGED=$(echo "$INSPECT" | jq -r '.HostConfig.Privileged')
    MEMORY=$(echo "$INSPECT" | jq -r '.HostConfig.Memory')
    
    # Healthcheck
    HEALTH_TEST=$(echo "$INSPECT" | jq -r '.Config.Healthcheck.Test // [] | join(" ")' 2>/dev/null)
    if [ "$HEALTH_TEST" = "" ] || [ "$HEALTH_TEST" = "null" ]; then
        HEALTHCHECK=""
    else
        HEALTHCHECK="$HEALTH_TEST"
    fi
    
    # Ports
    PORTS=$(echo "$INSPECT" | jq -c '[.HostConfig.PortBindings // {} | to_entries[] | {host_ip: (.value[0].HostIp // "0.0.0.0"), host_port: (.value[0].HostPort | tonumber), container_port: (.key | split("/")[0] | tonumber)}]')
    
    # Mounts
    MOUNTS=$(echo "$INSPECT" | jq -c '[.Mounts[] | {source: .Source, destination: .Destination, type: .Type}]')
    
    # Output JSON for this container
    jq -n \
      --arg name "$NAME" \
      --arg image "$IMAGE" \
      --argjson privileged "$PRIVILEGED" \
      --argjson memory "$MEMORY" \
      --arg healthcheck "$HEALTHCHECK" \
      --argjson ports "$PORTS" \
      --argjson mounts "$MOUNTS" \
      '{name: $name, image: $image, privileged: $privileged, memory_limit: $memory, healthcheck: $healthcheck, ports: $ports, mounts: $mounts}'
done | jq -s .)

CONTAINER_COUNT=$(echo "$DOCKER_JSON" | jq 'length')
echo "📦 Found $CONTAINER_COUNT containers"

# Get network ports (Docker host port bindings)
NETWORK_PORTS=$(docker ps --format '{{.Ports}}' 2>/dev/null | grep -oE '127\.0\.0\.1:[0-9]+|0\.0\.0\.0:[0-9]+|\[::\]:[0-9]+' | sed 's/.*://' | sort -nu)

if [ -z "$NETWORK_PORTS" ]; then
    NETWORK_PORTS_JSON="[]"
else
    NETWORK_PORTS_JSON=$(echo "$NETWORK_PORTS" | jq -R . | jq -s .)
fi

echo "🔌 Found $(echo "$NETWORK_PORTS_JSON" | jq 'length') network ports"

# Update baseline file using jq
echo "📝 Updating baseline..."

jq --argjson docker "$DOCKER_JSON" \
   --argjson ports "$NETWORK_PORTS_JSON" \
   '.docker = $docker | .network.open_ports = $ports | .updated = now | .updated_iso = (now | strftime("%Y-%m-%dT%H:%M:%SZ"))' \
   "$BASELINE_FILE" > "$BASELINE_FILE.tmp" && mv "$BASELINE_FILE.tmp" "$BASELINE_FILE"

echo "✅ Baseline updated successfully"
echo ""
echo "Summary:"
echo "  Containers: $CONTAINER_COUNT"
echo "  Network ports: $(echo "$NETWORK_PORTS_JSON" | jq 'length')"
echo "  Backup: $BACKUP_FILE"
echo ""
echo "Run drift detection to verify: ./security/drift-detection.sh"