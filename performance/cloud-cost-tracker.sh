#!/bin/bash
# Track cloud resource costs
set -euo pipefail
# Resolve the invoking user's home and this repository's root. Under sudo,
# $HOME is /root, so fall back to $SUDO_USER before trusting it. Both may be
# overridden: SPECTRE_HOME=/srv/secure SPECTRE_REPO=/opt/spectre-security
_spectre_here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SPECTRE_HOME="${SPECTRE_HOME:-$(getent passwd "${SUDO_USER:-$USER}" 2>/dev/null | cut -d: -f6)}"
SPECTRE_HOME="${SPECTRE_HOME:-$HOME}"
SPECTRE_REPO="${SPECTRE_REPO:-$(git -C "$_spectre_here" rev-parse --show-toplevel 2>/dev/null || echo "$_spectre_here")}"

REPORT_DIR="${SPECTRE_REPO}/performance/reports"
mkdir -p "$REPORT_DIR"
DATE=$(date +%Y%m%d)

echo "=== Cloud Cost Report - $DATE ===" > "$REPORT_DIR/cost-report-$DATE.md"

# AWS Cost (if AWS CLI configured)
if command -v aws >/dev/null 2>&1; then
    echo "## AWS Costs" >> "$REPORT_DIR/cost-report-$DATE.md"
    aws ce get-cost-and-usage \
        --time-period Start=$(date -d "-30 days" +%Y-%m-%d),End=$(date +%Y-%m-%d) \
        --granularity MONTHLY \
        --metrics BlendedCost \
        --output text 2>/dev/null >> "$REPORT_DIR/cost-report-$DATE.md" || \
        echo "AWS cost data not available (configure aws CLI)" >> "$REPORT_DIR/cost-report-$DATE.md"
fi

# Docker resource costs (estimated)
echo "" >> "$REPORT_DIR/cost-report-$DATE.md"
echo "## Docker Resource Usage" >> "$REPORT_DIR/cost-report-$DATE.md"
docker stats --no-stream 2>/dev/null >> "$REPORT_DIR/cost-report-$DATE.md" || true

# Disk usage by service
echo "" >> "$REPORT_DIR/cost-report-$DATE.md"
echo "## Disk Usage by Directory" >> "$REPORT_DIR/cost-report-$DATE.md"
du -sh ${SPECTRE_REPO} ${SPECTRE_HOME}/projects/ /backups/ /var/log/ 2>/dev/null >> "$REPORT_DIR/cost-report-$DATE.md"

echo "Cost report: $REPORT_DIR/cost-report-$DATE.md"
