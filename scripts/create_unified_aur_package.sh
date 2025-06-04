#!/bin/bash

# CloudToLocalLLM Unified AUR Binary Package Creator
# Creates a binary package from the unified Flutter build output
# No separate tray daemon - everything is integrated into the main application

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
VERSION="3.0.2"  # Security Fixes + Docker Non-Root User Implementation
BUILD_DIR="$PROJECT_ROOT/build/linux/x64/release/bundle"
OUTPUT_DIR="$PROJECT_ROOT/dist"
PACKAGE_NAME="cloudtolocalllm-$VERSION-x86_64"
PACKAGE_DIR="$OUTPUT_DIR/$PACKAGE_NAME"

# Logging functions
log() {
    echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[$(date '+%H:%M:%S')] ✅${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[$(date '+%H:%M:%S')] ⚠️${NC} $1"
}

log_error() {
    echo -e "${RED}[$(date '+%H:%M:%S')] ❌${NC} $1"
}

# Header
echo -e "${BLUE}CloudToLocalLLM Unified AUR Binary Package Creator${NC}"
echo -e "${BLUE}===================================================${NC}"
echo "Version: $VERSION"
echo "Output: $OUTPUT_DIR/$PACKAGE_NAME.tar.gz"
echo ""

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    if [[ ! -d "$BUILD_DIR" ]]; then
        log_error "Flutter build directory not found: $BUILD_DIR"
        log_error "Please run 'flutter build linux --release' first"
        exit 1
    fi
    
    if [[ ! -f "$BUILD_DIR/cloudtolocalllm" ]]; then
        log_error "Main executable not found: $BUILD_DIR/cloudtolocalllm"
        exit 1
    fi
    
    # Check required tools
    for tool in tar gzip sha256sum; do
        if ! command -v "$tool" &> /dev/null; then
            log_error "Required tool not found: $tool"
            exit 1
        fi
    done
    
    log_success "Prerequisites check passed"
}

# Create package structure
create_package_structure() {
    log "Creating package structure..."
    
    # Clean and create package directory
    rm -rf "$PACKAGE_DIR"
    mkdir -p "$PACKAGE_DIR"
    mkdir -p "$OUTPUT_DIR"
    
    log_success "Package structure created"
}

# Copy Flutter application
copy_flutter_app() {
    log "Copying unified Flutter application..."
    
    # Copy the entire Flutter bundle
    cp -r "$BUILD_DIR"/* "$PACKAGE_DIR/"
    
    # Ensure main executable is executable
    chmod +x "$PACKAGE_DIR/cloudtolocalllm"
    
    # Verify the copy
    if [[ ! -f "$PACKAGE_DIR/cloudtolocalllm" ]]; then
        log_error "Failed to copy main executable"
        exit 1
    fi
    
    # Check for essential directories
    for dir in data lib; do
        if [[ -d "$BUILD_DIR/$dir" && ! -d "$PACKAGE_DIR/$dir" ]]; then
            log_error "Failed to copy essential directory: $dir"
            exit 1
        fi
    done
    
    log_success "Flutter application copied successfully"
}

# Add metadata and documentation
add_metadata() {
    log "Adding package metadata..."
    
    # Create package info file
    cat > "$PACKAGE_DIR/PACKAGE_INFO.txt" << EOF
CloudToLocalLLM v$VERSION
========================

Package Type: Unified Binary Package for AUR
Architecture: x86_64
Build Date: $(date '+%Y-%m-%d %H:%M:%S')

Contents:
- Main Flutter application (cloudtolocalllm)
- Integrated system tray functionality
- All required libraries and data files
- Unified architecture with no separate components

Installation:
This package is designed for AUR (Arch User Repository) installation.
Use: yay -S cloudtolocalllm

Security Features:
- Docker containers run as non-root users
- Enhanced permission handling
- Secure authentication flow

For more information, visit:
https://github.com/imrightguy/CloudToLocalLLM
EOF
    
    # Add version file for runtime detection
    echo "$VERSION" > "$PACKAGE_DIR/VERSION"
    
    log_success "Metadata added"
}

# Create archive
create_archive() {
    log "Creating compressed archive..."
    
    cd "$OUTPUT_DIR"
    
    # Create tar.gz archive
    tar -czf "$PACKAGE_NAME.tar.gz" "$PACKAGE_NAME/"
    
    if [[ ! -f "$PACKAGE_NAME.tar.gz" ]]; then
        log_error "Failed to create archive"
        exit 1
    fi
    
    # Get archive size
    local size=$(du -h "$PACKAGE_NAME.tar.gz" | cut -f1)
    log_success "Archive created: $PACKAGE_NAME.tar.gz ($size)"
}

# Generate checksums
generate_checksums() {
    log "Generating checksums..."
    
    cd "$OUTPUT_DIR"
    
    # Generate SHA256 checksum
    sha256sum "$PACKAGE_NAME.tar.gz" > "$PACKAGE_NAME.tar.gz.sha256"
    
    local checksum=$(cut -d' ' -f1 "$PACKAGE_NAME.tar.gz.sha256")
    log_success "SHA256: $checksum"
    
    # Create checksum info for AUR PKGBUILD
    cat > "$PACKAGE_NAME-aur-info.txt" << EOF
# AUR PKGBUILD Information for CloudToLocalLLM v$VERSION

# Update these values in aur-package/PKGBUILD:
pkgver=$VERSION
sha256sums=('SKIP' '$checksum')

# SourceForge download URL:
source=(
    "https://github.com/imrightguy/CloudToLocalLLM/archive/v\$pkgver.tar.gz"
    "https://sourceforge.net/projects/cloudtolocalllm/files/releases/v\${pkgver}/cloudtolocalllm-\${pkgver}-x86_64.tar.gz"
)
EOF
    
    log_success "Checksums and AUR info generated"
}

# Test package integrity
test_package() {
    log "Testing package integrity..."
    
    cd "$OUTPUT_DIR"
    
    # Create temporary test directory
    local test_dir="test_$PACKAGE_NAME"
    rm -rf "$test_dir"
    mkdir "$test_dir"
    
    # Extract and test
    tar -xzf "$PACKAGE_NAME.tar.gz" -C "$test_dir"
    
    if [[ -f "$test_dir/$PACKAGE_NAME/cloudtolocalllm" ]]; then
        log_success "Package integrity test passed"
    else
        log_error "Package integrity test failed"
        exit 1
    fi
    
    # Cleanup test directory
    rm -rf "$test_dir"
}

# Display package information
display_package_info() {
    cd "$OUTPUT_DIR"
    
    local size=$(du -h "$PACKAGE_NAME.tar.gz" | cut -f1)
    local checksum=$(cut -d' ' -f1 "$PACKAGE_NAME.tar.gz.sha256")
    
    echo ""
    echo -e "${GREEN}📦 Package Information${NC}"
    echo -e "${GREEN}======================${NC}"
    echo "Package: $PACKAGE_NAME.tar.gz"
    echo "Size: $size"
    echo "SHA256: $checksum"
    echo ""
    echo -e "${BLUE}📁 Files created:${NC}"
    echo "  • $OUTPUT_DIR/$PACKAGE_NAME.tar.gz"
    echo "  • $OUTPUT_DIR/$PACKAGE_NAME.tar.gz.sha256"
    echo "  • $OUTPUT_DIR/$PACKAGE_NAME-aur-info.txt"
    echo ""
    echo -e "${YELLOW}📋 Next steps:${NC}"
    echo "  1. Upload to SourceForge: scripts/upload_to_sourceforge.sh"
    echo "  2. Update AUR PKGBUILD with new checksum"
    echo "  3. Test AUR package build"
    echo "  4. Submit to AUR"
}

# Cleanup
cleanup() {
    log "Cleaning up temporary files..."
    rm -rf "$PACKAGE_DIR"
    log_success "Cleanup completed"
}

# Main execution
main() {
    check_prerequisites
    create_package_structure
    copy_flutter_app
    add_metadata
    create_archive
    generate_checksums
    test_package
    display_package_info
    cleanup
    
    echo ""
    log_success "🎉 Unified AUR binary package created successfully!"
    echo -e "${GREEN}📦 Ready for SourceForge upload and AUR deployment${NC}"
}

# Error handling
trap 'log_error "Script failed at line $LINENO. Check logs above for details."' ERR

# Execute main function
main "$@"
