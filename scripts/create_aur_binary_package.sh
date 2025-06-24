#!/bin/bash

# CloudToLocalLLM AUR Binary Package Creator
# Creates AUR-compatible binary packages for distribution
# Uses pre-built binaries to avoid Flutter dependency for end users

set -euo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DIST_DIR="$PROJECT_ROOT/dist"
AUR_DIR="$PROJECT_ROOT/aur-package"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

# Get version using unified version manager
get_version() {
    "$PROJECT_ROOT/scripts/version_manager.sh" get-semantic
}

# Get full version with build number
get_full_version() {
    "$PROJECT_ROOT/scripts/version_manager.sh" get
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if Flutter build exists
    local flutter_bundle="$PROJECT_ROOT/build/linux/x64/release/bundle"
    if [[ ! -d "$flutter_bundle" ]]; then
        log_error "Flutter Linux build not found. Run 'flutter build linux --release' first."
        exit 1
    fi
    
    # Check if main executable exists
    if [[ ! -f "$flutter_bundle/cloudtolocalllm" ]]; then
        log_error "Main executable not found in Flutter build"
        exit 1
    fi
    
    # Check if AUR directory exists
    if [[ ! -d "$AUR_DIR" ]]; then
        log_error "AUR package directory not found: $AUR_DIR"
        exit 1
    fi
    
    # Check if PKGBUILD exists
    if [[ ! -f "$AUR_DIR/PKGBUILD" ]]; then
        log_error "PKGBUILD not found in AUR directory"
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

# Create binary package structure
create_binary_package() {
    local version="$1"
    local package_name="cloudtolocalllm-${version}-x86_64"
    local package_dir="$DIST_DIR/$package_name"
    
    log_info "Creating binary package structure for version $version..."
    
    # Clean and create package directory
    rm -rf "$package_dir"
    mkdir -p "$package_dir"
    
    # Copy Flutter bundle
    local flutter_bundle="$PROJECT_ROOT/build/linux/x64/release/bundle"
    cp -r "$flutter_bundle"/* "$package_dir/"
    
    # Ensure main executable is executable
    chmod +x "$package_dir/cloudtolocalllm"
    
    # Copy documentation
    if [[ -f "$PROJECT_ROOT/README.md" ]]; then
        cp "$PROJECT_ROOT/README.md" "$package_dir/"
    fi
    
    if [[ -f "$PROJECT_ROOT/LICENSE" ]]; then
        cp "$PROJECT_ROOT/LICENSE" "$package_dir/"
    fi
    
    # Create package info file
    cat > "$package_dir/PACKAGE_INFO.txt" << EOF
CloudToLocalLLM Binary Package
Version: $version
Build Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)
Architecture: x86_64
Package Type: AUR Binary Distribution

This package contains pre-built binaries for CloudToLocalLLM,
eliminating the need for Flutter SDK installation on end-user systems.

Installation:
1. Extract package to /usr/share/cloudtolocalllm/
2. Create symlink: ln -sf /usr/share/cloudtolocalllm/cloudtolocalllm /usr/bin/
3. Run: cloudtolocalllm

For more information, visit: https://cloudtolocalllm.online
EOF
    
    log_success "Binary package structure created"
}

# Create compressed archive
create_archive() {
    local version="$1"
    local package_name="cloudtolocalllm-${version}-x86_64"
    local package_dir="$DIST_DIR/$package_name"
    local archive_name="${package_name}.tar.gz"
    
    log_info "Creating compressed archive..."
    
    cd "$DIST_DIR"
    
    # Create tar.gz archive
    tar -czf "$archive_name" "$package_name"
    
    if [[ ! -f "$archive_name" ]]; then
        log_error "Failed to create archive: $archive_name"
        exit 1
    fi
    
    log_success "Archive created: $archive_name"
}

# Generate checksums
generate_checksums() {
    local version="$1"
    local archive_name="cloudtolocalllm-${version}-x86_64.tar.gz"
    
    log_info "Generating checksums..."
    
    cd "$DIST_DIR"
    
    if [[ -f "$archive_name" ]]; then
        sha256sum "$archive_name" > "${archive_name}.sha256"
        local checksum=$(sha256sum "$archive_name" | cut -d' ' -f1)
        log_success "SHA256 checksum generated: $checksum"
        echo "$checksum"
    else
        log_error "Archive not found for checksum generation"
        exit 1
    fi
}

# Update PKGBUILD with new checksum
update_pkgbuild() {
    local version="$1"
    local checksum="$2"
    
    log_info "Updating PKGBUILD with new version and checksum..."
    
    # Create backup
    cp "$AUR_DIR/PKGBUILD" "$AUR_DIR/PKGBUILD.backup"
    
    # Update version
    sed -i "s/^pkgver=.*/pkgver=$version/" "$AUR_DIR/PKGBUILD"
    
    # Update checksum
    sed -i "s/sha256sums=.*/sha256sums=(\n    '$checksum'\n)/" "$AUR_DIR/PKGBUILD"
    
    log_success "PKGBUILD updated with version $version and checksum"
}

# Validate package
validate_package() {
    local version="$1"
    local archive_name="cloudtolocalllm-${version}-x86_64.tar.gz"
    
    log_info "Validating package..."
    
    cd "$DIST_DIR"
    
    # Check archive integrity
    if tar -tzf "$archive_name" >/dev/null 2>&1; then
        log_success "Archive integrity check passed"
    else
        log_error "Archive integrity check failed"
        exit 1
    fi
    
    # Check if main executable exists in archive
    if tar -tzf "$archive_name" | grep -q "cloudtolocalllm-${version}-x86_64/cloudtolocalllm"; then
        log_success "Main executable found in archive"
    else
        log_error "Main executable not found in archive"
        exit 1
    fi
    
    log_success "Package validation completed"
}

# Main execution function
main() {
    log_info "Starting CloudToLocalLLM AUR binary package creation..."
    
    # Get version
    local version=$(get_version)
    log_info "Building AUR binary package for version: $version"
    
    # Create dist directory
    mkdir -p "$DIST_DIR"
    
    # Execute build steps
    check_prerequisites
    create_binary_package "$version"
    create_archive "$version"
    local checksum=$(generate_checksums "$version")
    update_pkgbuild "$version" "$checksum"
    validate_package "$version"
    
    log_success "AUR binary package creation completed successfully!"
    log_info "Package location: $DIST_DIR/cloudtolocalllm-${version}-x86_64.tar.gz"
    log_info "SHA256 checksum: $checksum"
    log_info "PKGBUILD updated: $AUR_DIR/PKGBUILD"
    
    # Display final information
    echo
    echo "=== AUR Binary Package Summary ==="
    echo "Version: $version"
    echo "Package: cloudtolocalllm-${version}-x86_64.tar.gz"
    echo "Size: $(du -h "$DIST_DIR/cloudtolocalllm-${version}-x86_64.tar.gz" | cut -f1)"
    echo "SHA256: $checksum"
    echo
    echo "Next steps:"
    echo "1. Test package: cd aur-package && makepkg -si"
    echo "2. Submit to AUR: git add . && git commit -m 'Update to v$version'"
    echo
}

# Handle script arguments
case "${1:-}" in
    --help|-h)
        echo "CloudToLocalLLM AUR Binary Package Creator"
        echo
        echo "Usage: $0 [options]"
        echo
        echo "Options:"
        echo "  --help, -h     Show this help message"
        echo
        echo "This script creates AUR-compatible binary packages by:"
        echo "  - Packaging pre-built Flutter Linux binaries"
        echo "  - Creating compressed archives for distribution"
        echo "  - Generating SHA256 checksums"
        echo "  - Updating PKGBUILD with new version and checksums"
        echo
        echo "Requirements:"
        echo "  - Completed Flutter Linux build (flutter build linux --release)"
        echo "  - Existing AUR package structure in aur-package/"
        echo
        exit 0
        ;;
esac

# Run main function
main "$@"
