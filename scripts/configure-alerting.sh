#!/bin/bash
# Helper script to configure GitHub Actions secrets for alerting

set -euo pipefail

echo "=== GitHub Actions Alerting Configuration ==="
echo ""
echo "Add these secrets to GitHub Settings → Secrets → Actions:"
echo ""

read -p "Slack Webhook URL (optional): " SLACK_WEBHOOK
read -p "Generic Webhook URL (optional): " WEBHOOK_URL
read -p "Email for alerts (optional): " EMAIL_TO

echo ""
echo "=== Commands to run ==="
echo ""

if [ -n "$SLACK_WEBHOOK" ]; then
    echo "gh secret set SECURITY_SLACK_WEBHOOK --body \"$SLACK_WEBHOOK\""
fi

if [ -n "$WEBHOOK_URL" ]; then
    echo "gh secret set SECURITY_WEBHOOK_URL --body \"$WEBHOOK_URL\""
fi

if [ -n "$EMAIL_TO" ]; then
    echo "gh secret set SECURITY_EMAIL_TO --body \"$EMAIL_TO\""
    echo "gh secret set SECURITY_EMAIL_FROM --body \"security@$(hostname -d 2>/dev/null || echo localhost)\""
    echo "gh secret set SECURITY_SMTP_SERVER --body \"localhost\""
    echo "gh secret set SECURITY_SMTP_PORT --body \"25\""
fi

echo ""
echo "Or add manually at: https://github.com/bigwalkdoe/scripts/settings/secrets/actions"
