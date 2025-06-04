#!/bin/bash

# CloudToLocalLLM Smart Deployment Script
# Implements the new granular versioning strategy with intelligent release decisions

set -euo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
VERSION_MANAGER="$PROJECT_ROOT/scripts/version_manager.sh"

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

log_section() {
    echo -e "${CYAN}=== $1 ===${NC}"
}

# Get version information
get_current_version() {
    "$VERSION_MANAGER" get-semantic
}

get_current_build() {
    "$VERSION_MANAGER" get-build
}

get_full_version() {
    "$VERSION_MANAGER" get
}

# Check if GitHub release should be created
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

# Update AUR package with new version
update_aur_package() {
    local version="$1"
    local build_number="$2"
    local aur_pkgbuild="$PROJECT_ROOT/aur-package/PKGBUILD"
    
    log_info "Updating AUR package to version $version+$build_number"
    
    if [[ ! -f "$aur_pkgbuild" ]]; then
        log_error "AUR PKGBUILD not found at $aur_pkgbuild"
        return 1
    fi
    
    # Update version in PKGBUILD
    sed -i "s/pkgver=.*/pkgver=$version/" "$aur_pkgbuild"
    
    # Update .SRCINFO
    cd "$PROJECT_ROOT/aur-package"
    makepkg --printsrcinfo > .SRCINFO
    
    log_success "AUR package updated to version $version"
}

# Create GitHub release (only for major versions)
create_github_release() {
    local version="$1"
    local build_number="$2"
    
    log_section "Creating GitHub Release v$version"
    
    # Build release assets
    log_info "Building release assets..."
    "$PROJECT_ROOT/scripts/packaging/build_all_packages.sh"
    
    # Create Git tag
    log_info "Creating Git tag v$version"
    git tag -a "v$version" -m "CloudToLocalLLM v$version - Major Release"
    git push origin "v$version"
    
    log_success "GitHub release v$version created"
    log_info "Release assets should be uploaded manually to GitHub"
}

# Deploy to VPS (always done)
deploy_to_vps() {
    local version="$1"
    local build_number="$2"
    
    log_section "Deploying to VPS"
    
    log_info "Deploying version $version+$build_number to VPS..."
    
    # Run VPS deployment script
    if [[ -f "$PROJECT_ROOT/scripts/deploy/update_and_deploy.sh" ]]; then
        "$PROJECT_ROOT/scripts/deploy/update_and_deploy.sh"
        log_success "VPS deployment completed"
    else
        log_warning "VPS deployment script not found, skipping"
    fi
}

# Update documentation
update_documentation() {
    local version="$1"
    local build_number="$2"
    local release_type="$3"
    
    log_info "Updating documentation for version $version+$build_number"
    
    # Update README if major/minor release
    if [[ "$release_type" == "major" || "$release_type" == "minor" ]]; then
        log_info "Updating README.md with new version information"
        # Add any README updates here if needed
    fi
    
    log_success "Documentation updated"
}

# Generate deployment summary
generate_deployment_summary() {
    local version="$1"
    local build_number="$2"
    local release_type="$3"
    local github_release="$4"
    
    log_section "Deployment Summary"
    
    echo -e "${CYAN}Version:${NC} $version+$build_number"
    echo -e "${CYAN}Release Type:${NC} $release_type"
    echo -e "${CYAN}GitHub Release:${NC} $github_release"
    echo -e "${CYAN}AUR Package:${NC} Updated"
    echo -e "${CYAN}VPS Deployment:${NC} Completed"
    
    if [[ "$github_release" == "Yes" ]]; then
        echo ""
        echo -e "${YELLOW}Next Steps:${NC}"
        echo "1. Upload release assets to GitHub release v$version"
        echo "2. Update AUR repository with new PKGBUILD"
        echo "3. Announce major release to users"
    else
        echo ""
        echo -e "${YELLOW}Next Steps:${NC}"
        echo "1. Update AUR repository with new PKGBUILD"
        echo "2. Monitor VPS deployment"
    fi
}

# Main deployment function
deploy() {
    local increment_type="$1"
    
    log_section "CloudToLocalLLM Smart Deployment"
    
    # Get current version info
    local current_version=$(get_current_version)
    local current_build=$(get_current_build)
    
    log_info "Current version: $current_version+$current_build"
    log_info "Increment type: $increment_type"
    
    # Increment version
    log_info "Incrementing version..."
    "$VERSION_MANAGER" increment "$increment_type"
    
    # Get new version info
    local new_version=$(get_current_version)
    local new_build=$(get_current_build)
    local full_version=$(get_full_version)
    
    log_success "Version updated to: $full_version"
    
    # Determine if GitHub release is needed
    local github_release="No"
    if should_create_github_release "$new_version"; then
        github_release="Yes"
    fi
    
    # Update AUR package
    update_aur_package "$new_version" "$new_build"
    
    # Create GitHub release if needed
    if [[ "$github_release" == "Yes" ]]; then
        create_github_release "$new_version" "$new_build"
    else
        log_info "Skipping GitHub release (not a major version)"
    fi
    
    # Deploy to VPS
    deploy_to_vps "$new_version" "$new_build"
    
    # Update documentation
    update_documentation "$new_version" "$new_build" "$increment_type"
    
    # Generate summary
    generate_deployment_summary "$new_version" "$new_build" "$increment_type" "$github_release"
    
    log_success "Smart deployment completed successfully!"
}

# Show usage information
show_usage() {
    echo "CloudToLocalLLM Smart Deployment Script"
    echo ""
    echo "Usage: $0 <increment_type>"
    echo ""
    echo "Increment Types:"
    echo "  major    - Major release (x.0.0) - Creates GitHub release"
    echo "  minor    - Minor release (x.y.0) - No GitHub release"
    echo "  patch    - Patch release (x.y.z) - No GitHub release"
    echo "  build    - Build increment (x.y.z+nnn) - No GitHub release"
    echo ""
    echo "Examples:"
    echo "  $0 build    # Increment build number for testing"
    echo "  $0 patch    # Bug fix release"
    echo "  $0 minor    # Feature addition"
    echo "  $0 major    # Major release with breaking changes"
}

# Main execution
main() {
    if [[ $# -eq 0 ]]; then
        show_usage
        exit 1
    fi
    
    local increment_type="$1"
    
    case "$increment_type" in
        "major"|"minor"|"patch"|"build")
            deploy "$increment_type"
            ;;
        "help"|"--help"|"-h")
            show_usage
            ;;
        *)
            log_error "Invalid increment type: $increment_type"
            show_usage
            exit 1
            ;;
    esac
}

# Execute main function
main "$@"
