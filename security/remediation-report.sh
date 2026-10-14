#!/bin/bash
# Auto Remediation Report Generator
# Generates specific fix commands for each drift issue

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$SCRIPT_DIR/logs"
LATEST_DRIFT_JSON="$LOG_DIR/drift-report-latest.json"
REPORT_FILE="$LOG_DIR/remediation-report-$(date +%Y%m%d_%H%M%S).md"

echo "=== Generating Remediation Report ==="

if [ ! -f "$LATEST_DRIFT_JSON" ]; then
    echo "No drift report found at $LATEST_DRIFT_JSON"
    exit 1
fi

DRIFT_DETECTED=$(cat "$LATEST_DRIFT_JSON" | jq -r '.drift_detected')
BASELINE_FILE=$(cat "$LATEST_DRIFT_JSON" | jq -r '.baseline_file')

cat > "$REPORT_FILE" << EOF
# Automated Remediation Report

**Generated:** $(date)
**Source:** $BASELINE_FILE
**Drift Detected:** $DRIFT_DETECTED

---

## Summary

| Category | Issues | Auto-Fixable | Manual Required |
|----------|--------|--------------|-----------------|
EOF

# Process each category
for CATEGORY in docker network compliance backup; do
    COUNT=$(cat "$LATEST_DRIFT_JSON" | jq -r ".categories.$CATEGORY // {} | length")
    if [ "$COUNT" -gt 0 ]; then
        echo "| $CATEGORY | $COUNT | TBD | TBD |" >> "$REPORT_FILE"
        
        echo "" >> "$REPORT_FILE"
        echo "### $CATEGORY" >> "$REPORT_FILE"
        echo "" >> "$REPORT_FILE"
        
        # Get all checks in this category
        KEYS=$(cat "$LATEST_DRIFT_JSON" | jq -r ".categories.$CATEGORY | keys[]")
        for CHECK in $KEYS; do
            DETAILS=$(cat "$LATEST_DRIFT_JSON" | jq -r ".categories.$CATEGORY.\"$CHECK\"")
            STATUS=$(echo "$DETAILS" | jq -r '.status')
            EXPECTED=$(echo "$DETAILS" | jq -r '.expected')
            ACTUAL=$(echo "$DETAILS" | jq -r '.actual')
            
            echo "#### $CHECK" >> "$REPORT_FILE"
            echo "" >> "$REPORT_FILE"
            echo "- **Status:** $STATUS" >> "$REPORT_FILE"
            echo "- **Expected:** $EXPECTED" >> "$REPORT_FILE"
            echo "- **Actual:** $ACTUAL" >> "$REPORT_FILE"
            echo "" >> "$REPORT_FILE"
            
            # Generate fix commands based on category and check
            case "$CATEGORY" in
                docker)
                    if [[ "$CHECK" == *"privileged"* ]]; then
                        echo "**Fix:** Recreate container without \`--privileged\` flag" >> "$REPORT_FILE"
                        echo '```bash' >> "$REPORT_FILE"
                        echo "docker run --rm -d --name <name> <image>  # Remove --privileged" >> "$REPORT_FILE"
                        echo '```' >> "$REPORT_FILE"
                    elif [[ "$CHECK" == *"memory_limit"* ]]; then
                        echo "**Fix:** Add memory limit when starting container" >> "$REPORT_FILE"
                        echo '```bash' >> "$REPORT_FILE"
                        echo "docker run --memory=2g <image>" >> "$REPORT_FILE"
                        echo '```' >> "$REPORT_FILE"
                    elif [[ "$CHECK" == *"healthcheck"* ]]; then
                        echo "**Fix:** Add healthcheck to container" >> "$REPORT_FILE"
                        echo '```bash' >> "$REPORT_FILE"
                        echo "docker run --health-cmd=\"curl -f http://localhost/health\" --health-interval=30s <image>" >> "$REPORT_FILE"
                        echo '```' >> "$REPORT_FILE"
                    elif [[ "$CHECK" == *"ports"* ]]; then
                        echo "**Fix:** Recreate container with localhost-only binding" >> "$REPORT_FILE"
                        echo '```bash' >> "$REPORT_FILE"
                        echo "docker run -p 127.0.0.1:8080:8080 <image>" >> "$REPORT_FILE"
                        echo '```' >> "$REPORT_FILE"
                    elif [[ "$CHECK" == *"mounts"* ]]; then
                        echo "**Fix:** Review and update volume mounts" >> "$REPORT_FILE"
                        echo '```bash' >> "$REPORT_FILE"
                        echo "docker run -v /correct/source:/destination <image>" >> "$REPORT_FILE"
                        echo '```' >> "$REPORT_FILE"
                    elif [[ "$CHECK" == *"existence"* ]]; then
                        echo "**Fix:** Ensure container is running" >> "$REPORT_FILE"
                        echo '```bash' >> "$REPORT_FILE"
                        echo "docker compose up -d <service>" >> "$REPORT_FILE"
                        echo '```' >> "$REPORT_FILE"
                    fi
                    ;;
                network)
                    if [[ "$CHECK" == *"unexpected_0.0.0.0"* ]]; then
                        PORT=$(echo "$CHECK" | sed 's/.*port_//')
                        echo "**Fix:** Recreate container binding to localhost only" >> "$REPORT_FILE"
                        echo '```bash' >> "$REPORT_FILE"
                        echo "docker run -p 127.0.0.1:$PORT:$PORT <image>" >> "$REPORT_FILE"
                        echo '```' >> "$REPORT_FILE"
                    elif [[ "$CHECK" == *"missing_binding"* ]]; then
                        PORT=$(echo "$CHECK" | sed 's/.*port_//')
                        echo "**Fix:** Ensure service is running and port is bound" >> "$REPORT_FILE"
                        echo '```bash' >> "$REPORT_FILE"
                        echo "docker compose up -d <service>" >> "$REPORT_FILE"
                        echo '```' >> "$REPORT_FILE"
                    fi
                    ;;
                compliance)
                    if [[ "$CHECK" == *"firewall"* ]]; then
                        echo "**Fix:** Enable firewall" >> "$REPORT_FILE"
                        echo '```bash' >> "$REPORT_FILE"
                        echo "# UFW" >> "$REPORT_FILE"
                        echo "sudo ufw enable" >> "$REPORT_FILE"
                        echo "# firewalld" >> "$REPORT_FILE"
                        echo "sudo systemctl enable --now firewalld" >> "$REPORT_FILE"
                        echo '```' >> "$REPORT_FILE"
                    elif [[ "$CHECK" == *"ssh_password_auth"* ]]; then
                        echo "**Fix:** Disable SSH password authentication" >> "$REPORT_FILE"
                        echo '```bash' >> "$REPORT_FILE"
                        echo "sudo sed -i 's/^#*PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config" >> "$REPORT_FILE"
                        echo "sudo systemctl reload sshd" >> "$REPORT_FILE"
                        echo '```' >> "$REPORT_FILE"
                    elif [[ "$CHECK" == *"audit_logging"* ]]; then
                        echo "**Fix:** Enable auditd" >> "$REPORT_FILE"
                        echo '```bash' >> "$REPORT_FILE"
                        echo "sudo apt install auditd" >> "$REPORT_FILE"
                        echo "sudo systemctl enable --now auditd" >> "$REPORT_FILE"
                        echo '```' >> "$REPORT_FILE"
                    elif [[ "$CHECK" == *"intrusion_detection"* ]]; then
                        echo "**Fix:** Install and enable Fail2Ban" >> "$REPORT_FILE"
                        echo '```bash' >> "$REPORT_FILE"
                        echo "sudo apt install fail2ban" >> "$REPORT_FILE"
                        echo "sudo systemctl enable --now fail2ban" >> "$REPORT_FILE"
                        echo '```' >> "$REPORT_FILE"
                    elif [[ "$CHECK" == *"file_integrity"* ]]; then
                        echo "**Fix:** Initialize AIDE database" >> "$REPORT_FILE"
                        echo '```bash' >> "$REPORT_FILE"
                        echo "sudo apt install aide" >> "$REPORT_FILE"
                        echo "sudo aideinit" >> "$REPORT_FILE"
                        echo "sudo cp /var/lib/aide/aide.db.new.gz /var/lib/aide/aide.db.gz" >> "$REPORT_FILE"
                        echo '```' >> "$REPORT_FILE"
                    fi
                    ;;
            esac
            
            echo "" >> "$REPORT_FILE"
        done
    fi
done

cat >> "$REPORT_FILE" << 'EOF'

---

## Quick Reference Commands

### Fix All 0.0.0.0 Bindings
```bash
# List containers with 0.0.0.0 bindings
docker ps --format '{{.Names}}|{{.Ports}}' | grep '0.0.0.0:'

# Recreate with localhost binding
docker run -p 127.0.0.1:PORT:PORT <image>
```

### Enable All Compliance Controls
```bash
# Firewall
sudo ufw enable

# SSH key-only auth
sudo sed -i 's/^#*PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo systemctl reload sshd

# Audit logging
sudo apt install auditd && sudo systemctl enable --now auditd

# Fail2Ban
sudo apt install fail2ban && sudo systemctl enable --now fail2ban

# AIDE
sudo apt install aide && sudo aideinit && sudo cp /var/lib/aide/aide.db.new.gz /var/lib/aide/aide.db.gz
```

### Add Healthchecks to Containers
```bash
# Example healthcheck
docker run \
  --health-cmd="curl -f http://localhost:8080/health || exit 1" \
  --health-interval=30s \
  --health-timeout=10s \
  --health-retries=3 \
  <image>
```

### Set Memory Limits
```bash
docker run --memory=2g --memory-swap=4g <image>
```

---

## Automation

To auto-apply fixes (where safe):

```bash
# Run remediation script
./security/remediate-drift.sh

# Re-check drift
./security/drift-detection.sh
```

---

*Report generated by remediation-report.sh*
EOF

echo "✅ Remediation report generated: $REPORT_FILE"
echo ""
echo "=== Report Summary ==="
cat "$REPORT_FILE" | head -50