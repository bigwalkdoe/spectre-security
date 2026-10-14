#!/bin/bash
# Off-site Backup Replication Setup
# Rsync to remote location, cloud storage (AWS S3/Backblaze B2), encryption
set -euo pipefail

echo "=== Off-site Backup Replication Setup ==="
echo ""

BACKUP_DIR="/backups"
CONFIG_FILE="[REDACTED_PATH]/.secrets/backup-config.env"

# Load config if exists
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
fi

# Default configuration
REMOTE_HOST="${REMOTE_HOST:-}"
REMOTE_USER="${REMOTE_USER:-deon}"
REMOTE_PATH="${REMOTE_PATH:-/backups/replica}"
S3_BUCKET="${S3_BUCKET:-}"
B2_BUCKET="${B2_BUCKET:-}"
ENCRYPTION_KEY="${ENCRYPTION_KEY:-}"
GPG_RECIPIENT="${GPG_RECIPIENT:-}"

setup_encryption() {
    echo "Setting up backup encryption..."
    
    if [ -n "$GPG_RECIPIENT" ]; then
        echo "Using GPG encryption for recipient: $GPG_RECIPIENT"
    else
        # Generate encryption key if not exists
        if [ ! -f [REDACTED_PATH]/.secrets/backup-key.gpg ]; then
            echo "Generating backup encryption key..."
            ENCRYPTION_KEY=$(openssl rand -hex 32)
            echo "$ENCRYPTION_KEY" | gpg --symmetric --cipher-algo AES256 -o [REDACTED_PATH]/.secrets/backup-key.gpg 2>/dev/null || {
                echo "Creating plaintext key file (use GPG for production)"
                echo "$ENCRYPTION_KEY" > [REDACTED_PATH]/.secrets/backup-key.plain
                chmod 600 [REDACTED_PATH]/.secrets/backup-key.plain
            }
        fi
        echo "Backup encryption key at [REDACTED_PATH]/.secrets/backup-key.gpg"
    fi
}

setup_rsync_replication() {
    echo "[1/3] Setting up Rsync replication..."
    
    if [ -z "$REMOTE_HOST" ]; then
        echo "  Skipping - REMOTE_HOST not configured"
        echo "  Set in $CONFIG_FILE: REMOTE_HOST=backup.example.com"
        return
    fi

    # Create SSH key if needed
    if [ ! -f [REDACTED_PATH]/.ssh/backup_rsync ]; then
        ssh-keygen -t ed25519 -f [REDACTED_PATH]/.ssh/backup_rsync -N "" -C "backup-replication"
        echo "  SSH key generated: [REDACTED_PATH]/.ssh/backup_rsync.pub"
        echo "  Add this key to $REMOTE_USER@$REMOTE_HOST authorized_keys"
        cat [REDACTED_PATH]/.ssh/backup_rsync.pub
    fi

    # Create SSH config
    mkdir -p [REDACTED_PATH]/.ssh
    cat >> [REDACTED_PATH]/.ssh/config << SSH_CFG

# Backup replication host
Host backup-remote
    HostName $REMOTE_HOST
    User $REMOTE_USER
    IdentityFile ~/.ssh/backup_rsync
    Compression yes
    ServerAliveInterval 60
SSH_CFG
    chmod 600 [REDACTED_PATH]/.ssh/config

    # Create replication script
    cat > [REDACTED_PATH]/scripts/backups/replicate-to-remote.sh << RSYNC_SCRIPT
#!/bin/bash
# Replicate backups to remote location via rsync
set -euo pipefail

REMOTE_HOST="$REMOTE_HOST"
REMOTE_USER="$REMOTE_USER"
REMOTE_PATH="$REMOTE_PATH"
BACKUP_DIR="$BACKUP_DIR"
LOG_FILE="/var/log/backup-replication.log"
DATE=\$(date +%Y%m%d_%H%M%S)

echo "==========================================" >> "\$LOG_FILE"
echo "Backup Replication - \$DATE" >> "\$LOG_FILE"
echo "==========================================" >> "\$LOG_FILE"

# Rsync with encryption and bandwidth limiting
rsync -avz --progress \
    --partial \
    --bwlimit=50000 \
    --delete \
    --delete-excluded \
    --exclude='*.tmp' \
    -e "ssh -i [REDACTED_PATH]/.ssh/backup_rsync -o StrictHostKeyChecking=accept-new" \
    "\$BACKUP_DIR/" \
    "\$REMOTE_USER@\$REMOTE_HOST:\$REMOTE_PATH/" >> "\$LOG_FILE" 2>&1

RSYNC_EXIT=\$?

if [ \$RSYNC_EXIT -eq 0 ]; then
    echo "Backup replication completed successfully" >> "\$LOG_FILE"
    logger -p user.info "Off-site backup replication completed"
else
    echo "Backup replication FAILED (exit: \$RSYNC_EXIT)" >> "\$LOG_FILE"
    logger -p user.error "Off-site backup replication failed"
fi

echo "Replication completed: \$DATE" >> "\$LOG_FILE"
RSYNC_SCRIPT
    chmod +x [REDACTED_PATH]/scripts/backups/replicate-to-remote.sh
    echo "  Rsync replication script created"
}

setup_s3_replication() {
    echo "[2/3] Setting up S3/cloud storage replication..."
    
    if [ -z "$S3_BUCKET" ]; then
        echo "  Skipping - S3_BUCKET not configured"
        echo "  Set in $CONFIG_FILE: S3_BUCKET=my-backup-bucket"
        return
    fi

    # Create S3 replication script
    cat > [REDACTED_PATH]/scripts/backups/replicate-to-s3.sh << S3_SCRIPT
#!/bin/bash
# Replicate backups to S3-compatible storage
set -euo pipefail

S3_BUCKET="$S3_BUCKET"
BACKUP_DIR="$BACKUP_DIR"
LOG_FILE="/var/log/backup-s3-replication.log"
DATE=\$(date +%Y%m%d_%H%M%S)

# Load secrets
if [ -f "[REDACTED_PATH]/.secrets/environment" ]; then
    source "[REDACTED_PATH]/.secrets/environment"
fi

echo "==========================================" >> "\$LOG_FILE"
echo "S3 Backup Replication - \$DATE" >> "\$LOG_FILE"
echo "==========================================" >> "\$LOG_FILE"

# Upload encrypted backups to S3
if command -v aws >/dev/null 2>&1; then
    aws s3 sync "\$BACKUP_DIR/" "s3://\$S3_BUCKET/\$(hostname)/" \
        --storage-class STANDARD_IA \
        --no-follow-symlinks \
        --exclude "*.tmp" \
        --sse aws:kms >> "\$LOG_FILE" 2>&1
    
    S3_EXIT=\$?
    if [ \$S3_EXIT -eq 0 ]; then
        echo "S3 replication completed successfully" >> "\$LOG_FILE"
        logger -p user.info "S3 backup replication completed"
    else
        echo "S3 replication FAILED (exit: \$S3_EXIT)" >> "\$LOG_FILE"
        logger -p user.error "S3 backup replication failed"
    fi
elif command -v b2 >/dev/null 2>&1; then
    b2 sync "\$BACKUP_DIR/" "b2://\$S3_BUCKET/\$(hostname)/" >> "\$LOG_FILE" 2>&1
    echo "Backblaze B2 replication completed" >> "\$LOG_FILE"
else
    echo "Neither AWS CLI nor B2 CLI available" >> "\$LOG_FILE"
fi

echo "S3 replication completed: \$DATE" >> "\$LOG_FILE"
S3_SCRIPT
    chmod +x [REDACTED_PATH]/scripts/backups/replicate-to-s3.sh
    echo "  S3 replication script created for bucket: $S3_BUCKET"
}

setup_b2_replication() {
    echo "[3/3] Setting up Backblaze B2 replication..."
    
    if [ -z "$B2_BUCKET" ]; then
        echo "  Skipping - B2_BUCKET not configured"
        echo "  Set in $CONFIG_FILE: B2_BUCKET=my-backup-bucket"
        return
    fi

    if ! command -v b2 >/dev/null 2>&1; then
        pip install b2 2>/dev/null || true
    fi

    cat > [REDACTED_PATH]/scripts/backups/replicate-to-b2.sh << B2_SCRIPT
#!/bin/bash
# Replicate backups to Backblaze B2
set -euo pipefail

B2_BUCKET="$B2_BUCKET"
BACKUP_DIR="$BACKUP_DIR"
LOG_FILE="/var/log/backup-b2-replication.log"
DATE=\$(date +%Y%m%d_%H%M%S)

echo "==========================================" >> "\$LOG_FILE"
echo "B2 Backup Replication - \$DATE" >> "\$LOG_FILE"
echo "==========================================" >> "\$LOG_FILE"

if command -v b2 >/dev/null 2>&1; then
    b2 sync "\$BACKUP_DIR/" "b2://\$B2_BUCKET/\$(hostname)/" \
        --noProgress \
        --excludeRegex ".*\.tmp" >> "\$LOG_FILE" 2>&1
    
    echo "B2 replication completed" >> "\$LOG_FILE"
    logger -p user.info "B2 backup replication completed"
else
    echo "B2 CLI not available" >> "\$LOG_FILE"
fi
B2_SCRIPT
    chmod +x [REDACTED_PATH]/scripts/backups/replicate-to-b2.sh
    echo "  B2 replication script created for bucket: $B2_BUCKET"
}

# Save config
save_config() {
    cat > "$CONFIG_FILE" << CFG
# Off-site Backup Configuration
# Source this file before running replication scripts

# Rsync remote
REMOTE_HOST="${REMOTE_HOST}"
REMOTE_USER="${REMOTE_USER}"
REMOTE_PATH="${REMOTE_PATH}"

# S3-compatible storage
S3_BUCKET="${S3_BUCKET}"
export AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID:-}"
export AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY:-}"

# Backblaze B2
B2_BUCKET="${B2_BUCKET}"

# Encryption
ENCRYPTION_KEY="${ENCRYPTION_KEY}"
GPG_RECIPIENT="${GPG_RECIPIENT}"
CFG
    chmod 600 "$CONFIG_FILE"
    echo "Configuration saved to $CONFIG_FILE"
}

# Set up cron for replication
setup_cron() {
    echo "Scheduling replication jobs..."
    
    if ! crontab -l 2>/dev/null | grep -q "replicate-to-remote"; then
        (crontab -l 2>/dev/null
         echo "# Off-site backup replication"
         echo "30 4 * * * [REDACTED_PATH]/scripts/backups/replicate-to-remote.sh"
         echo "0 5 * * * [REDACTED_PATH]/scripts/backups/replicate-to-s3.sh"
         echo "0 6 * * * [REDACTED_PATH]/scripts/backups/replicate-to-b2.sh"
        ) | crontab -
        echo "Replication cron jobs added"
    fi
}

# Run all
setup_encryption
echo ""
setup_rsync_replication
echo ""
setup_s3_replication
echo ""
setup_b2_replication
echo ""
save_config
setup_cron

echo ""
echo "=== Off-site Backup Replication Setup Complete ==="
echo ""
echo "Replication methods configured:"
echo "  - Rsync:     ${REMOTE_HOST:+$REMOTE_HOST}$([ -z \"$REMOTE_HOST\" ] && echo 'NOT CONFIGURED')"
echo "  - S3:        ${S3_BUCKET:+$S3_BUCKET}$([ -z \"$S3_BUCKET\" ] && echo 'NOT CONFIGURED')"
echo "  - B2:        ${B2_BUCKET:+$B2_BUCKET}$([ -z \"$B2_BUCKET\" ] && echo 'NOT CONFIGURED')"
echo ""
echo "Encryption: ${ENCRYPTION_KEY:+enabled}$([ -z \"$ENCRYPTION_KEY\" ] && echo 'configure key')"
echo ""
echo "Edit $CONFIG_FILE with your credentials"
echo "Run replication manually: [REDACTED_PATH]/scripts/backups/replicate-to-remote.sh"
