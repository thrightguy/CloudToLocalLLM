#!/bin/bash

# CloudToLocalLLM Version Management Utility
# Provides unified version management across all platforms and build systems

set -euo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PUBSPEC_FILE="$PROJECT_ROOT/pubspec.yaml"
APP_CONFIG_FILE="$PROJECT_ROOT/lib/config/app_config.dart"
SHARED_VERSION_FILE="$PROJECT_ROOT/lib/shared/lib/version.dart"
SHARED_PUBSPEC_FILE="$PROJECT_ROOT/lib/shared/pubspec.yaml"
ASSETS_VERSION_FILE="$PROJECT_ROOT/assets/version.json"

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

# Generate new build number based on current timestamp (YYYYMMDDHHMM format)
generate_build_number() {
    date +"%Y%m%d%H%M"
}

# Increment build number - generates placeholder for build-time injection
# Build timestamp will be injected at actual build execution time
increment_build_number() {
    # Generate placeholder timestamp that will be replaced at build time
    # This allows version preparation without finalizing the build timestamp
    echo "BUILD_TIME_PLACEHOLDER"
}

# Check if version qualifies for GitHub release
should_create_github_release() {
    local version="$1"
    local major=$(echo "$version" | cut -d. -f1)
    local minor=$(echo "$version" | cut -d. -f2)
    local patch=$(echo "$version" | cut -d. -f3)

    # Only create GitHub releases for major version updates (x.0.0)
    if [[ "$minor" == "0" && "$patch" == "0" ]]; then
        return 0  # true
    else
        return 1  # false
    fi
}

# Get release type based on version change
get_release_type() {
    local old_version="$1"
    local new_version="$2"

    local old_major=$(echo "$old_version" | cut -d. -f1)
    local old_minor=$(echo "$old_version" | cut -d. -f2)
    local old_patch=$(echo "$old_version" | cut -d. -f3)

    local new_major=$(echo "$new_version" | cut -d. -f1)
    local new_minor=$(echo "$new_version" | cut -d. -f2)
    local new_patch=$(echo "$new_version" | cut -d. -f3)

    if [[ "$new_major" != "$old_major" ]]; then
        echo "major"
    elif [[ "$new_minor" != "$old_minor" ]]; then
        echo "minor"
    elif [[ "$new_patch" != "$old_patch" ]]; then
        echo "patch"
    else
        echo "build"
    fi
}

# Increment version based on type (major, minor, patch, build)
#
# CloudToLocalLLM Semantic Versioning Strategy:
#
# PATCH (0.0.X+YYYYMMDDHHMM):
#   - Hotfixes and critical bug fixes requiring immediate deployment
#   - Security updates and emergency patches
#   - Critical stability fixes that can't wait for next minor release
#   - Example: Database connection fix, authentication bug, crash fix
#
# MINOR (0.X.0+YYYYMMDDHHMM):
#   - Feature additions and new functionality
#   - Quality of life improvements and UI enhancements
#   - Planned feature releases and capability expansions
#   - Example: New tunnel features, UI improvements, API additions
#
# MAJOR (X.0.0+YYYYMMDDHHMM):
#   - Breaking changes and architectural overhauls
#   - Significant API changes requiring user adaptation
#   - Major platform or framework migrations
#   - Example: Flutter 4.0 migration, API v2 breaking changes
#
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
            # MAJOR: Breaking changes, architectural overhauls, significant API changes
            major=$((major + 1))
            minor=0
            patch=0
            ;;
        "minor")
            # MINOR: Feature additions, UI enhancements, planned functionality
            minor=$((minor + 1))
            patch=0
            ;;
        "patch")
            # PATCH: Hotfixes, security updates, critical bug fixes
            patch=$((patch + 1))
            ;;
        "build")
            # BUILD: Timestamp-only increment, no semantic version change
            ;;
        *)
            log_error "Invalid increment type. Use: major, minor, patch, or build"
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

# Update version in shared/lib/version.dart
update_shared_version_file() {
    local new_version="$1"
    local new_build_number="$2"

    log_info "Updating shared/lib/version.dart to $new_version"

    if [[ ! -f "$SHARED_VERSION_FILE" ]]; then
        log_warning "shared/lib/version.dart not found, skipping update"
        return
    fi

    # Create backup
    cp "$SHARED_VERSION_FILE" "$SHARED_VERSION_FILE.backup"

    # Generate build timestamp and ensure build number is in YYYYMMDDHHMM format
    local build_timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    # Use the provided build_number parameter which should already be in YYYYMMDDHHMM format
    local build_number_int="$new_build_number"

    # Update all version constants
    sed -i "s/static const String mainAppVersion = '[^']*';/static const String mainAppVersion = '$new_version';/" "$SHARED_VERSION_FILE"
    sed -i "s/static const int mainAppBuildNumber = [0-9]*;/static const int mainAppBuildNumber = $build_number_int;/" "$SHARED_VERSION_FILE"
    sed -i "s/static const String tunnelManagerVersion = '[^']*';/static const String tunnelManagerVersion = '$new_version';/" "$SHARED_VERSION_FILE"
    sed -i "s/static const int tunnelManagerBuildNumber = [0-9]*;/static const int tunnelManagerBuildNumber = $build_number_int;/" "$SHARED_VERSION_FILE"
    sed -i "s/static const String sharedLibraryVersion = '[^']*';/static const String sharedLibraryVersion = '$new_version';/" "$SHARED_VERSION_FILE"
    sed -i "s/static const int sharedLibraryBuildNumber = [0-9]*;/static const int sharedLibraryBuildNumber = $build_number_int;/" "$SHARED_VERSION_FILE"
    sed -i "s/static const String buildTimestamp = '[^']*';/static const String buildTimestamp = '$build_timestamp';/" "$SHARED_VERSION_FILE"

    log_success "Updated shared/lib/version.dart to $new_version"
}

# Update version in shared/pubspec.yaml
update_shared_pubspec_version() {
    local new_version="$1"
    local new_build_number="$2"
    local full_version="$new_version+$new_build_number"

    log_info "Updating shared/pubspec.yaml version to $full_version"

    if [[ ! -f "$SHARED_PUBSPEC_FILE" ]]; then
        log_warning "shared/pubspec.yaml not found, skipping update"
        return
    fi

    # Create backup
    cp "$SHARED_PUBSPEC_FILE" "$SHARED_PUBSPEC_FILE.backup"

    # Update version line
    sed -i "s/^version:.*/version: $full_version/" "$SHARED_PUBSPEC_FILE"

    log_success "Updated shared/pubspec.yaml version to $full_version"
}

# Update version in assets/version.json
update_assets_version_json() {
    local new_version="$1"
    local new_build_number="$2"

    log_info "Updating assets/version.json to $new_version"

    if [[ ! -f "$ASSETS_VERSION_FILE" ]]; then
        log_warning "assets/version.json not found, skipping update"
        return
    fi

    # Create backup
    cp "$ASSETS_VERSION_FILE" "$ASSETS_VERSION_FILE.backup"

    # Generate build timestamp
    local build_timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)

    # Read current git commit (preserve existing value if available)
    local git_commit="unknown"
    if command -v git >/dev/null 2>&1 && git rev-parse --git-dir >/dev/null 2>&1; then
        git_commit=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
    fi

    # Update the JSON file using sed (preserving existing git_commit if extraction fails)
    sed -i "s/\"version\": \"[^\"]*\"/\"version\": \"$new_version\"/" "$ASSETS_VERSION_FILE"
    sed -i "s/\"build_number\": \"[^\"]*\"/\"build_number\": \"$new_build_number\"/" "$ASSETS_VERSION_FILE"
    sed -i "s/\"build_date\": \"[^\"]*\"/\"build_date\": \"$build_timestamp\"/" "$ASSETS_VERSION_FILE"

    # Only update git_commit if we successfully got one
    if [[ "$git_commit" != "unknown" ]]; then
        sed -i "s/\"git_commit\": \"[^\"]*\"/\"git_commit\": \"$git_commit\"/" "$ASSETS_VERSION_FILE"
    fi

    log_success "Updated assets/version.json to $new_version"
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
                log_error "Usage: $0 increment <major|minor|patch|build>"
                exit 1
            fi

            local current_version=$(get_semantic_version)
            local increment_type="$2"

            if [[ "$increment_type" == "build" ]]; then
                # For build increments, keep same semantic version but increment build number
                local new_build_number=$(increment_build_number)
                validate_version_format "$current_version"
                update_pubspec_version "$current_version" "$new_build_number"
                update_app_config_version "$current_version"
                update_shared_version_file "$current_version" "$new_build_number"
                update_shared_pubspec_version "$current_version" "$new_build_number"
                update_assets_version_json "$current_version" "$new_build_number"
                log_info "Build number incremented (no GitHub release needed)"
            else
                # For semantic version changes, generate new timestamp build number
                local new_version=$(increment_version "$increment_type")
                local new_build_number=$(generate_build_number)  # Use timestamp for new semantic version
                validate_version_format "$new_version"
                update_pubspec_version "$new_version" "$new_build_number"
                update_app_config_version "$new_version"
                update_shared_version_file "$new_version" "$new_build_number"
                update_shared_pubspec_version "$new_version" "$new_build_number"
                update_assets_version_json "$new_version" "$new_build_number"

                # Check if GitHub release should be created
                if should_create_github_release "$new_version"; then
                    log_warning "This is a MAJOR version update - GitHub release should be created!"
                    log_info "Run: git tag v$new_version && git push origin v$new_version"
                else
                    log_info "Minor/patch update - no GitHub release needed"
                fi
            fi

            show_version_info
            ;;
        "set")
            if [[ -z "${2:-}" ]]; then
                log_error "Usage: $0 set <version>"
                exit 1
            fi
            validate_version_format "$2"
            local new_build_number=$(generate_build_number)  # Use timestamp for set command
            update_pubspec_version "$2" "$new_build_number"
            update_app_config_version "$2"
            update_shared_version_file "$2" "$new_build_number"
            update_shared_pubspec_version "$2" "$new_build_number"
            update_assets_version_json "$2" "$new_build_number"
            show_version_info
            ;;
        "validate")
            local version=$(get_semantic_version)
            validate_version_format "$version"
            ;;
        "prepare")
            if [[ -z "${2:-}" ]]; then
                log_error "Usage: $0 prepare <major|minor|patch|build>"
                exit 1
            fi

            local current_version=$(get_semantic_version)
            local increment_type="$2"

            if [[ "$increment_type" == "build" ]]; then
                # For build preparation, keep same semantic version with placeholder
                local placeholder_build="BUILD_TIME_PLACEHOLDER"
                validate_version_format "$current_version"
                update_pubspec_version "$current_version" "$placeholder_build"
                update_app_config_version "$current_version"
                update_shared_version_file "$current_version" "$placeholder_build"
                update_shared_pubspec_version "$current_version" "$placeholder_build"
                update_assets_version_json "$current_version" "$placeholder_build"
                log_info "Version prepared for build-time timestamp injection"
            else
                # For semantic version changes, prepare with placeholder
                local new_version=$(increment_version "$increment_type")
                local placeholder_build="BUILD_TIME_PLACEHOLDER"
                validate_version_format "$new_version"
                update_pubspec_version "$new_version" "$placeholder_build"
                update_app_config_version "$new_version"
                update_shared_version_file "$new_version" "$placeholder_build"
                update_shared_pubspec_version "$new_version" "$placeholder_build"
                update_assets_version_json "$new_version" "$placeholder_build"

                # Check if GitHub release should be created
                if should_create_github_release "$new_version"; then
                    log_warning "This is a MAJOR version update - GitHub release should be created!"
                    log_info "Run: git tag v$new_version && git push origin v$new_version"
                else
                    log_info "Minor/patch update - no GitHub release needed"
                fi
            fi

            log_info "Version prepared with placeholder. Use build-time injection during actual build."
            show_version_info
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
            echo "  increment <type> Increment version (major|minor|patch|build) - immediate timestamp"
            echo "  prepare <type>   Prepare version (major|minor|patch|build) - build-time timestamp"
            echo "  set <version>    Set specific version (MAJOR.MINOR.PATCH)"
            echo "  validate         Validate current version format"
            echo "  help             Show this help message"
            echo ""
            echo "CloudToLocalLLM Semantic Versioning Strategy:"
            echo ""
            echo "  PATCH (0.0.X+YYYYMMDDHHMM) - URGENT FIXES:"
            echo "    • Hotfixes and critical bug fixes requiring immediate deployment"
            echo "    • Security updates and emergency patches"
            echo "    • Critical stability fixes that can't wait for next minor release"
            echo "    • Examples: Database connection fix, authentication bug, crash fix"
            echo ""
            echo "  MINOR (0.X.0+YYYYMMDDHHMM) - PLANNED FEATURES:"
            echo "    • Feature additions and new functionality"
            echo "    • Quality of life improvements and UI enhancements"
            echo "    • Planned feature releases and capability expansions"
            echo "    • Examples: New tunnel features, UI improvements, API additions"
            echo ""
            echo "  MAJOR (X.0.0+YYYYMMDDHHMM) - BREAKING CHANGES:"
            echo "    • Breaking changes and architectural overhauls"
            echo "    • Significant API changes requiring user adaptation"
            echo "    • Major platform or framework migrations"
            echo "    • Examples: Flutter 4.0 migration, API v2 breaking changes"
            echo "    • Creates GitHub release automatically"
            echo ""
            echo "  BUILD (X.Y.Z+YYYYMMDDHHMM) - TIMESTAMP ONLY:"
            echo "    • No semantic version change, only build timestamp update"
            echo "    • Used for CI/CD builds and testing iterations"
            echo ""
            echo "Build Number Format:"
            echo "  YYYYMMDDHHMM     Timestamp format representing build creation time"
            echo "  Example: 202506092204 = December 9, 2025 at 22:04"
            echo ""
            echo "Examples:"
            echo "  $0 info                    # Show current version info"
            echo "  $0 increment build         # Increment build number with immediate timestamp"
            echo "  $0 prepare build           # Prepare build increment for build-time timestamp"
            echo "  $0 increment patch         # Increment patch version with immediate timestamp"
            echo "  $0 prepare patch           # Prepare patch increment for build-time timestamp"
            echo "  $0 increment major         # Increment major (creates GitHub release)"
            echo "  $0 set 3.1.0              # Set version to 3.1.0 with immediate timestamp"
            echo ""
            echo "Build-Time Workflow:"
            echo "  1. $0 prepare build        # Prepare version with placeholder"
            echo "  2. flutter build ...       # Build process injects actual timestamp"
            echo "  3. Artifacts have real build creation time"
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
