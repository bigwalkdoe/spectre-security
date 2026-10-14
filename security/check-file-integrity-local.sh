#!/bin/bash
# AIDE File Integrity Check (Local version - no sudo required)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AIDE_DIR="$SCRIPT_DIR/aide"
AIDE_CHECKSUM="$AIDE_DIR/aide.db.gz"
AIDE_LOG="$AIDE_DIR/aide.log"
AIDE_CONF="$AIDE_DIR/aide.conf"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p "$AIDE_DIR"

echo "=== AIDE File Integrity Check - $DATE ==="

# Create AIDE config if it doesn't exist
if [ ! -f "$AIDE_CONF" ]; then
    cat > "$AIDE_CONF" << EOF
# AIDE Configuration for Repository Integrity
database_in=file:$AIDE_DIR/aide.db.gz
database_out=file:$AIDE_DIR/aide.db.new.gz
gzip_dbout=yes
report_url=file:$AIDE_DIR/aide.log
report_url=stdout
EOF
fi

if [ ! -f "$AIDE_CHECKSUM" ]; then
    echo "No AIDE database found. Running initialization..."
    aide --init --config="$AIDE_CONF" 2>&1 | tail -20
    if [ -f "$AIDE_DIR/aide.db.new.gz" ]; then
        cp "$AIDE_DIR/aide.db.new.gz" "$AIDE_CHECKSUM"
        echo "AIDE database initialized"
    fi
fi

echo "Checking file integrity..."
aide --check --config="$AIDE_CONF" > "$AIDE_LOG" 2>&1
AIDE_EXIT=$?

if [ $AIDE_EXIT -eq 0 ]; then
    echo "File integrity check PASSED"
else
    echo "WARNING: File integrity changes detected!"
    echo "Check $AIDE_LOG for details"
    cat "$AIDE_LOG"
fi

# Update database after successful check
if [ -f "$AIDE_DIR/aide.db.new.gz" ]; then
    cp "$AIDE_DIR/aide.db.new.gz" "$AIDE_CHECKSUM"
    echo "AIDE database updated"
fi

echo "AIDE check completed (exit code: $AIDE_EXIT)"
exit $AIDE_EXIT
