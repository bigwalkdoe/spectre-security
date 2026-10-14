#!/bin/bash
# Security Alerting Module
# Sends notifications via webhook, email, Slack, etc.

set -euo pipefail

# Configuration (can be overridden by env vars)
WEBHOOK_URL="${SECURITY_WEBHOOK_URL:-}"
SLACK_WEBHOOK="${SECURITY_SLACK_WEBHOOK:-}"
EMAIL_TO="${SECURITY_EMAIL_TO:-}"
EMAIL_FROM="${SECURITY_EMAIL_FROM:-security@localhost}"
SMTP_SERVER="${SECURITY_SMTP_SERVER:-localhost}"
SMTP_PORT="${SECURITY_SMTP_PORT:-25}"

ALERT_LEVEL="${1:-warning}"
MESSAGE="${2:-Security alert}"
DETAILS="${3:-}"
TIMESTAMP=$(date -Iseconds)
HOSTNAME=$(hostname)

# Send webhook notification
send_webhook() {
    local url="$1"
    local payload="$2"
    
    if [ -n "$url" ]; then
        curl -s -X POST "$url" \
            -H "Content-Type: application/json" \
            -d "$payload" \
            --max-time 10 \
            >/dev/null 2>&1 && return 0 || return 1
    fi
    return 1
}

# Send Slack notification
send_slack() {
    local webhook="$1"
    local text="$2"
    local color="$3"
    
    if [ -n "$webhook" ]; then
        local payload=$(jq -n \
            --arg text "$text" \
            --arg color "$color" \
            --arg timestamp "$TIMESTAMP" \
            --arg hostname "$HOSTNAME" \
            '{
                attachments: [{
                    color: $color,
                    title: "Security Alert: \($hostname)",
                    text: $text,
                    footer: "Security Baseline",
                    ts: ($timestamp | fromdateiso8601)
                }]
            }')
        
        send_webhook "$webhook" "$payload"
        return $?
    fi
    return 1
}

# Send email notification
send_email() {
    local to="$1"
    local subject="$2"
    local body="$3"
    
    if [ -n "$to" ] && command -v sendmail &> /dev/null; then
        {
            echo "To: $to"
            echo "From: $EMAIL_FROM"
            echo "Subject: $subject"
            echo "Content-Type: text/plain"
            echo ""
            echo "$body"
        } | sendmail -t 2>/dev/null && return 0 || return 1
    fi
    return 1
}

# Main alert function
alert() {
    local level="$1"
    local message="$2"
    local details="$3"
    
    local color="warning"
    case "$level" in
        critical) color="danger" ;;
        warning)  color="warning" ;;
        info)     color="good" ;;
    esac
    
    local full_message="*Level:* $level
*Message:* $message
*Host:* $HOSTNAME
*Time:* $TIMESTAMP"
    
    if [ -n "$details" ]; then
        full_message="$full_message
*Details:*
\`\`\`
$details
\`\`\`"
    fi
    
    # Send via all configured channels
    local sent=false
    
    if send_slack "$SLACK_WEBHOOK" "$full_message" "$color"; then
        echo "✅ Slack notification sent"
        sent=true
    fi
    
    if [ -n "$WEBHOOK_URL" ]; then
        local payload=$(jq -n \
            --arg level "$level" \
            --arg message "$message" \
            --arg details "$details" \
            --arg timestamp "$TIMESTAMP" \
            --arg hostname "$HOSTNAME" \
            '{level: $level, message: $message, details: $details, timestamp: $timestamp, hostname: $hostname}')
        
        if send_webhook "$WEBHOOK_URL" "$payload"; then
            echo "✅ Webhook notification sent"
            sent=true
        fi
    fi
    
    if [ -n "$EMAIL_TO" ]; then
        if send_email "$EMAIL_TO" "[SECURITY $level] $message" "$full_message"; then
            echo "✅ Email notification sent"
            sent=true
        fi
    fi
    
    if [ "$sent" = false ]; then
        echo "⚠️  No notification channels configured (set SECURITY_WEBHOOK_URL, SECURITY_SLACK_WEBHOOK, SECURITY_EMAIL_TO)"
        return 1
    fi
    
    return 0
}

# If called directly, send alert
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    alert "$@"
fi