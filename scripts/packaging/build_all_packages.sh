#!/bin/bash

# CloudToLocalLLM Unified Package Build Script
# Builds all package formats with unified version management

set -euo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

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

# Version management functions
get_version() {
    "$PROJECT_ROOT/scripts/version_manager.sh" get-semantic
}

get_full_version() {
    "$PROJECT_ROOT/scripts/version_manager.sh" get
}

get_build_number() {
    "$PROJECT_ROOT/scripts/version_manager.sh" get-build
}

# Increment version based on type
increment_version() {
    local increment_type="$1"
    log_info "Incrementing $increment_type version..."
    "$PROJECT_ROOT/scripts/version_manager.sh" increment "$increment_type"
}

# Validate version consistency across all packages
validate_version_consistency() {
    log_info "Validating version consistency across all packages..."
    
    local semantic_version=$(get_version)
    local full_version=$(get_full_version)
    local build_number=$(get_build_number)
    
    log_info "Semantic Version: $semantic_version"
    log_info "Full Version: $full_version"
    log_info "Build Number: $build_number"
    
    # Validate version format
    if ! "$PROJECT_ROOT/scripts/version_manager.sh" validate; then
        log_error "Version validation failed"
        exit 1
    fi
    
    log_success "Version validation passed"
}

# Update Flutter app configuration with current version
update_flutter_version() {
    log_info "Updating Flutter application version configuration..."
    
    local semantic_version=$(get_version)
    local build_number=$(get_build_number)
    
    # Update app_config.dart with current version
    local app_config_file="$PROJECT_ROOT/lib/config/app_config.dart"
    if [[ -f "$app_config_file" ]]; then
        sed -i "s/static const String appVersion = '[^']*';/static const String appVersion = '$semantic_version';/" "$app_config_file"
        log_success "Updated app_config.dart with version $semantic_version"
    fi
    
    # Create version.json asset for runtime version access
    local assets_dir="$PROJECT_ROOT/assets"
    mkdir -p "$assets_dir"
    
    cat > "$assets_dir/version.json" << EOFVERSION
{
  "version": "$semantic_version",
  "build_number": "$build_number",
  "build_date": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "git_commit": "$(git rev-parse --short HEAD 2>/dev/null || echo 'unknown')"
}
EOFVERSION
    
    log_success "Created version.json asset"
}

# Build Snap package
build_snap() {
    log_info "Building Snap package..."

    if [[ "$OSTYPE" != "linux-gnu"* ]]; then
        log_warning "Skipping Snap build (Linux required)"
        return 0
    fi

    cd "$SCRIPT_DIR"
    if ./build_snap.sh; then
        log_success "Snap build completed"
    else
        log_error "Snap build failed"
        return 1
    fi
}

# Build Debian package (deprecated - no longer supported)
build_debian() {
    log_warning "Debian package building is no longer supported"
    log_info "CloudToLocalLLM now supports: AUR, AppImage, Flatpak, and Snap packages"
    log_info "Use PowerShell Create-UnifiedPackages.ps1 for comprehensive package creation"
    return 0
}

# Build AUR package
build_aur() {
    log_info "Building AUR package..."

    if [[ "$OSTYPE" != "linux-gnu"* ]]; then
        log_warning "Skipping AUR build (Linux required)"
        return 0
    fi

    if [[ ! -f /etc/arch-release ]]; then
        log_warning "Skipping AUR build (Arch Linux required)"
        return 0
    fi

    cd "$SCRIPT_DIR"
    if ./build_aur.sh; then
        log_success "AUR package build completed"
    else
        log_error "AUR package build failed"
        return 1
    fi
}

# Validate all generated packages
validate_packages() {
    log_info "Validating generated packages..."
    
    local version=$(get_version)
    local dist_dir="$PROJECT_ROOT/dist"
    local validation_errors=0
    
    # Check Snap package
    if [[ -f "$dist_dir/cloudtolocalllm_${version}_amd64.snap" ]]; then
        log_success "Snap package found: cloudtolocalllm_${version}_amd64.snap"
        if [[ -f "$dist_dir/cloudtolocalllm_${version}_amd64.snap.sha256" ]]; then
            log_success "Snap package checksum found"
        else
            log_error "Snap package checksum missing"
            ((validation_errors++))
        fi
    else
        log_warning "Snap package not found (may have been skipped)"
    fi
    
    # Debian packages no longer supported
    log_info "Debian package building is deprecated - skipping validation"

    # Check AUR package
    if [[ -f "$dist_dir/aur/cloudtolocalllm-${version}.tar.gz" ]]; then
        log_success "AUR source tarball found: cloudtolocalllm-${version}.tar.gz"
        if [[ -f "$dist_dir/aur/cloudtolocalllm-${version}.tar.gz.sha256" ]]; then
            log_success "AUR source tarball checksum found"
        else
            log_error "AUR source tarball checksum missing"
            ((validation_errors++))
        fi
    else
        log_warning "AUR package not found (may have been skipped)"
    fi
    
    if [[ $validation_errors -gt 0 ]]; then
        log_error "Package validation failed with $validation_errors errors"
        return 1
    else
        log_success "All packages validated successfully"
        return 0
    fi
}

# Generate build summary
generate_summary() {
    log_info "Generating build summary..."
    
    local version=$(get_version)
    local full_version=$(get_full_version)
    local build_number=$(get_build_number)
    local dist_dir="$PROJECT_ROOT/dist"
    
    echo
    echo "=== CloudToLocalLLM Build Summary ==="
    echo "Semantic Version: $version"
    echo "Full Version: $full_version"
    echo "Build Number: $build_number"
    echo "Build Date: $(date)"
    echo
    echo "Generated Packages:"
    
    # List all generated packages with sizes
    if [[ -f "$dist_dir/cloudtolocalllm_${version}_amd64.snap" ]]; then
        local size=$(du -h "$dist_dir/cloudtolocalllm_${version}_amd64.snap" | cut -f1)
        echo "  Snap: cloudtolocalllm_${version}_amd64.snap ($size)"
    fi
    
    # Debian packages no longer supported

    if [[ -f "$dist_dir/aur/cloudtolocalllm-${version}.tar.gz" ]]; then
        local size=$(du -h "$dist_dir/aur/cloudtolocalllm-${version}.tar.gz" | cut -f1)
        echo "  AUR: cloudtolocalllm-${version}.tar.gz ($size)"
    fi
    
    echo
    echo "Distribution Directory: $dist_dir"
    echo
}

# Main execution function
main() {
    local increment_type=""
    local skip_version_increment=false
    local packages_to_build="all"
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --increment)
                increment_type="$2"
                shift 2
                ;;
            --skip-increment)
                skip_version_increment=true
                shift
                ;;
            --packages)
                packages_to_build="$2"
                shift 2
                ;;
            --help|-h)
                echo "CloudToLocalLLM Unified Package Build Script"
                echo
                echo "Usage: $0 [options]"
                echo
                echo "Options:"
                echo "  --increment <type>    Increment version (major|minor|patch)"
                echo "  --skip-increment      Skip version increment"
                echo "  --packages <list>     Build specific packages (all|snap|aur)"
                echo "  --help, -h           Show this help message"
                echo
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done
    
    log_info "Starting CloudToLocalLLM unified package build..."
    
    # Increment version if requested
    if [[ -n "$increment_type" ]] && [[ "$skip_version_increment" == false ]]; then
        increment_version "$increment_type"
    fi
    
    # Validate version consistency
    validate_version_consistency
    
    # Update Flutter version configuration
    update_flutter_version
    
    # Build packages based on selection
    local build_errors=0
    
    case "$packages_to_build" in
        "all")
            build_snap || ((build_errors++))
            build_aur || ((build_errors++))
            ;;
        "snap")
            build_snap || ((build_errors++))
            ;;
        "debian")
            log_warning "Debian package building is deprecated. Use 'snap' or 'aur' instead."
            build_debian  # Will show deprecation message
            ;;
        "aur")
            build_aur || ((build_errors++))
            ;;
        *)
            log_error "Invalid package selection: $packages_to_build"
            log_error "Supported options: all, snap, aur"
            exit 1
            ;;
    esac
    
    # Validate generated packages
    if ! validate_packages; then
        ((build_errors++))
    fi
    
    # Generate summary
    generate_summary
    
    # Final status
    if [[ $build_errors -eq 0 ]]; then
        log_success "All package builds completed successfully!"
        exit 0
    else
        log_error "Package build completed with $build_errors errors"
        exit 1
    fi
}

# Execute main function with all arguments
main "$@"
