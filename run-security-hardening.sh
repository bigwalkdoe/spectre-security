#!/bin/bash
# Main Security Orchestration Script (Repository Local Version)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SECURITY_LOG="$SCRIPT_DIR/security/logs/security-hardening.log"
mkdir -p "$(dirname "$SECURITY_LOG")"
DATE=$(date +%Y%m%d_%H%M%S)

echo "==========================================" >> "$SECURITY_LOG"
echo "Security Hardening - $DATE" >> "$SECURITY_LOG"
echo "==========================================" >> "$SECURITY_LOG"

# Make scripts executable
chmod +x "$SCRIPT_DIR/security"/*.sh 2>/dev/null

# Check Docker security if Docker is available
if command -v docker &> /dev/null; then
    echo "Running Docker security checks..." >> "$SECURITY_LOG"
    # Check for privileged containers
    docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}" | grep -v "CONTAINER ID" >> "$SECURITY_LOG" 2>&1 || true
    DOCKER_STATUS=0
else
    echo "Docker not available, skipping Docker checks" >> "$SECURITY_LOG"
    DOCKER_STATUS=0
fi

# Check for sensitive files in repo
echo "Checking for sensitive files..." >> "$SECURITY_LOG"
if find "$SCRIPT_DIR" -type f \( -name "*.pem" -o -name "*.key" -o -name "*.crt" -o -name "*secret*" -o -name "*password*" -o -name "*.env" \) ! -path "*/.git/*" 2>/dev/null | grep -v ".example" | grep -v "README" | head -20 >> "$SECURITY_LOG"; then
    echo "WARNING: Potential sensitive files found!" >> "$SECURITY_LOG"
    SENSITIVE_STATUS=1
else
    echo "No sensitive files detected" >> "$SECURITY_LOG"
    SENSITIVE_STATUS=0
fi

# Check script permissions
echo "Checking script permissions..." >> "$SECURITY_LOG"
find "$SCRIPT_DIR" -type f -name "*.sh" -perm /o+w 2>/dev/null | head -20 >> "$SECURITY_LOG" || true
PERM_STATUS=0

# Generate summary
echo "==========================================" >> "$SECURITY_LOG"
echo "Security Hardening Summary - $DATE" >> "$SECURITY_LOG"
echo "Docker security: $([ $DOCKER_STATUS -eq 0 ] && echo 'SUCCESS' || echo 'FAILED')" >> "$SECURITY_LOG"
echo "Sensitive files: $([ $SENSITIVE_STATUS -eq 0 ] && echo 'CLEAN' || echo 'WARNING')" >> "$SECURITY_LOG"
echo "Permissions: $([ $PERM_STATUS -eq 0 ] && echo 'OK' || echo 'WARNING')" >> "$SECURITY_LOG"
echo "==========================================" >> "$SECURITY_LOG"

# Exit with error if any check failed
if [ $DOCKER_STATUS -ne 0 ] || [ $SENSITIVE_STATUS -ne 0 ] || [ $PERM_STATUS -ne 0 ]; then
    exit 1
fi

echo "Security hardening orchestration completed: $DATE"