#!/bin/bash
# List all project archives with details

ARCHIVE_BASE="$HOME/dev/archives"

echo "=== Project Archives ==="
echo ""

if [ ! -d "$ARCHIVE_BASE" ]; then
    echo "No archives directory found"
    exit 0
fi

# List archives by year
for year_dir in "$ARCHIVE_BASE"/*; do
    if [ -d "$year_dir" ]; then
        year=$(basename "$year_dir")
        echo "📁 $year"
        echo "----------------------------------------"
        
        for archive in "$year_dir"/*.tar.gz; do
            if [ -f "$archive" ]; then
                archive_name=$(basename "$archive" .tar.gz)
                archive_size=$(du -sh "$archive" | cut -f1)
                archive_date=$(stat -c %y "$archive" | cut -d' ' -f1)
                echo "  📦 $archive_name"
                echo "     Size: $archive_size | Archived: $archive_date"
                echo "     Path: $archive"
                echo ""
            fi
        done
        
        echo ""
    fi
done

TOTAL_SIZE=$(du -sh "$ARCHIVE_BASE" 2>/dev/null | cut -f1)
TOTAL_ARCHIVES=$(find "$ARCHIVE_BASE" -name "*.tar.gz" | wc -l)
echo "========================================"
echo "Total archives: $TOTAL_ARCHIVES"
echo "Total size: $TOTAL_SIZE"