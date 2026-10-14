#!/bin/bash
# Setup script for automated maintenance cron jobs

echo "=== Directory Management Cron Setup ==="
echo ""
echo "This script will help you set up automated maintenance jobs."
echo "The following cron jobs will be added:"
echo ""
echo "1. Daily temp cleanup (2:00 AM)"
echo "2. Weekly Downloads cleanup (Sunday 3:00 AM - files older than 30 days)"
echo "3. Monthly cache cleanup (1st of month 4:00 AM - files older than 90 days)"
echo ""

# Check if crontab exists
if ! crontab -l >/dev/null 2>&1; then
    echo "No existing crontab found. Creating new one."
else
    echo "Existing crontab found. Current entries:"
    echo "----------------------------------------"
    crontab -l
    echo "----------------------------------------"
    echo ""
fi

read -p "Add automated maintenance jobs to crontab? (y/n): " -n 1 -r
echo
echo

if [[ $REPLY =~ ^[Yy]$ ]]; then
    # Get current crontab
    CURRENT_CRON=$(crontab -l 2>/dev/null || echo "")
    
    # Add new cron jobs
    NEW_CRON="$CURRENT_CRON

# Directory Management - Automated Maintenance
# Daily temp cleanup at 2:00 AM
0 2 * * * $HOME/scripts/cleanup-temp.sh

# Weekly Downloads cleanup on Sunday at 3:00 AM (files older than 30 days)
0 3 * * 0 $HOME/scripts/cleanup-downloads.sh 30

# Monthly cache cleanup on 1st at 4:00 AM (files older than 90 days)
0 4 1 * * $HOME/scripts/cleanup-cache.sh
"
    
    # Install new crontab
    echo "$NEW_CRON" | crontab -
    
    echo "Cron jobs installed successfully!"
    echo ""
    echo "Current crontab:"
    echo "----------------------------------------"
    crontab -l
    echo "----------------------------------------"
    echo ""
    echo "Maintenance schedule:"
    echo "  - Temp cleanup: Daily at 2:00 AM"
    echo "  - Downloads cleanup: Weekly (Sunday) at 3:00 AM"
    echo "  - Cache cleanup: Monthly (1st) at 4:00 AM"
else
    echo "Cron setup cancelled."
    echo ""
    echo "To add manually, add these lines to your crontab (crontab -e):"
    echo ""
    echo "# Directory Management - Automated Maintenance"
    echo "0 2 * * * $HOME/scripts/cleanup-temp.sh"
    echo "0 3 * * 0 $HOME/scripts/cleanup-downloads.sh 30"
    echo "0 4 1 * * $HOME/scripts/cleanup-cache.sh"
fi