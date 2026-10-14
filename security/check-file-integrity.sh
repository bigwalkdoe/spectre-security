#!/bin/bash
# AIDE File Integrity Check
set -euo pipefail

AIDE_CHECKSUM="/var/lib/aide/aide.db.gz"
AIDE_LOG="/var/log/aide/aide.log"
DATE=$(date +%Y%m%d_%H%M%S)

echo "=== AIDE File Integrity Check - $DATE ==="

if [ ! -f "$AIDE_CHECKSUM" ]; then
    echo "No AIDE database found. Running initialization..."
    sudo aide --init
    sudo cp /var/lib/aide/aide.db.new.gz /var/lib/aide/aide.db.gz
fi

echo "Checking file integrity..."
sudo aide --check > "$AIDE_LOG" 2>&1
AIDE_EXIT=$?

if [ $AIDE_EXIT -eq 0 ]; then
    echo "File integrity check PASSED"
    logger -p user.info "AIDE integrity check passed"
else
    echo "WARNING: File integrity changes detected!"
    echo "Check $AIDE_LOG for details"
    logger -p user.warning "AIDE integrity check failed - changes detected"
    cat "$AIDE_LOG"
fi

# Update database after successful check
if [ -f /var/lib/aide/aide.db.new.gz ]; then
    sudo cp /var/lib/aide/aide.db.new.gz /var/lib/aide/aide.db.gz
    echo "AIDE database updated"
fi

echo "AIDE check completed (exit code: $AIDE_EXIT)"
