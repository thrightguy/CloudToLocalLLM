#!/bin/bash

# CloudToLocalLLM Unified Package Creator v3.4.0+
# Creates a unified package for static download distribution
# Single Flutter application with integrated system tray - no Python dependencies

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

# Get version from pubspec.yaml dynamically
VERSION=$(grep '^version:' "$PROJECT_ROOT/pubspec.yaml" | sed 's/version: *\([0-9.]*\).*/\1/')
if [[ -z "$VERSION" ]]; then
    echo "Error: Could not extract version from pubspec.yaml"
    exit 1
fi
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
echo -e "${BLUE}CloudToLocalLLM Unified Package Creator${NC}"
echo -e "${BLUE}=======================================${NC}"
echo "Version: $VERSION"
echo "Distribution: Static Download"
echo "Output: $OUTPUT_DIR/$PACKAGE_NAME.tar.gz"
echo ""

# Build unified Flutter application
build_flutter_app() {
    log "Building unified Flutter application..."

    cd "$PROJECT_ROOT"

    log "  Running flutter pub get..."
    if ! flutter pub get; then
        log_error "Failed to get dependencies for Flutter app"
        exit 1
    fi

    log "  Running flutter build linux --release..."
    if ! flutter build linux --release; then
        log_error "Failed to build Flutter app"
        exit 1
    fi

    if [[ ! -f "build/linux/x64/release/bundle/cloudtolocalllm" ]]; then
        log_error "Flutter app executable not found after build"
        exit 1
    fi

    log_success "Unified Flutter application built successfully"
}

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."

    # Check Flutter
    if ! command -v flutter &> /dev/null; then
        log_error "Flutter is not installed or not in PATH"
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

# Copy unified Flutter application
copy_flutter_app() {
    log "Copying unified Flutter application..."

    # Copy Flutter application with complete bundle structure
    if [[ -d "$PROJECT_ROOT/build/linux/x64/release/bundle" ]]; then
        log "Copying Flutter application bundle..."
        cp -r "$PROJECT_ROOT/build/linux/x64/release/bundle"/* "$PACKAGE_DIR/"
        chmod +x "$PACKAGE_DIR/cloudtolocalllm"
        log "  Application libraries: $(ls -1 "$PROJECT_ROOT/build/linux/x64/release/bundle/lib" | wc -l) files"
    else
        log_error "Flutter build bundle not found"
        exit 1
    fi

    # Verify essential files and libraries
    if [[ ! -f "$PACKAGE_DIR/cloudtolocalllm" ]]; then
        log_error "Failed to copy main executable"
        exit 1
    fi

    # Verify all required Flutter plugin libraries are present
    local required_libs=("libwindow_manager_plugin.so" "libflutter_secure_storage_linux_plugin.so" "liburl_launcher_linux_plugin.so" "libtray_manager_plugin.so")
    for lib in "${required_libs[@]}"; do
        if [[ ! -f "$PACKAGE_DIR/lib/$lib" ]]; then
            log_warning "Optional library missing: $lib (may not be required for all features)"
        else
            log "  ✅ Required library present: $lib"
        fi
    done

    # Verify AOT data (libapp.so) is present
    if [[ -f "$PACKAGE_DIR/lib/libapp.so" ]]; then
        log "  ✅ AOT data present: libapp.so"
    else
        log_error "AOT data missing: libapp.so"
        exit 1
    fi

    log "  Total libraries: $(ls -1 "$PACKAGE_DIR/lib" | wc -l) files"
    log_success "Unified Flutter application copied successfully with proper bundle structure"
}

# Add metadata and documentation
add_metadata() {
    log "Adding package metadata..."
    
    # Create package info file
    cat > "$PACKAGE_DIR/PACKAGE_INFO.txt" << EOF
CloudToLocalLLM v$VERSION
========================

Package Type: Unified Binary Package for Static Distribution
Architecture: x86_64
Build Date: $(date '+%Y-%m-%d %H:%M:%S')

Contents:
- Unified Flutter application (cloudtolocalllm)
- Integrated system tray functionality using tray_manager
- Integrated tunnel manager for connection brokering
- All required libraries and data files
- Single executable with no Python dependencies

Installation:
This package is designed for static download distribution.
Download from: https://cloudtolocalllm.online/download/

AUR Installation:
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
    
    # Create checksum info for AUR PKGBUILD (static distribution)
    cat > "$PACKAGE_NAME-aur-info.txt" << EOF
# AUR PKGBUILD Information for CloudToLocalLLM v$VERSION
# Static Distribution Configuration

# Update these values in aur-package/PKGBUILD:
pkgver=$VERSION
sha256sums=('SKIP' '$checksum')

# Static download URL:
source=(
    "https://github.com/imrightguy/CloudToLocalLLM/archive/v\$pkgver.tar.gz"
    "https://cloudtolocalllm.online/cloudtolocalllm-\${pkgver}-x86_64.tar.gz"
)

# Deployment workflow for static distribution:
# 1. Upload cloudtolocalllm-$VERSION-x86_64.tar.gz to https://cloudtolocalllm.online/
# 2. Update aur-package/PKGBUILD with new version and checksum
# 3. Test AUR package build locally
# 4. Submit updated PKGBUILD to AUR
# 5. Deploy web app to VPS
EOF
    
    log_success "Checksums and AUR info generated for static distribution"
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
    echo -e "${YELLOW}📋 Next steps for static distribution:${NC}"
    echo "  1. Upload package to https://cloudtolocalllm.online/download/"
    echo "  2. Update aur-package/PKGBUILD with new version and checksum"
    echo "  3. Test AUR package build locally"
    echo "  4. Submit updated PKGBUILD to AUR"
    echo "  5. Deploy web app to VPS"
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
    build_flutter_app
    create_package_structure
    copy_flutter_app
    add_metadata
    create_archive
    generate_checksums
    test_package
    display_package_info
    cleanup

    echo ""
    log_success "🎉 Unified package created successfully for static distribution!"
    echo -e "${GREEN}📦 Ready for static download deployment and AUR update${NC}"
}

# Error handling
trap 'log_error "Script failed at line $LINENO. Check logs above for details."' ERR

# Execute main function
main "$@"
