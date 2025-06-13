#!/bin/bash

# CloudToLocalLLM AUR Local Package Preparation
# Prepares AUR package with local distribution file instead of external download
# Eliminates 404 errors by including the binary directly in the AUR repository

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
AUR_DIR="$PROJECT_ROOT/aur-package"
DIST_DIR="$PROJECT_ROOT/dist"

# Flags
VERBOSE=false
DRY_RUN=false
FORCE=false

# Logging functions (output to stderr to avoid capture in command substitution)
log_info() {
    echo -e "${BLUE}[AUR-LOCAL-PREP]${NC} $1" >&2
}

log_success() {
    echo -e "${GREEN}[AUR-LOCAL-PREP] ✅${NC} $1" >&2
}

log_warning() {
    echo -e "${YELLOW}[AUR-LOCAL-PREP] ⚠️${NC} $1" >&2
}

log_error() {
    echo -e "${RED}[AUR-LOCAL-PREP] ❌${NC} $1" >&2
}

log_verbose() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "${BLUE}[AUR-LOCAL-PREP] [VERBOSE]${NC} $1" >&2
    fi
}

# Show usage information
show_usage() {
    cat << EOF
CloudToLocalLLM AUR Local Package Preparation

USAGE:
    $0 [OPTIONS]

OPTIONS:
    --verbose       Enable verbose output
    --dry-run       Show what would be done without making changes
    --force         Force operations without prompts
    --help          Show this help message

DESCRIPTION:
    Prepares the AUR package to use a local distribution file instead of
    external downloads. This eliminates 404 errors and makes the package
    installation completely offline.

WORKFLOW:
    1. Locates the current distribution file in dist/ directory
    2. Copies the distribution file to aur-package/ directory
    3. Verifies the PKGBUILD is configured for local file usage
    4. Updates checksums if needed
    5. Prepares the package for AUR submission

EXAMPLES:
    $0                      # Prepare AUR package with local file
    $0 --verbose            # Verbose output
    $0 --dry-run            # Show what would be done

FILES INVOLVED:
    - dist/cloudtolocalllm-VERSION-x86_64.tar.gz (source)
    - aur-package/cloudtolocalllm-VERSION-x86_64.tar.gz (destination)
    - aur-package/PKGBUILD (updated for local file)
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
            --force)
                FORCE=true
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

# Get current version from pubspec.yaml
get_version() {
    if [[ ! -f "$PROJECT_ROOT/pubspec.yaml" ]]; then
        log_error "pubspec.yaml not found"
        exit 1
    fi
    
    local version_line=$(grep "^version:" "$PROJECT_ROOT/pubspec.yaml")
    if [[ -z "$version_line" ]]; then
        log_error "Version line not found in pubspec.yaml"
        exit 1
    fi
    
    # Extract semantic version (before +)
    local full_version=$(echo "$version_line" | sed 's/^version: *//')
    echo "$full_version" | cut -d'+' -f1
}

# Validate environment
validate_environment() {
    log_verbose "Validating environment..."
    
    # Check if we're in the right directory
    if [[ ! -f "$PROJECT_ROOT/pubspec.yaml" ]]; then
        log_error "pubspec.yaml not found. Are you in the CloudToLocalLLM project root?"
        exit 1
    fi
    
    # Check if AUR directory exists
    if [[ ! -d "$AUR_DIR" ]]; then
        log_error "AUR directory not found: $AUR_DIR"
        exit 1
    fi
    
    # Check if PKGBUILD exists
    if [[ ! -f "$AUR_DIR/PKGBUILD" ]]; then
        log_error "PKGBUILD not found in AUR directory"
        exit 1
    fi
    
    # Check required commands
    if ! command -v sha256sum &> /dev/null; then
        log_error "sha256sum command not found"
        exit 1
    fi
    
    if ! command -v makepkg &> /dev/null; then
        log_warning "makepkg not found - .SRCINFO regeneration may fail"
    fi
    
    log_verbose "Environment validation passed"
}

# Find distribution file
find_distribution_file() {
    local version="$1"
    local dist_file="$DIST_DIR/cloudtolocalllm-$version-x86_64.tar.gz"

    log_info "Looking for distribution file: cloudtolocalllm-$version-x86_64.tar.gz"

    if [[ ! -f "$dist_file" ]]; then
        log_error "Distribution file not found: $dist_file"
        log_error "Please ensure the unified package has been built"
        exit 1
    fi

    # Check file size
    local file_size=$(du -h "$dist_file" | cut -f1)
    log_verbose "Found distribution file: $dist_file ($file_size)"

    # Return the file path via stdout
    echo "$dist_file"
}

# Copy distribution file to AUR directory
copy_distribution_file() {
    local source_file="$1"
    local version="$2"
    local dest_file="$AUR_DIR/cloudtolocalllm-$version-x86_64.tar.gz"
    
    log_info "Copying distribution file to AUR directory..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "DRY RUN: Would copy $source_file to $dest_file"
        return 0
    fi
    
    # Copy the file
    cp "$source_file" "$dest_file"
    
    # Verify copy
    if [[ ! -f "$dest_file" ]]; then
        log_error "Failed to copy distribution file"
        exit 1
    fi
    
    local dest_size=$(du -h "$dest_file" | cut -f1)
    log_success "Distribution file copied successfully ($dest_size)"

    # Return the file path via stdout
    echo "$dest_file"
}

# Verify PKGBUILD configuration
verify_pkgbuild_config() {
    local version="$1"
    
    log_info "Verifying PKGBUILD configuration for local file usage..."
    
    # Check if PKGBUILD uses local file (not external URL)
    if grep -q "https://" "$AUR_DIR/PKGBUILD"; then
        log_warning "PKGBUILD still contains external URLs"
        log_warning "This should have been updated to use local files"
        
        if [[ "$FORCE" == "true" ]]; then
            log_info "Force mode: Continuing despite URL presence"
        else
            log_error "Please update PKGBUILD to use local files first"
            log_error "Use --force to continue anyway"
            exit 1
        fi
    fi
    
    # Check version in PKGBUILD
    local pkgbuild_version=$(grep "^pkgver=" "$AUR_DIR/PKGBUILD" | cut -d'=' -f2)
    if [[ "$pkgbuild_version" != "$version" ]]; then
        log_warning "PKGBUILD version ($pkgbuild_version) doesn't match current version ($version)"
        
        if [[ "$FORCE" == "true" ]]; then
            log_info "Force mode: Updating PKGBUILD version..."
            if [[ "$DRY_RUN" != "true" ]]; then
                sed -i "s/^pkgver=.*/pkgver=$version/" "$AUR_DIR/PKGBUILD"
            fi
            log_success "PKGBUILD version updated to $version"
        else
            log_error "Use --force to automatically update the version"
            exit 1
        fi
    fi
    
    log_verbose "PKGBUILD configuration verified"
}

# Update checksums
update_checksums() {
    local dist_file="$1"
    local version="$2"
    
    log_info "Updating SHA256 checksums..."
    
    # Calculate new checksum
    local new_checksum=$(sha256sum "$dist_file" | cut -d' ' -f1)
    log_verbose "New SHA256 checksum: $new_checksum"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "DRY RUN: Would update PKGBUILD with checksum: $new_checksum"
        return 0
    fi
    
    # Update PKGBUILD checksum (handle both empty and existing checksums)
    sed -i "s/'[a-f0-9]\{64\}'/'$new_checksum'/; s/''/'$new_checksum'/" "$AUR_DIR/PKGBUILD"
    
    log_success "SHA256 checksum updated in PKGBUILD"
}

# Regenerate .SRCINFO
regenerate_srcinfo() {
    log_info "Regenerating .SRCINFO..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "DRY RUN: Would regenerate .SRCINFO"
        return 0
    fi
    
    cd "$AUR_DIR"
    
    if command -v makepkg &> /dev/null; then
        makepkg --printsrcinfo > .SRCINFO
        log_success ".SRCINFO regenerated successfully"
    else
        log_warning "makepkg not available - .SRCINFO not regenerated"
        log_warning "Please run 'makepkg --printsrcinfo > .SRCINFO' manually in the AUR directory"
    fi
    
    cd "$PROJECT_ROOT"
}

# Display summary
display_summary() {
    local version="$1"
    local dist_file="$2"
    
    log_success "🎉 AUR local package preparation completed!"
    echo ""
    echo "📋 Summary:"
    echo "  ✅ Version: $version"
    echo "  ✅ Distribution file: $(basename "$dist_file")"
    echo "  ✅ File size: $(du -h "$dist_file" | cut -f1)"
    echo "  ✅ AUR directory: $AUR_DIR"
    echo "  ✅ Local file approach: Enabled"
    echo ""
    echo "📋 Next Steps:"
    echo "  1. Review changes in aur-package/ directory"
    echo "  2. Test package build: cd aur-package && makepkg -si"
    echo "  3. Submit to AUR: ./scripts/deploy/submit_aur_package.sh --force"
    echo ""
    echo "📋 Benefits:"
    echo "  ✅ No external download dependencies"
    echo "  ✅ Eliminates 404 errors"
    echo "  ✅ Completely offline installation"
    echo "  ✅ More reliable for end users"
}

# Main execution function
main() {
    # Parse command line arguments
    parse_arguments "$@"
    
    # Show header
    if [[ "$VERBOSE" == "true" ]]; then
        log_info "CloudToLocalLLM AUR Local Package Preparation"
        log_info "Project root: $PROJECT_ROOT"
        log_info "AUR directory: $AUR_DIR"
    fi
    
    # Validate environment
    validate_environment
    
    # Get current version
    local version=$(get_version)
    log_info "Preparing AUR package for version: $version"
    
    # Find and copy distribution file
    local source_dist_file
    source_dist_file=$(find_distribution_file "$version")
    local dest_dist_file
    dest_dist_file=$(copy_distribution_file "$source_dist_file" "$version")
    
    # Verify and update PKGBUILD
    verify_pkgbuild_config "$version"
    update_checksums "$dest_dist_file" "$version"
    regenerate_srcinfo
    
    # Display summary
    if [[ "$DRY_RUN" != "true" ]]; then
        display_summary "$version" "$dest_dist_file"
    else
        log_success "DRY RUN: AUR local package preparation simulation completed"
    fi
}

# Execute main function with all arguments
main "$@"
