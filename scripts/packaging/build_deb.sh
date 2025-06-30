#!/bin/bash
set -e

# CloudToLocalLLM Debian Package Builder
# Builds .deb packages for Linux distribution
# Version: 1.0.0

# Script configuration
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
    echo -e "${BLUE}[$(date '+%H:%M:%S')] [DEB-BUILD]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[$(date '+%H:%M:%S')] [DEB-BUILD]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[$(date '+%H:%M:%S')] [DEB-BUILD]${NC} $1"
}

log_error() {
    echo -e "${RED}[$(date '+%H:%M:%S')] [DEB-BUILD]${NC} $1"
}

# Function to get version from pubspec.yaml
get_version() {
    grep 'version:' "$PROJECT_ROOT/pubspec.yaml" | awk '{print $2}'
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites for Debian package build..."

    # Check if we're in the project root
    if [[ ! -f "$PROJECT_ROOT/pubspec.yaml" ]]; then
        log_error "pubspec.yaml not found. Please run from project root."
        exit 1
    fi

    # Check if Flutter Linux build exists
    if [[ ! -f "$PROJECT_ROOT/build/linux/x64/release/bundle/cloudtolocalllm" ]]; then
        log_error "Flutter Linux build not found. Please run 'flutter build linux --release' first."
        log_error "Expected: $PROJECT_ROOT/build/linux/x64/release/bundle/cloudtolocalllm"
        exit 1
    fi

    # Check if debian package structure exists
    if [[ ! -d "$PROJECT_ROOT/packaging/deb" ]]; then
        log_error "Debian package structure not found at $PROJECT_ROOT/packaging/deb"
        exit 1
    fi

    # Check required tools
    if ! command -v dpkg-deb &> /dev/null; then
        log_error "dpkg-deb not found. Please install dpkg-dev package."
        exit 1
    fi

    log_success "All prerequisites satisfied"
}

# Variables
VERSION=$(get_version)
DEB_VERSION=$(echo $VERSION | cut -d '+' -f 1)
BUILD_NUMBER=$(echo $VERSION | cut -d '+' -f 2)
PACKAGE_NAME="cloudtolocalllm-${DEB_VERSION}-amd64.deb"
BUILD_DIR="/tmp/cloudtolocalllm-deb-build"
OUTPUT_DIR="$PROJECT_ROOT/dist/linux"
OUTPUT_PATH="$OUTPUT_DIR/$PACKAGE_NAME"

# Create output directory
create_build_environment() {
    log_info "Creating build environment..."

    mkdir -p "$OUTPUT_DIR"

    # Create temporary build directory
    rm -rf "$BUILD_DIR"
    mkdir -p "$BUILD_DIR"

    log_success "Created build directory: $BUILD_DIR"
}

# Copy package structure and Flutter build
copy_package_files() {
    log_info "Copying debian package structure..."

    # Copy debian package structure
    cp -r "$PROJECT_ROOT/packaging/deb/"* "$BUILD_DIR/"
    log_success "Copied debian package structure"

    # Create required directories
    mkdir -p "$BUILD_DIR/usr/bin"
    mkdir -p "$BUILD_DIR/usr/lib/cloudtolocalllm"
    mkdir -p "$BUILD_DIR/usr/share/pixmaps"
    mkdir -p "$BUILD_DIR/usr/share/applications"

    log_info "Copying Flutter Linux build artifacts..."

    # Copy Flutter Linux build to package structure
    cp "$PROJECT_ROOT/build/linux/x64/release/bundle/cloudtolocalllm" "$BUILD_DIR/usr/lib/cloudtolocalllm/"
    cp -r "$PROJECT_ROOT/build/linux/x64/release/bundle/data" "$BUILD_DIR/usr/lib/cloudtolocalllm/"
    cp -r "$PROJECT_ROOT/build/linux/x64/release/bundle/lib" "$BUILD_DIR/usr/lib/cloudtolocalllm/"

    # Create wrapper script
    cat > "$BUILD_DIR/usr/bin/cloudtolocalllm" << 'EOF'
#!/bin/bash
cd /usr/lib/cloudtolocalllm
exec ./cloudtolocalllm "$@"
EOF

    log_success "Copied Flutter build files and created wrapper script"
}

# Copy additional assets
copy_assets() {
    log_info "Copying application assets..."

    # Copy icon
    if [[ -f "$PROJECT_ROOT/assets/icons/app_icon.png" ]]; then
        cp "$PROJECT_ROOT/assets/icons/app_icon.png" "$BUILD_DIR/usr/share/pixmaps/cloudtolocalllm.png"
        log_success "Copied app icon from assets/icons/"
    elif [[ -f "$PROJECT_ROOT/assets/images/icon.png" ]]; then
        cp "$PROJECT_ROOT/assets/images/icon.png" "$BUILD_DIR/usr/share/pixmaps/cloudtolocalllm.png"
        log_success "Copied app icon from assets/images/"
    elif [[ -f "$PROJECT_ROOT/linux/cloudtolocalllm.png" ]]; then
        cp "$PROJECT_ROOT/linux/cloudtolocalllm.png" "$BUILD_DIR/usr/share/pixmaps/cloudtolocalllm.png"
        log_success "Copied linux icon"
    else
        log_warning "No app icon found, package will use default icon"
    fi

    # Copy desktop file if it exists
    if [[ -f "$PROJECT_ROOT/assets/linux/cloudtolocalllm.desktop" ]]; then
        cp "$PROJECT_ROOT/assets/linux/cloudtolocalllm.desktop" "$BUILD_DIR/usr/share/applications/"
        log_success "Copied desktop file"
    fi
}

# Update package metadata
update_package_metadata() {
    log_info "Updating package metadata..."

    # Calculate installed size
    INSTALLED_SIZE=$(du -sk "$BUILD_DIR" | cut -f1)

    # Update control file
    sed -i "s/Version: .*/Version: $DEB_VERSION/" "$BUILD_DIR/DEBIAN/control"
    sed -i "s/Installed-Size: .*/Installed-Size: $INSTALLED_SIZE/" "$BUILD_DIR/DEBIAN/control"

    log_success "Updated control file with version $DEB_VERSION and size $INSTALLED_SIZE KB"
}

# Set file permissions
set_permissions() {
    log_info "Setting file permissions..."

    # Set DEBIAN script permissions
    chmod 755 "$BUILD_DIR/DEBIAN/postinst" 2>/dev/null || true
    chmod 755 "$BUILD_DIR/DEBIAN/postrm" 2>/dev/null || true

    # Set application permissions
    chmod 755 "$BUILD_DIR/usr/bin/cloudtolocalllm"
    chmod 755 "$BUILD_DIR/usr/lib/cloudtolocalllm/cloudtolocalllm"

    # Set data and lib permissions
    find "$BUILD_DIR/usr/lib/cloudtolocalllm/data" -type f -exec chmod 644 {} \; 2>/dev/null || true
    find "$BUILD_DIR/usr/lib/cloudtolocalllm/data" -type d -exec chmod 755 {} \; 2>/dev/null || true
    find "$BUILD_DIR/usr/lib/cloudtolocalllm/lib" -type f -exec chmod 644 {} \; 2>/dev/null || true
    find "$BUILD_DIR/usr/lib/cloudtolocalllm/lib" -type d -exec chmod 755 {} \; 2>/dev/null || true

    # Set icon and desktop file permissions
    chmod 644 "$BUILD_DIR/usr/share/pixmaps/cloudtolocalllm.png" 2>/dev/null || true
    chmod 644 "$BUILD_DIR/usr/share/applications/cloudtolocalllm.desktop" 2>/dev/null || true

    log_success "Set correct permissions"
}

# Build the DEB package
build_deb_package() {
    log_info "Building DEB package..."

    # Build the package
    if dpkg-deb --build "$BUILD_DIR" "$OUTPUT_PATH"; then
        log_success "DEB package built successfully"
    else
        log_error "Failed to build DEB package"
        exit 1
    fi
}

# Generate checksums
generate_checksums() {
    log_info "Generating SHA256 checksum..."

    cd "$OUTPUT_DIR"
    sha256sum "$(basename "$OUTPUT_PATH")" > "$(basename "$OUTPUT_PATH").sha256"

    log_success "Generated SHA256 checksum: $(basename "$OUTPUT_PATH").sha256"
}

# Validate the package
validate_package() {
    log_info "Validating DEB package..."

    if [[ -f "$OUTPUT_PATH" ]]; then
        local package_size=$(du -h "$OUTPUT_PATH" | cut -f1)
        log_success "DEB package created successfully: $(basename "$OUTPUT_PATH")"
        log_info "Package size: $package_size"
        log_info "Package location: $OUTPUT_PATH"

        # Run lintian for package validation if available
        if command -v lintian &> /dev/null; then
            log_info "Running lintian validation..."
            if lintian "$OUTPUT_PATH" 2>&1 | tee /tmp/lintian_output.txt; then
                log_success "Lintian validation passed"
            else
                log_warning "Lintian validation found issues:"
                cat /tmp/lintian_output.txt
                log_warning "Package created but has lintian warnings/errors"
            fi
        else
            log_warning "Lintian not available, skipping validation"
        fi
    else
        log_error "Failed to create DEB package"
        exit 1
    fi
}

# Cleanup build artifacts
cleanup_build() {
    log_info "Cleaning up build artifacts..."

    rm -rf "$BUILD_DIR"
    rm -f /tmp/lintian_output.txt 2>/dev/null || true

    log_success "Cleanup completed"
}

# Main execution function
main() {
    log_info "Starting CloudToLocalLLM Debian package build..."
    log_info "Version: $VERSION"
    log_info "Package: $PACKAGE_NAME"

    check_prerequisites
    create_build_environment
    copy_package_files
    copy_assets
    update_package_metadata
    set_permissions
    build_deb_package
    generate_checksums
    validate_package
    cleanup_build

    log_success "Debian package build completed successfully!"
    log_info "Package: $OUTPUT_PATH"
    log_info "Checksum: $OUTPUT_PATH.sha256"
}

# Execute main function
main "$@"
