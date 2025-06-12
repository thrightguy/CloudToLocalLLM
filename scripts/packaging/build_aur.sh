#!/bin/bash

# CloudToLocalLLM AUR Package Build Script
# Builds AUR packages with unified version management

set -euo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
BUILD_DIR="$PROJECT_ROOT/build/aur"
DIST_DIR="$PROJECT_ROOT/dist/aur"

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

# Extract version using unified version manager
get_version() {
    "$PROJECT_ROOT/scripts/version_manager.sh" get-semantic
}

# Get full version with build number
get_full_version() {
    "$PROJECT_ROOT/scripts/version_manager.sh" get
}

# Get build number
get_build_number() {
    "$PROJECT_ROOT/scripts/version_manager.sh" get-build
}

# Check if running on Arch Linux
check_arch_linux() {
    if [[ ! -f /etc/arch-release ]]; then
        log_error "AUR packages can only be built on Arch Linux"
        exit 1
    fi
    
    log_success "Running on Arch Linux"
}

# Check dependencies
check_dependencies() {
    log_info "Checking AUR build dependencies..."
    
    # Check for required tools
    local missing_tools=()
    
    if ! command -v makepkg &> /dev/null; then
        missing_tools+=("base-devel")
    fi
    
    if ! command -v git &> /dev/null; then
        missing_tools+=("git")
    fi
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        log_error "Missing required packages: ${missing_tools[*]}"
        log_info "Install with: sudo pacman -S ${missing_tools[*]}"
        exit 1
    fi
    
    log_success "All dependencies available"
}

# Create PKGBUILD file
create_pkgbuild() {
    local version="$1"
    local build_number="$2"
    
    log_info "Creating PKGBUILD file..."
    
    mkdir -p "$BUILD_DIR"
    
    cat > "$BUILD_DIR/PKGBUILD" << EOF
# Maintainer: CloudToLocalLLM Team <support@cloudtolocalllm.online>
pkgname=cloudtolocalllm
pkgver=$version
pkgrel=1
pkgdesc="Manage and run powerful Large Language Models locally, orchestrated via a cloud interface"
arch=('x86_64')
url="https://cloudtolocalllm.online"
license=('MIT')
depends=('gtk3' 'libayatana-appindicator')
makedepends=('flutter' 'git' 'imagemagick')
source=("git+https://github.com/imrightguy/CloudToLocalLLM.git#tag=v\$pkgver")
sha256sums=('SKIP')

build() {
    cd "\$srcdir/CloudToLocalLLM"
    
    # Clean and get dependencies
    flutter clean
    flutter pub get
    
    # Build Flutter application with build-time timestamp injection
    if [[ -f "scripts/flutter_build_with_timestamp.sh" && -x "scripts/flutter_build_with_timestamp.sh" ]]; then
        scripts/flutter_build_with_timestamp.sh linux --release
    else
        flutter build linux --release
    fi
    
    # Apply tray manager fix if needed
    if [[ -f scripts/fix_tray_manager_deprecation.sh ]]; then
        bash scripts/fix_tray_manager_deprecation.sh apply || true
    fi
    
    # Rebuild with fixes and build-time timestamp injection
    if [[ -f "scripts/flutter_build_with_timestamp.sh" && -x "scripts/flutter_build_with_timestamp.sh" ]]; then
        scripts/flutter_build_with_timestamp.sh linux --release
    else
        flutter build linux --release
    fi
}

package() {
    cd "\$srcdir/CloudToLocalLLM"
    
    # Install application
    install -dm755 "\$pkgdir/usr/bin"
    cp -r build/linux/x64/release/bundle/* "\$pkgdir/usr/bin/"
    
    # Make executable
    chmod +x "\$pkgdir/usr/bin/cloudtolocalllm"
    
    # Install desktop file
    install -Dm644 assets/linux/cloudtolocalllm.desktop "\$pkgdir/usr/share/applications/cloudtolocalllm.desktop"
    
    # Install icons
    install -Dm644 assets/images/icon.png "\$pkgdir/usr/share/icons/hicolor/256x256/apps/cloudtolocalllm.png"
    
    # Generate additional icon sizes
    for size in 16 32 48 64 128; do
        install -dm755 "\$pkgdir/usr/share/icons/hicolor/\${size}x\${size}/apps"
        convert assets/images/icon.png -resize \${size}x\${size} "\$pkgdir/usr/share/icons/hicolor/\${size}x\${size}/apps/cloudtolocalllm.png"
    done
    
    # Install man page (if exists)
    if [[ -f assets/linux/cloudtolocalllm.1 ]]; then
        install -Dm644 assets/linux/cloudtolocalllm.1 "\$pkgdir/usr/share/man/man1/cloudtolocalllm.1"
    fi
}
EOF

    log_success "PKGBUILD file created"
}

# Build AUR package
build_aur_package() {
    local version="$1"
    
    log_info "Building AUR package..."
    
    cd "$BUILD_DIR"
    
    # Build the package
    makepkg -sf --noconfirm
    
    # Move generated package to dist directory
    mkdir -p "$DIST_DIR"
    local pkg_file=$(find . -name "*.pkg.tar.zst" -type f | head -1)
    
    if [[ -n "$pkg_file" ]]; then
        mv "$pkg_file" "$DIST_DIR/"
        log_success "AUR package created: $(basename "$pkg_file")"
    else
        log_error "AUR package creation failed - no .pkg.tar.zst file found"
        exit 1
    fi
}

# Generate source tarball for AUR
generate_source_tarball() {
    local version="$1"
    
    log_info "Generating source tarball for AUR..."
    
    mkdir -p "$DIST_DIR"
    
    # Create source tarball
    cd "$PROJECT_ROOT"
    git archive --format=tar.gz --prefix="cloudtolocalllm-$version/" HEAD > "$DIST_DIR/cloudtolocalllm-$version.tar.gz"
    
    # Generate checksum
    cd "$DIST_DIR"
    sha256sum "cloudtolocalllm-$version.tar.gz" > "cloudtolocalllm-$version.tar.gz.sha256"
    
    log_success "Source tarball created: cloudtolocalllm-$version.tar.gz"
}

# Clean up build artifacts
cleanup_build_artifacts() {
    log_info "Cleaning up AUR build artifacts..."
    
    # Remove build directory
    rm -rf "$BUILD_DIR"
    
    log_success "Build artifacts cleaned up"
}

# Generate build summary
generate_summary() {
    local version="$1"
    
    log_info "Generating AUR build summary..."
    
    echo
    echo "=== AUR Package Build Summary ==="
    echo "Version: $version"
    echo "PKGBUILD: Ready for AUR submission"
    echo "Source: cloudtolocalllm-$version.tar.gz"
    echo
    echo "Next steps for AUR submission:"
    echo "1. Update AUR repository with new PKGBUILD"
    echo "2. Test installation: makepkg -si"
    echo "3. Submit to AUR"
    echo
}

# Main execution function
main() {
    local version
    
    log_info "Starting CloudToLocalLLM AUR package build process..."
    
    # Get version information
    version=$(get_version)
    local build_number=$(get_build_number)
    
    log_info "Building version: $version"
    
    # Execute build steps
    check_arch_linux
    check_dependencies
    create_pkgbuild "$version" "$build_number"
    build_aur_package "$version"
    generate_source_tarball "$version"
    cleanup_build_artifacts
    generate_summary "$version"
    
    log_success "AUR package build completed successfully!"
    log_info "Package location: $DIST_DIR/"
}

# Handle command line arguments
case "${1:-}" in
    "--help"|"-h")
        echo "CloudToLocalLLM AUR Package Build Script"
        echo
        echo "Usage: $0 [options]"
        echo
        echo "Options:"
        echo "  --help, -h    Show this help message"
        echo
        echo "This script builds an AUR package for CloudToLocalLLM."
        echo "Must be run on Arch Linux with makepkg available."
        echo "The version is automatically extracted from pubspec.yaml."
        exit 0
        ;;
    "")
        main
        ;;
    *)
        log_error "Unknown option: $1"
        echo "Use '$0 --help' for usage information"
        exit 1
        ;;
esac
