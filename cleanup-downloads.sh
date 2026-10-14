#!/bin/bash
# Automated cleanup script for Downloads directory
# Removes files older than 30 days by default

DOWNLOADS_DIR="$HOME/Downloads"
DAYS=${1:-30}  # Default to 30 days, can be overridden with argument
LOG_FILE="$HOME/scripts/logs/cleanup-downloads.log"

# Create log directory if it doesn't exist
mkdir -p "$(dirname "$LOG_FILE")"

echo "=== Downloads Cleanup - $(date) ===" >> "$LOG_FILE"
echo "Cleaning files older than $DAYS days from $DOWNLOADS_DIR" >> "$LOG_FILE"

# Count files before cleanup
BEFORE_COUNT=$(find "$DOWNLOADS_DIR" -type f | wc -l)
BEFORE_SIZE=$(du -sh "$DOWNLOADS_DIR" | cut -f1)
echo "Before: $BEFORE_COUNT files, $BEFORE_SIZE" >> "$LOG_FILE"

# Remove files older than specified days
find "$DOWNLOADS_DIR" -type f -mtime +$DAYS -exec rm -v {} \; >> "$LOG_FILE" 2>&1

# Count files after cleanup
AFTER_COUNT=$(find "$DOWNLOADS_DIR" -type f | wc -l)
AFTER_SIZE=$(du -sh "$DOWNLOADS_DIR" | cut -f1)
echo "After: $AFTER_COUNT files, $AFTER_SIZE" >> "$LOG_FILE"
echo "Removed: $((BEFORE_COUNT - AFTER_COUNT)) files" >> "$LOG_FILE"
echo "Cleanup completed at $(date)" >> "$LOG_FILE"
echo "" >> "$LOG_FILE"

echo "Downloads cleanup completed. Removed $((BEFORE_COUNT - AFTER_COUNT)) files older than $DAYS days."
echo "Log saved to: $LOG_FILE"