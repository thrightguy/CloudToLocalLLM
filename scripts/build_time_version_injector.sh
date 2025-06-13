#!/bin/bash

# CloudToLocalLLM Build-Time Version Injector v3.5.5+
# Injects actual build timestamp into version files at the moment of build execution
# Ensures build numbers reflect true build creation time

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# File paths
PUBSPEC_FILE="$PROJECT_ROOT/pubspec.yaml"
ASSETS_VERSION_FILE="$PROJECT_ROOT/assets/version.json"
SHARED_VERSION_FILE="$PROJECT_ROOT/lib/shared/lib/version.dart"
SHARED_PUBSPEC_FILE="$PROJECT_ROOT/lib/shared/pubspec.yaml"
APP_CONFIG_FILE="$PROJECT_ROOT/lib/config/app_config.dart"

# Logging functions
log_info() {
    echo -e "${BLUE}[BUILD-TIME]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[BUILD-TIME] ✅${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[BUILD-TIME] ⚠️${NC} $1"
}

log_error() {
    echo -e "${RED}[BUILD-TIME] ❌${NC} $1"
}

# Generate build timestamp in YYYYMMDDHHMM format
generate_build_timestamp() {
    date +"%Y%m%d%H%M"
}

# Generate ISO timestamp for build_date fields
generate_iso_timestamp() {
    date -u +"%Y-%m-%dT%H:%M:%SZ"
}

# Get current semantic version from pubspec.yaml
get_semantic_version() {
    if [[ ! -f "$PUBSPEC_FILE" ]]; then
        log_error "pubspec.yaml not found: $PUBSPEC_FILE"
        exit 1
    fi
    
    local version_line=$(grep '^version:' "$PUBSPEC_FILE" | head -1)
    if [[ -z "$version_line" ]]; then
        log_error "No version found in pubspec.yaml"
        exit 1
    fi
    
    # Extract semantic version (before +)
    echo "$version_line" | sed 's/version: *//' | tr -d ' ' | cut -d'+' -f1
}

# Create backup of a file
create_backup() {
    local file="$1"
    if [[ -f "$file" ]]; then
        cp "$file" "$file.build-backup"
        log_info "Created backup: $file.build-backup"
    fi
}

# Restore backup of a file
restore_backup() {
    local file="$1"
    if [[ -f "$file.build-backup" ]]; then
        mv "$file.build-backup" "$file"
        log_info "Restored backup: $file"
    fi
}

# Update pubspec.yaml with build timestamp
update_pubspec_version() {
    local semantic_version="$1"
    local build_timestamp="$2"
    local full_version="$semantic_version+$build_timestamp"
    
    log_info "Updating pubspec.yaml to $full_version"
    
    create_backup "$PUBSPEC_FILE"
    
    # Update version line
    sed -i "s/^version:.*/version: $full_version/" "$PUBSPEC_FILE"
    
    log_success "Updated pubspec.yaml to $full_version"
}

# Update assets/version.json with build timestamp
update_assets_version_json() {
    local semantic_version="$1"
    local build_timestamp="$2"
    local iso_timestamp="$3"
    
    log_info "Updating assets/version.json"
    
    if [[ ! -f "$ASSETS_VERSION_FILE" ]]; then
        log_warning "assets/version.json not found, creating new file"
        mkdir -p "$(dirname "$ASSETS_VERSION_FILE")"
    else
        create_backup "$ASSETS_VERSION_FILE"
    fi
    
    # Get git commit hash
    local git_commit="unknown"
    if command -v git >/dev/null 2>&1 && git rev-parse --git-dir >/dev/null 2>&1; then
        git_commit=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
    fi
    
    # Create/update the JSON file
    cat > "$ASSETS_VERSION_FILE" << EOF
{
  "version": "$semantic_version",
  "build_number": "$build_timestamp",
  "build_date": "$iso_timestamp",
  "git_commit": "$git_commit"
}
EOF
    
    log_success "Updated assets/version.json"
}

# Update shared/lib/version.dart with build timestamp
update_shared_version_file() {
    local semantic_version="$1"
    local build_timestamp="$2"
    local iso_timestamp="$3"
    
    log_info "Updating lib/shared/lib/version.dart"
    
    if [[ ! -f "$SHARED_VERSION_FILE" ]]; then
        log_warning "lib/shared/lib/version.dart not found, skipping"
        return
    fi
    
    create_backup "$SHARED_VERSION_FILE"
    
    # Update all version constants
    sed -i "s/static const String mainAppVersion = '[^']*';/static const String mainAppVersion = '$semantic_version';/" "$SHARED_VERSION_FILE"
    sed -i "s/static const int mainAppBuildNumber = [0-9]*;/static const int mainAppBuildNumber = $build_timestamp;/" "$SHARED_VERSION_FILE"
    sed -i "s/static const String tunnelManagerVersion = '[^']*';/static const String tunnelManagerVersion = '$semantic_version';/" "$SHARED_VERSION_FILE"
    sed -i "s/static const int tunnelManagerBuildNumber = [0-9]*;/static const int tunnelManagerBuildNumber = $build_timestamp;/" "$SHARED_VERSION_FILE"
    sed -i "s/static const String sharedLibraryVersion = '[^']*';/static const String sharedLibraryVersion = '$semantic_version';/" "$SHARED_VERSION_FILE"
    sed -i "s/static const int sharedLibraryBuildNumber = [0-9]*;/static const int sharedLibraryBuildNumber = $build_timestamp;/" "$SHARED_VERSION_FILE"
    sed -i "s/static const String buildTimestamp = '[^']*';/static const String buildTimestamp = '$iso_timestamp';/" "$SHARED_VERSION_FILE"
    
    log_success "Updated lib/shared/lib/version.dart"
}

# Update shared/pubspec.yaml with build timestamp
update_shared_pubspec_version() {
    local semantic_version="$1"
    local build_timestamp="$2"
    local full_version="$semantic_version+$build_timestamp"
    
    log_info "Updating lib/shared/pubspec.yaml"
    
    if [[ ! -f "$SHARED_PUBSPEC_FILE" ]]; then
        log_warning "lib/shared/pubspec.yaml not found, skipping"
        return
    fi
    
    create_backup "$SHARED_PUBSPEC_FILE"
    
    # Update version line
    sed -i "s/^version:.*/version: $full_version/" "$SHARED_PUBSPEC_FILE"
    
    log_success "Updated lib/shared/pubspec.yaml to $full_version"
}

# Update app_config.dart with semantic version
update_app_config_version() {
    local semantic_version="$1"
    
    log_info "Updating lib/config/app_config.dart"
    
    if [[ ! -f "$APP_CONFIG_FILE" ]]; then
        log_warning "lib/config/app_config.dart not found, skipping"
        return
    fi
    
    create_backup "$APP_CONFIG_FILE"
    
    # Update version constant
    sed -i "s/static const String appVersion = '[^']*';/static const String appVersion = '$semantic_version';/" "$APP_CONFIG_FILE"
    
    log_success "Updated lib/config/app_config.dart to $semantic_version"
}

# Inject build timestamp into all version files
inject_build_timestamp() {
    log_info "🕒 Injecting build timestamp at build execution time..."
    
    # Generate timestamps
    local build_timestamp=$(generate_build_timestamp)
    local iso_timestamp=$(generate_iso_timestamp)
    local semantic_version=$(get_semantic_version)
    
    log_info "Build timestamp: $build_timestamp"
    log_info "ISO timestamp: $iso_timestamp"
    log_info "Semantic version: $semantic_version"
    
    # Update all version files
    update_pubspec_version "$semantic_version" "$build_timestamp"
    update_assets_version_json "$semantic_version" "$build_timestamp" "$iso_timestamp"
    update_shared_version_file "$semantic_version" "$build_timestamp" "$iso_timestamp"
    update_shared_pubspec_version "$semantic_version" "$build_timestamp"
    update_app_config_version "$semantic_version"
    
    log_success "✅ Build timestamp injection completed: $semantic_version+$build_timestamp"
}

# Restore all backups (for cleanup after build)
restore_all_backups() {
    log_info "🔄 Restoring version files from backups..."
    
    restore_backup "$PUBSPEC_FILE"
    restore_backup "$ASSETS_VERSION_FILE"
    restore_backup "$SHARED_VERSION_FILE"
    restore_backup "$SHARED_PUBSPEC_FILE"
    restore_backup "$APP_CONFIG_FILE"
    
    log_success "✅ All version files restored from backups"
}

# Clean up backup files
cleanup_backups() {
    log_info "🧹 Cleaning up backup files..."
    
    rm -f "$PUBSPEC_FILE.build-backup"
    rm -f "$ASSETS_VERSION_FILE.build-backup"
    rm -f "$SHARED_VERSION_FILE.build-backup"
    rm -f "$SHARED_PUBSPEC_FILE.build-backup"
    rm -f "$APP_CONFIG_FILE.build-backup"
    
    log_success "✅ Backup files cleaned up"
}

# Main command dispatcher
main() {
    case "${1:-}" in
        "inject")
            inject_build_timestamp
            ;;
        "restore")
            restore_all_backups
            ;;
        "cleanup")
            cleanup_backups
            ;;
        "help"|"--help"|"-h"|"")
            echo "CloudToLocalLLM Build-Time Version Injector"
            echo ""
            echo "Usage: $0 <command>"
            echo ""
            echo "Commands:"
            echo "  inject    Inject current timestamp into all version files"
            echo "  restore   Restore all version files from backups"
            echo "  cleanup   Clean up backup files"
            echo "  help      Show this help message"
            echo ""
            echo "This script is designed to be called during the build process"
            echo "to ensure build numbers reflect actual build execution time."
            ;;
        *)
            log_error "Unknown command: $1"
            echo "Use '$0 help' for usage information"
            exit 1
            ;;
    esac
}

# Change to project root
cd "$PROJECT_ROOT"

# Execute main function
main "$@"
