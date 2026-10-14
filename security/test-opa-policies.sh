#!/bin/bash
# OPA Policy Test Suite
# Tests all OPA policies against current infrastructure data

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
POLICY_DIR="$SCRIPT_DIR/../security/opa/policies"
TEST_DATA="$SCRIPT_DIR/test-data/current-infrastructure.json"
OPA_CMD="${OPA_CMD:-/tmp/opa}"

if [ ! -x "$OPA_CMD" ]; then
    OPA_CMD="opa"
fi

echo "=== OPA Policy Test Suite ==="
echo "Policy directory: $POLICY_DIR"
echo "Test data: $TEST_DATA"
echo "OPA command: $OPA_CMD"
echo ""

# Test 1: Backup Policy
echo "--- Test 1: Backup Policy ---"
if cat "$TEST_DATA" | jq '.backup' | $OPA_CMD eval -i /dev/stdin -d "$POLICY_DIR/backup-policy.rego" "data.backup.policy.deny" | jq -e '.result[0].expressions[0].value | length == 0' > /dev/null; then
    echo "✅ Backup Policy: PASSED"
else
    echo "❌ Backup Policy: FAILED"
    cat "$TEST_DATA" | jq '.backup' | $OPA_CMD eval -i /dev/stdin -d "$POLICY_DIR/backup-policy.rego" "data.backup.policy.deny" | jq '.result[0].expressions[0].value'
    exit 1
fi

# Test 2: Docker Security Policy (test each container)
echo "--- Test 2: Docker Security Policy ---"
DOCKER_PASSED=true
CONTAINERS=$(cat "$TEST_DATA" | jq -c '.docker[]')
while IFS= read -r container; do
    NAME=$(echo "$container" | jq -r '.name')
    if echo "$container" | $OPA_CMD eval -i /dev/stdin -d "$POLICY_DIR/docker-security.rego" "data.docker.security.deny" 2>/dev/null | jq -e '.result[0].expressions[0].value | length == 0' > /dev/null; then
        echo "  ✅ $NAME"
    else
        echo "  ❌ $NAME"
        echo "$container" | $OPA_CMD eval -i /dev/stdin -d "$POLICY_DIR/docker-security.rego" "data.docker.security.deny" 2>/dev/null | jq '.result[0].expressions[0].value'
        DOCKER_PASSED=false
    fi
done <<< "$CONTAINERS"
if [ "$DOCKER_PASSED" = true ]; then
    echo "✅ Docker Security Policy: ALL PASSED"
else
    echo "❌ Docker Security Policy: SOME FAILED"
    exit 1
fi

# Test 3: Network Security Policy
echo "--- Test 3: Network Security Policy ---"
if cat "$TEST_DATA" | jq '.network' | $OPA_CMD eval -i /dev/stdin -d "$POLICY_DIR/network-security.rego" "data.network.security.deny" | jq -e '.result[0].expressions[0].value | length == 0' > /dev/null; then
    echo "✅ Network Security Policy: PASSED"
else
    echo "❌ Network Security Policy: FAILED"
    cat "$TEST_DATA" | jq '.network' | $OPA_CMD eval -i /dev/stdin -d "$POLICY_DIR/network-security.rego" "data.network.security.deny" | jq '.result[0].expressions[0].value'
    exit 1
fi

# Test 4: Security Compliance Policy
echo "--- Test 4: Security Compliance Policy ---"
if cat "$TEST_DATA" | jq '.compliance' | $OPA_CMD eval -i /dev/stdin -d "$POLICY_DIR/security-compliance.rego" "data.security.compliance.deny" | jq -e '.result[0].expressions[0].value | length == 0' > /dev/null; then
    echo "✅ Security Compliance Policy: PASSED"
else
    echo "❌ Security Compliance Policy: FAILED"
    cat "$TEST_DATA" | jq '.compliance' | $OPA_CMD eval -i /dev/stdin -d "$POLICY_DIR/security-compliance.rego" "data.security.compliance.deny" | jq '.result[0].expressions[0].value'
    exit 1
fi

echo ""
echo "=== ALL TESTS PASSED ==="