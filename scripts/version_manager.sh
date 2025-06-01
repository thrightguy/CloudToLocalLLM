#!/bin/bash

# CloudToLocalLLM Version Management Utility
# Provides unified version management across all platforms and build systems

set -euo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PUBSPEC_FILE="$PROJECT_ROOT/pubspec.yaml"
APP_CONFIG_FILE="$PROJECT_ROOT/lib/config/app_config.dart"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Extract version components from pubspec.yaml
get_version_from_pubspec() {
    if [[ ! -f "$PUBSPEC_FILE" ]]; then
        log_error "pubspec.yaml not found at $PUBSPEC_FILE"
        exit 1
    fi
    
    local version_line=$(grep "^version:" "$PUBSPEC_FILE" | head -1)
    if [[ -z "$version_line" ]]; then
        log_error "No version found in pubspec.yaml"
        exit 1
    fi
    
    # Extract version (format: version: MAJOR.MINOR.PATCH+BUILD_NUMBER)
    local full_version=$(echo "$version_line" | sed 's/version: *//' | tr -d ' ')
    echo "$full_version"
}

# Extract semantic version (without build number)
get_semantic_version() {
    local full_version=$(get_version_from_pubspec)
    echo "$full_version" | sed 's/+.*//'
}

# Extract build number
get_build_number() {
    local full_version=$(get_version_from_pubspec)
    if [[ "$full_version" == *"+"* ]]; then
        echo "$full_version" | sed 's/.*+//'
    else
        echo "1"
    fi
}

# Generate new build number based on current timestamp
generate_build_number() {
    date +"%Y%m%d%H%M"
}

# Increment version based on type (major, minor, patch)
increment_version() {
    local increment_type="$1"
    local current_version=$(get_semantic_version)
    
    # Parse current version
    local major=$(echo "$current_version" | cut -d. -f1)
    local minor=$(echo "$current_version" | cut -d. -f2)
    local patch=$(echo "$current_version" | cut -d. -f3)
    
    # Increment based on type
    case "$increment_type" in
        "major")
            major=$((major + 1))
            minor=0
            patch=0
            ;;
        "minor")
            minor=$((minor + 1))
            patch=0
            ;;
        "patch")
            patch=$((patch + 1))
            ;;
        *)
            log_error "Invalid increment type. Use: major, minor, or patch"
            exit 1
            ;;
    esac
    
    echo "$major.$minor.$patch"
}

# Update version in pubspec.yaml
update_pubspec_version() {
    local new_version="$1"
    local new_build_number="$2"
    local full_version="$new_version+$new_build_number"
    
    log_info "Updating pubspec.yaml version to $full_version"
    
    # Create backup
    cp "$PUBSPEC_FILE" "$PUBSPEC_FILE.backup"
    
    # Update version line
    sed -i "s/^version:.*/version: $full_version/" "$PUBSPEC_FILE"
    
    log_success "Updated pubspec.yaml version to $full_version"
}

# Update version in app_config.dart
update_app_config_version() {
    local new_version="$1"
    
    log_info "Updating app_config.dart version to $new_version"
    
    if [[ ! -f "$APP_CONFIG_FILE" ]]; then
        log_warning "app_config.dart not found, skipping update"
        return
    fi
    
    # Create backup
    cp "$APP_CONFIG_FILE" "$APP_CONFIG_FILE.backup"
    
    # Update version constant
    sed -i "s/static const String appVersion = '[^']*';/static const String appVersion = '$new_version';/" "$APP_CONFIG_FILE"
    
    log_success "Updated app_config.dart version to $new_version"
}

# Validate version format
validate_version_format() {
    local version="$1"
    
    # Check semantic version format (MAJOR.MINOR.PATCH)
    if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        log_error "Invalid version format: $version. Expected format: MAJOR.MINOR.PATCH"
        exit 1
    fi
    
    log_success "Version format is valid: $version"
}

# Display current version information
show_version_info() {
    local full_version=$(get_version_from_pubspec)
    local semantic_version=$(get_semantic_version)
    local build_number=$(get_build_number)
    
    echo -e "${CYAN}=== CloudToLocalLLM Version Information ===${NC}"
    echo -e "Full Version:     ${GREEN}$full_version${NC}"
    echo -e "Semantic Version: ${GREEN}$semantic_version${NC}"
    echo -e "Build Number:     ${GREEN}$build_number${NC}"
    echo -e "Source File:      ${BLUE}$PUBSPEC_FILE${NC}"
}

# Main command dispatcher
main() {
    case "${1:-}" in
        "get")
            get_version_from_pubspec
            ;;
        "get-semantic")
            get_semantic_version
            ;;
        "get-build")
            get_build_number
            ;;
        "info")
            show_version_info
            ;;
        "increment")
            if [[ -z "${2:-}" ]]; then
                log_error "Usage: $0 increment <major|minor|patch>"
                exit 1
            fi
            local new_version=$(increment_version "$2")
            local new_build_number=$(generate_build_number)
            validate_version_format "$new_version"
            update_pubspec_version "$new_version" "$new_build_number"
            update_app_config_version "$new_version"
            show_version_info
            ;;
        "set")
            if [[ -z "${2:-}" ]]; then
                log_error "Usage: $0 set <version>"
                exit 1
            fi
            validate_version_format "$2"
            local new_build_number=$(generate_build_number)
            update_pubspec_version "$2" "$new_build_number"
            update_app_config_version "$2"
            show_version_info
            ;;
        "validate")
            local version=$(get_semantic_version)
            validate_version_format "$version"
            ;;
        "help"|"--help"|"-h"|"")
            echo "CloudToLocalLLM Version Manager"
            echo ""
            echo "Usage: $0 <command> [arguments]"
            echo ""
            echo "Commands:"
            echo "  get              Get full version (MAJOR.MINOR.PATCH+BUILD)"
            echo "  get-semantic     Get semantic version (MAJOR.MINOR.PATCH)"
            echo "  get-build        Get build number"
            echo "  info             Show detailed version information"
            echo "  increment <type> Increment version (major|minor|patch)"
            echo "  set <version>    Set specific version (MAJOR.MINOR.PATCH)"
            echo "  validate         Validate current version format"
            echo "  help             Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0 info                    # Show current version info"
            echo "  $0 increment patch         # Increment patch version"
            echo "  $0 set 2.1.0              # Set version to 2.1.0"
            ;;
        *)
            log_error "Unknown command: $1"
            echo "Use '$0 help' for usage information"
            exit 1
            ;;
    esac
}

# Execute main function with all arguments
main "$@"
