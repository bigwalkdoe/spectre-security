#!/bin/bash
# Replicate backups to S3-compatible storage
set -euo pipefail

S3_BUCKET="modelink-S3"
BACKUP_DIR="/backups"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_DIR="$SCRIPT_DIR/../logs"
LOG_FILE="$LOG_DIR/backup-s3-replication.log"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p "$LOG_DIR"

# Load secrets
if [ -f "[REDACTED_PATH]/.secrets/environment" ]; then
    source "[REDACTED_PATH]/.secrets/environment"
fi
if [ -f "[REDACTED_PATH]/.secrets/backup-config.env" ]; then
    source "[REDACTED_PATH]/.secrets/backup-config.env"
fi

{
    echo "=========================================="
    echo "S3 Backup Replication - $DATE"
    echo "=========================================="

    if command -v aws >/dev/null 2>&1 && [ -n "${AWS_ACCESS_KEY_ID:-}" ]; then
        aws s3 sync "$BACKUP_DIR/" "s3://$S3_BUCKET/$(hostname)/" \
            --storage-class STANDARD_IA \
            --no-follow-symlinks \
            --exclude "*.tmp" \
            --sse aws:kms

        S3_EXIT=$?
        if [ $S3_EXIT -eq 0 ]; then
            echo "S3 replication completed successfully"
            logger -p user.info "S3 backup replication completed"
        else
            echo "S3 replication FAILED (exit: $S3_EXIT)"
            logger -p user.error "S3 backup replication failed"
        fi
    else
        echo "AWS CLI not available or AWS credentials not configured"
        echo "Set AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY in backup-config.env"
    fi

    echo "S3 replication completed: $DATE"
} >> "$LOG_FILE" 2>&1
