#!/bin/bash
# Automated cleanup script for cache directories
# Cleans various cache directories to free up disk space

LOG_FILE="$HOME/scripts/logs/cleanup-cache.log"
CACHE_DIRS=(
    "$HOME/.cache"
    "$HOME/.npm/_cacache"
    "$HOME/.pyenv/cache"
    "$HOME/.config/Code/cache"
    "$HOME/.config/Code - Insiders/cache"
    "$HOME/.local/share/Trash/files"
)

# Create log directory if it doesn't exist
mkdir -p "$(dirname "$LOG_FILE")"

echo "=== Cache Cleanup - $(date) ===" >> "$LOG_FILE"
echo "Starting cache cleanup..." >> "$LOG_FILE"

TOTAL_FREED=0

for dir in "${CACHE_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        echo "Processing: $dir" >> "$LOG_FILE"
        
        # Get size before cleanup
        if [ -d "$dir" ]; then
            BEFORE_SIZE=$(du -sb "$dir" | cut -f1)
            BEFORE_SIZE_HUMAN=$(du -sh "$dir" | cut -f1)
        else
            BEFORE_SIZE=0
            BEFORE_SIZE_HUMAN="0B"
        fi
        
        # Remove files older than 90 days
        find "$dir" -type f -mtime +90 -delete 2>/dev/null
        
        # Get size after cleanup
        if [ -d "$dir" ]; then
            AFTER_SIZE=$(du -sb "$dir" | cut -f1)
            AFTER_SIZE_HUMAN=$(du -sh "$dir" | cut -f1)
        else
            AFTER_SIZE=0
            AFTER_SIZE_HUMAN="0B"
        fi
        
        FREED=$((BEFORE_SIZE - AFTER_SIZE))
        TOTAL_FREED=$((TOTAL_FREED + FREED))
        
        echo "$dir: $BEFORE_SIZE_HUMAN -> $AFTER_SIZE_HUMAN (freed: $(numfmt --to=iec-i $FREED))" >> "$LOG_FILE"
    fi
done

echo "" >> "$LOG_FILE"
echo "Total space freed: $(numfmt --to=iec-i $TOTAL_FREED)" >> "$LOG_FILE"
echo "Cache cleanup completed at $(date)" >> "$LOG_FILE"
echo "" >> "$LOG_FILE"

echo "Cache cleanup completed. Total space freed: $(numfmt --to=iec-i $TOTAL_FREED)"
echo "Log saved to: $LOG_FILE"