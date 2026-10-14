#!/bin/bash
# Cleanup script for temporary directories

LOG_FILE="$HOME/scripts/logs/cleanup-temp.log"
TEMP_DIRS=(
    "$HOME/temp"
    "/tmp"
)

# Create log directory if it doesn't exist
mkdir -p "$(dirname "$LOG_FILE")"

echo "=== Temp Directory Cleanup - $(date) ===" >> "$LOG_FILE"
echo "Starting temp directory cleanup..." >> "$LOG_FILE"

for dir in "${TEMP_DIRS[@]}"; do
    if [ -d "$dir" ] && [ -w "$dir" ]; then
        echo "Processing: $dir" >> "$LOG_FILE"
        
        # Get size before cleanup
        BEFORE_SIZE=$(du -sb "$dir" 2>/dev/null | cut -f1)
        BEFORE_SIZE_HUMAN=$(du -sh "$dir" 2>/dev/null | cut -f1)
        
        # Remove files older than 7 days
        find "$dir" -type f -mtime +7 -delete 2>/dev/null
        find "$dir" -type d -mtime +7 -empty -delete 2>/dev/null
        
        # Get size after cleanup
        AFTER_SIZE=$(du -sb "$dir" 2>/dev/null | cut -f1)
        AFTER_SIZE_HUMAN=$(du -sh "$dir" 2>/dev/null | cut -f1)
        
        if [ -n "$BEFORE_SIZE" ] && [ -n "$AFTER_SIZE" ]; then
            FREED=$((BEFORE_SIZE - AFTER_SIZE))
            echo "$dir: $BEFORE_SIZE_HUMAN -> $AFTER_SIZE_HUMAN (freed: $(numfmt --to=iec-i $FREED 2>/dev/null || echo $FREED))" >> "$LOG_FILE"
        fi
    fi
done

echo "Temp directory cleanup completed at $(date)" >> "$LOG_FILE"
echo "" >> "$LOG_FILE"

echo "Temp directory cleanup completed."
echo "Log saved to: $LOG_FILE"