#!/bin/bash

# CloudToLocalLLM Simple Timestamp Injector
# Generates a real timestamp and immediately updates all version files
# Eliminates the BUILD_TIME_PLACEHOLDER system that causes deployment failures

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

# Version files to update
PUBSPEC_FILE="$PROJECT_ROOT/pubspec.yaml"
ASSETS_VERSION_FILE="$PROJECT_ROOT/assets/version.json"
SHARED_VERSION_FILE="$PROJECT_ROOT/lib/shared/lib/version.dart"
SHARED_PUBSPEC_FILE="$PROJECT_ROOT/lib/shared/pubspec.yaml"
APP_CONFIG_FILE="$PROJECT_ROOT/lib/config/app_config.dart"

# Flags
VERBOSE=false
DRY_RUN=false

# Logging functions
log_info() {
    echo -e "${BLUE}[TIMESTAMP-INJECTOR]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[TIMESTAMP-INJECTOR] ✅${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[TIMESTAMP-INJECTOR] ⚠️${NC} $1"
}

log_error() {
    echo -e "${RED}[TIMESTAMP-INJECTOR] ❌${NC} $1"
}

log_verbose() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "${BLUE}[TIMESTAMP-INJECTOR] [VERBOSE]${NC} $1"
    fi
}

# Show usage information
show_usage() {
    cat << EOF
CloudToLocalLLM Simple Timestamp Injector

USAGE:
    $0 [OPTIONS]

OPTIONS:
    --verbose       Enable verbose output
    --dry-run       Show what would be done without making changes
    --help          Show this help message

DESCRIPTION:
    Generates a real timestamp in YYYYMMDDHHMM format and immediately updates
    all version files with this timestamp. Eliminates the BUILD_TIME_PLACEHOLDER
    system that causes "Invalid version number" errors during flutter pub get.

EXAMPLES:
    $0                      # Update all version files with current timestamp
    $0 --verbose            # Verbose output
    $0 --dry-run            # Show what would be done

FILES UPDATED:
    - pubspec.yaml
    - assets/version.json
    - lib/shared/lib/version.dart
    - lib/shared/pubspec.yaml
    - lib/config/app_config.dart (semantic version only)
EOF
}

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --verbose)
                VERBOSE=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --help)
                show_usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
}

# Generate timestamp in YYYYMMDDHHMM format
generate_timestamp() {
    date +"%Y%m%d%H%M"
}

# Generate ISO timestamp for JSON
generate_iso_timestamp() {
    date -u +"%Y-%m-%dT%H:%M:%SZ"
}

# Get current semantic version from pubspec.yaml
get_semantic_version() {
    if [[ ! -f "$PUBSPEC_FILE" ]]; then
        log_error "pubspec.yaml not found: $PUBSPEC_FILE"
        exit 1
    fi
    
    local version_line=$(grep "^version:" "$PUBSPEC_FILE")
    if [[ -z "$version_line" ]]; then
        log_error "Version line not found in pubspec.yaml"
        exit 1
    fi
    
    # Extract semantic version (before +)
    local full_version=$(echo "$version_line" | sed 's/^version: *//')
    echo "$full_version" | cut -d'+' -f1
}

# Get git commit hash
get_git_commit() {
    if git rev-parse --git-dir > /dev/null 2>&1; then
        git rev-parse --short HEAD 2>/dev/null || echo "unknown"
    else
        echo "unknown"
    fi
}

# Update pubspec.yaml with real timestamp
update_pubspec_version() {
    local semantic_version="$1"
    local build_timestamp="$2"
    local full_version="$semantic_version+$build_timestamp"
    
    log_info "Updating pubspec.yaml to $full_version"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "DRY RUN: Would update pubspec.yaml version to $full_version"
        return 0
    fi
    
    # Update version line
    sed -i "s/^version:.*/version: $full_version/" "$PUBSPEC_FILE"
    
    log_verbose "Updated $PUBSPEC_FILE"
}

# Update assets/version.json with real timestamp
update_assets_version_json() {
    local semantic_version="$1"
    local build_timestamp="$2"
    local iso_timestamp="$3"
    local git_commit="$4"
    
    log_info "Updating assets/version.json"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "DRY RUN: Would update assets/version.json with build_number: $build_timestamp"
        return 0
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
    
    log_verbose "Updated $ASSETS_VERSION_FILE"
}

# Update lib/shared/lib/version.dart with real timestamp
update_shared_version_file() {
    local semantic_version="$1"
    local build_timestamp="$2"
    local iso_timestamp="$3"
    
    log_info "Updating lib/shared/lib/version.dart"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "DRY RUN: Would update version.dart with build numbers: $build_timestamp"
        return 0
    fi
    
    if [[ ! -f "$SHARED_VERSION_FILE" ]]; then
        log_warning "lib/shared/lib/version.dart not found, skipping"
        return 0
    fi
    
    # Update build number constants (replace BUILD_TIME_PLACEHOLDER with actual numbers)
    sed -i "s/BUILD_TIME_PLACEHOLDER/$build_timestamp/g" "$SHARED_VERSION_FILE"
    
    # Update semantic version constants
    sed -i "s/static const String mainAppVersion = '[^']*'/static const String mainAppVersion = '$semantic_version'/" "$SHARED_VERSION_FILE"
    sed -i "s/static const String tunnelManagerVersion = '[^']*'/static const String tunnelManagerVersion = '$semantic_version'/" "$SHARED_VERSION_FILE"
    sed -i "s/static const String sharedLibraryVersion = '[^']*'/static const String sharedLibraryVersion = '$semantic_version'/" "$SHARED_VERSION_FILE"
    
    # Update build timestamp
    sed -i "s/static const String buildTimestamp = '[^']*'/static const String buildTimestamp = '$iso_timestamp'/" "$SHARED_VERSION_FILE"
    
    log_verbose "Updated $SHARED_VERSION_FILE"
}

# Update lib/shared/pubspec.yaml with real timestamp
update_shared_pubspec_version() {
    local semantic_version="$1"
    local build_timestamp="$2"
    local full_version="$semantic_version+$build_timestamp"
    
    log_info "Updating lib/shared/pubspec.yaml to $full_version"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "DRY RUN: Would update shared pubspec.yaml version to $full_version"
        return 0
    fi
    
    if [[ ! -f "$SHARED_PUBSPEC_FILE" ]]; then
        log_warning "lib/shared/pubspec.yaml not found, skipping"
        return 0
    fi
    
    # Update version line
    sed -i "s/^version:.*/version: $full_version/" "$SHARED_PUBSPEC_FILE"
    
    log_verbose "Updated $SHARED_PUBSPEC_FILE"
}

# Update lib/config/app_config.dart with semantic version
update_app_config_version() {
    local semantic_version="$1"
    
    log_info "Updating lib/config/app_config.dart to $semantic_version"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "DRY RUN: Would update app_config.dart appVersion to $semantic_version"
        return 0
    fi
    
    if [[ ! -f "$APP_CONFIG_FILE" ]]; then
        log_warning "lib/config/app_config.dart not found, skipping"
        return 0
    fi
    
    # Update appVersion constant
    sed -i "s/static const String appVersion = '[^']*'/static const String appVersion = '$semantic_version'/" "$APP_CONFIG_FILE"
    
    log_verbose "Updated $APP_CONFIG_FILE"
}

# Main injection function
inject_timestamp() {
    log_info "🕒 Starting simple timestamp injection..."
    
    # Generate timestamps
    local build_timestamp=$(generate_timestamp)
    local iso_timestamp=$(generate_iso_timestamp)
    local git_commit=$(get_git_commit)
    
    # Get current semantic version
    local semantic_version=$(get_semantic_version)
    
    log_info "Generated timestamp: $build_timestamp"
    log_info "Semantic version: $semantic_version"
    log_verbose "ISO timestamp: $iso_timestamp"
    log_verbose "Git commit: $git_commit"
    
    # Update all version files
    update_pubspec_version "$semantic_version" "$build_timestamp"
    update_assets_version_json "$semantic_version" "$build_timestamp" "$iso_timestamp" "$git_commit"
    update_shared_version_file "$semantic_version" "$build_timestamp" "$iso_timestamp"
    update_shared_pubspec_version "$semantic_version" "$build_timestamp"
    update_app_config_version "$semantic_version"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_success "DRY RUN: Simple timestamp injection simulation completed"
    else
        log_success "✅ Simple timestamp injection completed: $semantic_version+$build_timestamp"
        log_info "All version files updated with real timestamp - no more BUILD_TIME_PLACEHOLDER!"
    fi
}

# Validate environment
validate_environment() {
    log_verbose "Validating environment..."
    
    # Check if we're in the right directory
    if [[ ! -f "$PUBSPEC_FILE" ]]; then
        log_error "pubspec.yaml not found. Are you in the CloudToLocalLLM project root?"
        exit 1
    fi
    
    # Check required commands
    if ! command -v date &> /dev/null; then
        log_error "date command not found"
        exit 1
    fi
    
    if ! command -v sed &> /dev/null; then
        log_error "sed command not found"
        exit 1
    fi
    
    log_verbose "Environment validation passed"
}

# Main execution
main() {
    # Parse command line arguments
    parse_arguments "$@"
    
    # Show header
    if [[ "$VERBOSE" == "true" ]]; then
        log_info "CloudToLocalLLM Simple Timestamp Injector"
        log_info "Project root: $PROJECT_ROOT"
    fi
    
    # Validate environment
    validate_environment
    
    # Execute timestamp injection
    inject_timestamp
    
    # Success
    if [[ "$DRY_RUN" != "true" ]]; then
        log_success "🎉 Timestamp injection completed successfully!"
        log_info "You can now run 'flutter pub get' and 'flutter build' without errors"
    fi
}

# Execute main function with all arguments
main "$@"
