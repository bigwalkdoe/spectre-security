#!/bin/bash
# Projects Backup Script
# Backs up critical project directories

# Resolve the invoking user's home and this repository's root. Under sudo,
# $HOME is /root, so fall back to $SUDO_USER before trusting it. Both may be
# overridden: SPECTRE_HOME=/srv/secure SPECTRE_REPO=/opt/spectre-security
_spectre_here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SPECTRE_HOME="${SPECTRE_HOME:-$(getent passwd "${SUDO_USER:-$USER}" 2>/dev/null | cut -d: -f6)}"
SPECTRE_HOME="${SPECTRE_HOME:-$HOME}"
SPECTRE_REPO="${SPECTRE_REPO:-$(git -C "$_spectre_here" rev-parse --show-toplevel 2>/dev/null || echo "$_spectre_here")}"
BACKUP_DIR="/backups/projects"
DATE=$(date +%Y%m%d_%H%M%S)
RETENTION_DAYS=14

mkdir -p "$BACKUP_DIR"

echo "Backing up project directories..."

# Critical projects to backup
PROJECTS=(
    "${SPECTRE_HOME}/projects/example-project"
    "${SPECTRE_HOME}/projects/Modelink"
)

for project in "${PROJECTS[@]}"; do
    project_name=$(basename "$project")
    echo "Backing up project: $project_name"
    
    # Exclude node_modules, .git, and other build artifacts
    tar czf "$BACKUP_DIR/${project_name}_$DATE.tar.gz" \
        --exclude='node_modules' \
        --exclude='.git' \
        --exclude='__pycache__' \
        --exclude='*.pyc' \
        --exclude='.venv' \
        --exclude='venv' \
        --exclude='dist' \
        --exclude='build' \
        --exclude='.next' \
        --exclude='.cache' \
        -C "${SPECTRE_HOME}" "projects/$(basename "$project")"
done

# Backup scripts directory
echo "Backing up scripts directory..."
tar czf "$BACKUP_DIR/scripts_$DATE.tar.gz" -C ${SPECTRE_HOME} scripts

# Cleanup old backups
echo "Cleaning up old project backups (older than $RETENTION_DAYS days)..."
find "$BACKUP_DIR" -type f -mtime +$RETENTION_DAYS -delete

echo "Project backup completed: $DATE"
logger -p user.info "Project backup completed successfully"
