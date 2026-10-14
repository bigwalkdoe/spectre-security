#!/bin/bash
# Policy Version Manager
# Manages OPA policy versions with approval gates

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
POLICY_DIR="$SCRIPT_DIR/../security/opa/policies"
VERSIONS_DIR="$SCRIPT_DIR/../security/opa/versions"
POLICY_INDEX="$VERSIONS_DIR/index.json"

mkdir -p "$VERSIONS_DIR"

# Initialize index if not exists
if [ ! -f "$POLICY_INDEX" ]; then
    cat > "$POLICY_INDEX" << 'EOF'
{
  "policies": {},
  "current_version": "1.0.0",
  "history": []
}
EOF
fi

# Semantic version bump
bump_version() {
    local current="$1"
    local bump_type="$2"  # major, minor, patch
    
    IFS='.' read -r major minor patch <<< "$current"
    
    case "$bump_type" in
        major) major=$((major + 1)); minor=0; patch=0 ;;
        minor) minor=$((minor + 1)); patch=0 ;;
        patch) patch=$((patch + 1)) ;;
        *) echo "Invalid bump type: $bump_type"; exit 1 ;;
    esac
    
    echo "$major.$minor.$patch"
}

# Create new policy version
create_version() {
    local policy_file="$1"
    local bump_type="${2:-patch}"
    local message="${3:-Policy update}"
    
    local policy_name=$(basename "$policy_file" .rego)
    local current_version=$(jq -r ".policies.\"$policy_name\".version // \"0.0.0\"" "$POLICY_INDEX")
    local new_version=$(bump_version "$current_version" "$bump_type")
    local timestamp=$(date -Iseconds)
    local commit_hash=$(git rev-parse HEAD 2>/dev/null || echo "unknown")
    
    # Create version directory
    local version_dir="$VERSIONS_DIR/$policy_name/v$new_version"
    mkdir -p "$version_dir"
    
    # Copy policy and test files
    cp "$policy_file" "$version_dir/"
    cp "${policy_file%.*}_test.rego" "$version_dir/" 2>/dev/null || true
    
    # Create version metadata
    cat > "$version_dir/metadata.json" << EOF
{
  "policy": "$policy_name",
  "version": "$new_version",
  "previous_version": "$current_version",
  "timestamp": "$timestamp",
  "commit": "$commit_hash",
  "message": "$message",
  "bump_type": "$bump_type",
  "author": "$(git config user.name 2>/dev/null || echo "unknown")",
  "email": "$(git config user.email 2>/dev/null || echo "unknown")"
}
EOF
    
    # Update index
    jq --arg policy "$policy_name" \
       --arg version "$new_version" \
       --arg timestamp "$timestamp" \
       --arg commit "$commit_hash" \
       --arg message "$message" \
       --arg bump "$bump_type" \
       '.policies[$policy] = {
         "version": $version,
         "updated_at": $timestamp,
         "commit": $commit,
         "message": $message,
         "bump_type": $bump
       } | .current_version = $version | .history += [{
         "policy": $policy,
         "version": $version,
         "timestamp": $timestamp,
         "commit": $commit,
         "message": $message,
         "bump_type": $bump
       }]' "$POLICY_INDEX" > "$POLICY_INDEX.tmp" && mv "$POLICY_INDEX.tmp" "$POLICY_INDEX"
    
    echo "Created version v$new_version for $policy_name"
    echo "  Previous: $current_version"
    echo "  Message: $message"
    echo "  Bump: $bump_type"
}

# List all policy versions
list_versions() {
    local policy="${1:-}"
    
    if [ -n "$policy" ]; then
        echo "Versions for $policy:"
        ls -1 "$VERSIONS_DIR/$policy/" 2>/dev/null | sort -V | sed 's/^/  v/' || echo "  No versions found"
    else
        echo "All policy versions:"
        for policy_dir in "$VERSIONS_DIR"/*/; do
            [ -d "$policy_dir" ] || continue
            policy_name=$(basename "$policy_dir")
            versions=$(ls -1 "$policy_dir" 2>/dev/null | sort -V | sed 's/^/v/' | tr '\n' ' ')
            echo "  $policy_name: $versions"
        done
    fi
}

# Show version details
show_version() {
    local policy="$1"
    local version="$2"
    
    local version_dir="$VERSIONS_DIR/$policy/v$version"
    if [ ! -d "$version_dir" ]; then
        echo "Version $version not found for $policy"
        exit 1
    fi
    
    cat "$version_dir/metadata.json" | jq '.'
    echo ""
    echo "=== Policy ==="
    cat "$version_dir/${policy}.rego" | head -50
}

# Approve policy version (for CI/CD gate)
approve_version() {
    local policy="$1"
    local version="$2"
    local approver="${3:-$(git config user.name 2>/dev/null || echo "system")}"
    
    local version_dir="$VERSIONS_DIR/$policy/v$version"
    if [ ! -d "$version_dir" ]; then
        echo "Version $version not found for $policy"
        exit 1
    fi
    
    # Add approval to metadata
    local timestamp=$(date -Iseconds)
    jq --arg approver "$approver" \
       --arg timestamp "$timestamp" \
       '.approved = true | .approved_by = $approver | .approved_at = $timestamp' \
       "$version_dir/metadata.json" > "$version_dir/metadata.json.tmp" && \
    mv "$version_dir/metadata.json.tmp" "$version_dir/metadata.json"
    
    # Update index
    jq --arg policy "$policy" \
       --arg version "$version" \
       --arg approver "$approver" \
       --arg timestamp "$timestamp" \
       '.policies[$policy].approved = true | .policies[$policy].approved_by = $approver | .policies[$policy].approved_at = $timestamp' \
       "$POLICY_INDEX" > "$POLICY_INDEX.tmp" && mv "$POLICY_INDEX.tmp" "$POLICY_INDEX"
    
    echo "Approved $policy v$version by $approver at $timestamp"
}

# Check if policy version is approved
check_approval() {
    local policy="$1"
    local version="$2"
    
    local approved=$(jq -r ".policies.\"$policy\".approved // false" "$POLICY_INDEX")
    if [ "$approved" = "true" ]; then
        echo "Policy $policy v$version is APPROVED"
        return 0
    else
        echo "Policy $policy v$version is NOT APPROVED"
        return 1
    fi
}

# CI/CD Gate: Check all policies approved
check_all_approved() {
    local all_approved=true
    
    jq -r '.policies | to_entries[] | "\(.key) \(.value.version) \(.value.approved // false)"' "$POLICY_INDEX" | while read -r policy version approved; do
        if [ "$approved" = "true" ]; then
            echo "✅ $policy v$version - APPROVED"
        else
            echo "❌ $policy v$version - NOT APPROVED"
            all_approved=false
        fi
    done
    
    if [ "$all_approved" = "true" ]; then
        echo "All policies approved ✅"
        return 0
    else
        echo "Some policies not approved ❌"
        return 1
    fi
}

# Show help
show_help() {
    cat << EOF
Policy Version Manager

Usage: $0 <command> [args]

Commands:
  create <policy.rego> [major|minor|patch] [message]  Create new version
  list [policy]                                       List versions
  show <policy> <version>                             Show version details
  approve <policy> <version> [approver]               Approve version
  check <policy> <version>                            Check approval status
  check-all                                           Check all policies approved
  help                                                Show this help

Examples:
  $0 create security/opa/policies/kubernetes-admission.rego minor "Add hostPort restriction"
  $0 approve kubernetes-admission 1.1.0
  $0 check kubernetes-admission 1.1.0
  $0 check-all
EOF
}

# Main
case "${1:-help}" in
    create)
        create_version "$2" "${3:-patch}" "${4:-Policy update}"
        ;;
    list)
        list_versions "$2"
        ;;
    show)
        show_version "$2" "$3"
        ;;
    approve)
        approve_version "$2" "$3" "${4:-}"
        ;;
    check)
        check_approval "$2" "$3"
        ;;
    check-all)
        check_all_approved
        ;;
    help|*)
        show_help
        ;;
esac