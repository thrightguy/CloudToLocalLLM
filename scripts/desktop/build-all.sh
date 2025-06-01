#!/bin/bash

# Master build script for CloudToLocalLLM Desktop Bridge
# This script builds the application and creates all Linux packages

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

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

# Show usage
show_usage() {
    cat << EOF
CloudToLocalLLM Desktop Bridge Build Script

Usage: $0 [options]

Options:
  --build-only      Build application only (no packages)
  --deb-only        Build Debian package only
  --appimage-only   Build AppImage only
  --aur-only        Prepare AUR package only
  --clean           Clean build directories before building
  --help            Show this help message

Examples:
  $0                    # Build everything
  $0 --build-only       # Build application only
  $0 --deb-only         # Build Debian package only
  $0 --clean            # Clean and build everything

EOF
}

# Parse command line arguments
BUILD_ONLY=false
DEB_ONLY=false
APPIMAGE_ONLY=false
AUR_ONLY=false
CLEAN=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --build-only)
            BUILD_ONLY=true
            shift
            ;;
        --deb-only)
            DEB_ONLY=true
            shift
            ;;
        --appimage-only)
            APPIMAGE_ONLY=true
            shift
            ;;
        --aur-only)
            AUR_ONLY=true
            shift
            ;;
        --clean)
            CLEAN=true
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

# Clean build directories if requested
clean_build_dirs() {
    if [ "$CLEAN" = true ]; then
        log_info "Cleaning build directories..."
        rm -rf "$PROJECT_ROOT/build"
        rm -rf "$PROJECT_ROOT/dist"
        rm -rf "$PROJECT_ROOT/tools"
        log_success "Build directories cleaned"
    fi
}

# Check system requirements
check_requirements() {
    log_info "Checking system requirements..."
    
    # Check for required tools
    local missing_tools=()
    
    if ! command -v go &> /dev/null; then
        missing_tools+=("go")
    fi
    
    if ! command -v git &> /dev/null; then
        missing_tools+=("git")
    fi
    
    if [ ${#missing_tools[@]} -gt 0 ]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        log_error "Please install the missing tools and try again."
        exit 1
    fi
    
    # Check for optional tools
    local optional_tools=()
    
    if ! command -v dpkg-deb &> /dev/null; then
        optional_tools+=("dpkg-deb (for Debian packages)")
    fi
    
    if ! command -v wget &> /dev/null; then
        optional_tools+=("wget (for AppImage tools)")
    fi
    
    if ! command -v convert &> /dev/null; then
        optional_tools+=("imagemagick (for icon conversion)")
    fi
    
    if [ ${#optional_tools[@]} -gt 0 ]; then
        log_warning "Optional tools not found: ${optional_tools[*]}"
        log_warning "Some features may not be available."
    fi
    
    log_success "System requirements check completed"
}

# Build the application
build_application() {
    log_info "Building CloudToLocalLLM Desktop Bridge..."
    
    if ! "$SCRIPT_DIR/build-bridge.sh"; then
        log_error "Application build failed"
        exit 1
    fi
    
    log_success "Application build completed"
}

# Create Debian package
create_deb_package() {
    log_info "Creating Debian package..."
    
    if ! "$SCRIPT_DIR/package-deb.sh"; then
        log_error "Debian package creation failed"
        exit 1
    fi
    
    log_success "Debian package created"
}

# Create AppImage
create_appimage() {
    log_info "Creating AppImage..."
    
    if ! "$SCRIPT_DIR/package-appimage.sh"; then
        log_error "AppImage creation failed"
        exit 1
    fi
    
    log_success "AppImage created"
}

# Prepare AUR package
prepare_aur_package() {
    log_info "Preparing AUR package..."
    
    # Copy AUR files to dist directory
    mkdir -p "$PROJECT_ROOT/dist/aur"
    cp "$PROJECT_ROOT/packaging/linux/aur/PKGBUILD" "$PROJECT_ROOT/dist/aur/"
    cp "$PROJECT_ROOT/packaging/linux/aur/.SRCINFO" "$PROJECT_ROOT/dist/aur/"
    
    # Create AUR package info
    cat > "$PROJECT_ROOT/dist/aur/README.md" << 'EOF'
# CloudToLocalLLM Bridge AUR Package

This directory contains the files needed to create an AUR (Arch User Repository) package for CloudToLocalLLM Bridge.

## Files

- `PKGBUILD`: The main package build script
- `.SRCINFO`: Package metadata for AUR
- `README.md`: This file

## Installation from AUR

Once this package is published to AUR, users can install it using an AUR helper:

```bash
# Using yay
yay -S cloudtolocalllm-bridge

# Using paru
paru -S cloudtolocalllm-bridge

# Manual installation
git clone https://aur.archlinux.org/cloudtolocalllm-bridge.git
cd cloudtolocalllm-bridge
makepkg -si
```

## Publishing to AUR

To publish this package to AUR:

1. Create an account on https://aur.archlinux.org/
2. Upload your SSH public key
3. Clone the AUR repository:
   ```bash
   git clone ssh://aur@aur.archlinux.org/cloudtolocalllm-bridge.git
   ```
4. Copy the PKGBUILD and .SRCINFO files
5. Update the sha256sums in PKGBUILD with actual checksums
6. Commit and push:
   ```bash
   git add PKGBUILD .SRCINFO
   git commit -m "Initial import of cloudtolocalllm-bridge"
   git push
   ```

## Updating the Package

When releasing a new version:

1. Update `pkgver` in PKGBUILD
2. Update the source URL
3. Update sha256sums
4. Regenerate .SRCINFO: `makepkg --printsrcinfo > .SRCINFO`
5. Commit and push changes

For more information, see: https://wiki.archlinux.org/title/AUR_submission_guidelines
EOF
    
    log_success "AUR package prepared in $PROJECT_ROOT/dist/aur/"
}

# Show build summary
show_summary() {
    log_info "Build Summary"
    log_info "============="
    
    # Check what was built
    if [ -f "$PROJECT_ROOT/build/desktop-bridge/cloudtolocalllm-bridge" ]; then
        log_success "✓ Application binary built"
    fi
    
    if [ -f "$PROJECT_ROOT/dist/cloudtolocalllm-bridge_1.0.0_amd64.deb" ]; then
        log_success "✓ Debian package created"
        log_info "  File: $PROJECT_ROOT/dist/cloudtolocalllm-bridge_1.0.0_amd64.deb"
    fi
    
    if [ -f "$PROJECT_ROOT/dist/CloudToLocalLLM-Bridge-1.0.0-x86_64.AppImage" ]; then
        log_success "✓ AppImage created"
        log_info "  File: $PROJECT_ROOT/dist/CloudToLocalLLM-Bridge-1.0.0-x86_64.AppImage"
    fi
    
    if [ -d "$PROJECT_ROOT/dist/aur" ]; then
        log_success "✓ AUR package prepared"
        log_info "  Directory: $PROJECT_ROOT/dist/aur/"
    fi
    
    echo ""
    log_info "Installation Instructions:"
    echo ""
    
    if [ -f "$PROJECT_ROOT/dist/cloudtolocalllm-bridge_1.0.0_amd64.deb" ]; then
        log_info "Debian/Ubuntu:"
        echo "  sudo dpkg -i $PROJECT_ROOT/dist/cloudtolocalllm-bridge_1.0.0_amd64.deb"
        echo "  sudo apt-get install -f  # Fix dependencies if needed"
        echo ""
    fi
    
    if [ -f "$PROJECT_ROOT/dist/CloudToLocalLLM-Bridge-1.0.0-x86_64.AppImage" ]; then
        log_info "Universal Linux (AppImage):"
        echo "  chmod +x $PROJECT_ROOT/dist/CloudToLocalLLM-Bridge-1.0.0-x86_64.AppImage"
        echo "  $PROJECT_ROOT/dist/CloudToLocalLLM-Bridge-1.0.0-x86_64.AppImage"
        echo ""
    fi
    
    if [ -d "$PROJECT_ROOT/dist/aur" ]; then
        log_info "Arch Linux (AUR):"
        echo "  cd $PROJECT_ROOT/dist/aur"
        echo "  makepkg -si"
        echo ""
    fi
    
    log_info "For more information, visit: https://cloudtolocalllm.online"
}

# Main build process
main() {
    log_info "CloudToLocalLLM Desktop Bridge Build System"
    log_info "==========================================="
    
    clean_build_dirs
    check_requirements
    
    # Build application (always required)
    build_application
    
    # Handle specific build modes
    if [ "$BUILD_ONLY" = true ]; then
        log_success "Build completed (application only)"
        return
    fi
    
    if [ "$DEB_ONLY" = true ]; then
        create_deb_package
    elif [ "$APPIMAGE_ONLY" = true ]; then
        create_appimage
    elif [ "$AUR_ONLY" = true ]; then
        prepare_aur_package
    else
        # Build all packages
        create_deb_package
        create_appimage
        prepare_aur_package
    fi
    
    show_summary
    log_success "All builds completed successfully!"
}

# Make scripts executable
chmod +x "$SCRIPT_DIR"/*.sh

# Run main function
main "$@"
