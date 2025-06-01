#!/bin/bash

# CloudToLocalLLM Debian Package Build Script
# Creates .deb packages for Ubuntu, Debian, and derivatives
# Uses Docker for consistent build environment

set -e  # Exit on any error

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
BUILD_DIR="$PROJECT_ROOT/build/debian"
DIST_DIR="$PROJECT_ROOT/dist/debian"
DOCKER_DIR="$PROJECT_ROOT/docker/debian-builder"

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

# Check if Docker is available
check_docker() {
    if ! command -v docker &> /dev/null; then
        log_error "Docker is required for Debian package building"
        log_info "Install Docker: https://docs.docker.com/get-docker/"
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        log_error "Docker daemon is not running or not accessible"
        log_info "Start Docker daemon or add user to docker group"
        exit 1
    fi
    
    log_success "Docker is available and running"
}

# Create Docker build environment
create_docker_environment() {
    log_info "Creating Docker build environment..."
    
    mkdir -p "$DOCKER_DIR"
    
    # Create Dockerfile for Debian builder
    cat > "$DOCKER_DIR/Dockerfile" << 'EOF'
FROM ubuntu:22.04

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install build dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    dpkg-dev \
    fakeroot \
    lintian \
    curl \
    git \
    unzip \
    xz-utils \
    zip \
    libgtk-3-dev \
    libayatana-appindicator3-dev \
    pkg-config \
    cmake \
    ninja-build \
    clang \
    && rm -rf /var/lib/apt/lists/*

# Install Flutter
RUN git clone https://github.com/flutter/flutter.git -b stable /opt/flutter
ENV PATH="/opt/flutter/bin:${PATH}"

# Pre-download Flutter dependencies
RUN flutter doctor
RUN flutter precache --linux

# Create non-root user for building
RUN useradd -m -s /bin/bash builder

# Give builder user ownership of Flutter directory
RUN chown -R builder:builder /opt/flutter

USER builder
WORKDIR /workspace

# Set Flutter path for builder user
ENV PATH="/opt/flutter/bin:${PATH}"

CMD ["/bin/bash"]
EOF
    
    log_success "Docker build environment created"
}

# Build Docker image
build_docker_image() {
    log_info "Building Docker image for Debian packaging..."
    
    cd "$DOCKER_DIR"
    docker build -t cloudtolocalllm-debian-builder .
    
    log_success "Docker image built successfully"
}

# Create DEBIAN control files
create_control_files() {
    log_info "Creating DEBIAN control files..."
    
    local version="$1"
    local package_dir="$BUILD_DIR/package"
    local debian_dir="$package_dir/DEBIAN"
    
    mkdir -p "$debian_dir"
    
    # Create control file
    cat > "$debian_dir/control" << EOF
Package: cloudtolocalllm
Version: $version
Section: net
Priority: optional
Architecture: amd64
Depends: libayatana-appindicator3-1, libgtk-3-0, libc6 (>= 2.31), libgcc-s1 (>= 3.0)
Recommends: ollama
Suggests: firefox | chromium-browser
Installed-Size: $(du -sk "$package_dir/usr" 2>/dev/null | cut -f1 || echo "50000")
Maintainer: CloudToLocalLLM Team <support@cloudtolocalllm.online>
Description: Multi-tenant streaming LLM management application
 CloudToLocalLLM provides secure, scalable multi-tenant streaming
 for local LLM management with system tray integration.
 .
 Features include:
  - Multi-tenant streaming proxy architecture
  - System tray integration with minimize-to-tray
  - Cross-platform support (web and desktop)
  - Secure authentication and user isolation
  - Platform-specific connection logic (web proxy vs direct)
  - Professional "Coming Soon" placeholders for future features
Homepage: https://cloudtolocalllm.online
EOF
    
    # Create postinst script
    cat > "$debian_dir/postinst" << 'EOF'
#!/bin/bash
set -e

# Update icon cache
if command -v gtk-update-icon-cache >/dev/null 2>&1; then
    gtk-update-icon-cache -q -t -f /usr/share/icons/hicolor || true
fi

# Update desktop database
if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database -q /usr/share/applications || true
fi

echo "CloudToLocalLLM installed successfully!"
echo "Start from applications menu or run 'cloudtolocalllm' in terminal"

#DEBHELPER#

exit 0
EOF
    
    # Create prerm script
    cat > "$debian_dir/prerm" << 'EOF'
#!/bin/bash
set -e

echo "Removing CloudToLocalLLM..."

#DEBHELPER#

exit 0
EOF
    
    # Create postrm script
    cat > "$debian_dir/postrm" << 'EOF'
#!/bin/bash
set -e

case "$1" in
    remove|purge)
        # Update icon cache
        if command -v gtk-update-icon-cache >/dev/null 2>&1; then
            gtk-update-icon-cache -q -t -f /usr/share/icons/hicolor || true
        fi
        
        # Update desktop database
        if command -v update-desktop-database >/dev/null 2>&1; then
            update-desktop-database -q /usr/share/applications || true
        fi
        ;;
esac

#DEBHELPER#

exit 0
EOF
    
    # Make scripts executable
    chmod 755 "$debian_dir/postinst"
    chmod 755 "$debian_dir/prerm"
    chmod 755 "$debian_dir/postrm"
    
    log_success "DEBIAN control files created"
}

# Create desktop file
create_desktop_file() {
    log_info "Creating desktop file..."
    
    local version="$1"
    local package_dir="$BUILD_DIR/package"
    local desktop_dir="$package_dir/usr/share/applications"
    
    mkdir -p "$desktop_dir"
    
    cat > "$desktop_dir/cloudtolocalllm.desktop" << EOF
[Desktop Entry]
Name=CloudToLocalLLM
Comment=Multi-tenant streaming LLM management with system tray integration
Exec=cloudtolocalllm
Icon=cloudtolocalllm
Type=Application
Categories=Network;Development;
StartupNotify=true
StartupWMClass=cloudtolocalllm
Keywords=LLM;AI;Chat;Ollama;Streaming;Machine Learning;
Version=1.0
Terminal=false
MimeType=application/x-cloudtolocalllm;
EOF
    
    log_success "Desktop file created"
}

# Create man page
create_man_page() {
    log_info "Creating man page..."
    
    local version="$1"
    local package_dir="$BUILD_DIR/package"
    local man_dir="$package_dir/usr/share/man/man1"
    
    mkdir -p "$man_dir"
    
    cat > "$man_dir/cloudtolocalllm.1" << EOF
.TH CLOUDTOLOCALLLM 1 "$(date '+%B %Y')" "CloudToLocalLLM $version" "User Commands"
.SH NAME
cloudtolocalllm \- Multi-tenant streaming LLM management application
.SH SYNOPSIS
.B cloudtolocalllm
[\fIOPTIONS\fR]
.SH DESCRIPTION
CloudToLocalLLM provides secure, scalable multi-tenant streaming for local LLM management with system tray integration.
.PP
The application features a modern ChatGPT-like interface with platform-specific connection logic:
.IP \(bu 2
Web platform: Uses CloudToLocalLLM streaming proxy with authentication
.IP \(bu 2
Desktop platform: Direct connection to localhost Ollama instances
.PP
Key features include multi-tenant streaming proxy architecture, system tray integration with minimize-to-tray, cross-platform support, and secure authentication with user isolation.
.SH OPTIONS
.TP
.B \-h, \-\-help
Display help information and exit.
.TP
.B \-v, \-\-version
Display version information and exit.
.SH FILES
.TP
.I ~/.config/cloudtolocalllm/
User configuration directory
.TP
.I ~/.local/share/cloudtolocalllm/
User data directory
.SH EXAMPLES
.TP
Start CloudToLocalLLM:
.B cloudtolocalllm
.SH BUGS
Report bugs at: https://github.com/imrightguy/CloudToLocalLLM/issues
.SH AUTHOR
CloudToLocalLLM Team <support@cloudtolocalllm.online>
.SH SEE ALSO
.BR ollama (1)
EOF
    
    # Compress man page
    gzip -9 "$man_dir/cloudtolocalllm.1"

    log_success "Man page created and compressed"
}

# Build Flutter application in Docker
build_flutter_in_docker() {
    log_info "Building Flutter application in Docker container..."

    local version="$1"

    # Run Flutter build in Docker container
    docker run --rm \
        -v "$PROJECT_ROOT:/workspace" \
        -w /workspace \
        cloudtolocalllm-debian-builder \
        bash -c "
            set -e
            echo 'Setting up Git safe directories...'
            git config --global --add safe.directory /opt/flutter
            git config --global --add safe.directory /workspace

            echo 'Cleaning previous builds...'
            flutter clean

            echo 'Getting dependencies...'
            flutter pub get

            echo 'Building Flutter for Linux (initial build to generate plugin files)...'
            flutter build linux --release

            echo 'Applying tray manager fix...'
            if [[ -f scripts/fix_tray_manager_deprecation.sh ]]; then
                bash scripts/fix_tray_manager_deprecation.sh apply || echo 'Tray manager fix not needed or already applied'
            fi

            echo 'Rebuilding Flutter for Linux with fixes...'
            flutter build linux --release

            echo 'Flutter build completed successfully'
        "

    if [[ ! -d "$PROJECT_ROOT/build/linux/x64/release/bundle" ]]; then
        log_error "Flutter build failed - output directory not found"
        exit 1
    fi

    log_success "Flutter application built in Docker"
}

# Prepare package directory structure
prepare_package_structure() {
    log_info "Preparing package directory structure..."

    local package_dir="$BUILD_DIR/package"

    # Clean and create package directory
    rm -rf "$package_dir"
    mkdir -p "$package_dir"

    # Create directory structure
    mkdir -p "$package_dir/usr/bin"
    mkdir -p "$package_dir/usr/share/applications"
    mkdir -p "$package_dir/usr/share/icons/hicolor/16x16/apps"
    mkdir -p "$package_dir/usr/share/icons/hicolor/24x24/apps"
    mkdir -p "$package_dir/usr/share/icons/hicolor/32x32/apps"
    mkdir -p "$package_dir/usr/share/icons/hicolor/48x48/apps"
    mkdir -p "$package_dir/usr/share/icons/hicolor/64x64/apps"
    mkdir -p "$package_dir/usr/share/icons/hicolor/128x128/apps"
    mkdir -p "$package_dir/usr/share/icons/hicolor/256x256/apps"
    mkdir -p "$package_dir/usr/share/doc/cloudtolocalllm"
    mkdir -p "$package_dir/usr/share/licenses/cloudtolocalllm"
    mkdir -p "$package_dir/usr/share/man/man1"

    log_success "Package directory structure created"
}

# Copy application files
copy_application_files() {
    log_info "Copying application files..."

    local package_dir="$BUILD_DIR/package"
    local flutter_bundle="$PROJECT_ROOT/build/linux/x64/release/bundle"

    # Copy Flutter bundle
    cp -r "$flutter_bundle"/* "$package_dir/usr/bin/"

    # Ensure main executable is named correctly and executable
    if [[ -f "$package_dir/usr/bin/cloudtolocalllm" ]]; then
        chmod 755 "$package_dir/usr/bin/cloudtolocalllm"
    else
        log_error "Main executable not found in Flutter build"
        exit 1
    fi

    # Copy documentation
    if [[ -f "$PROJECT_ROOT/README.md" ]]; then
        cp "$PROJECT_ROOT/README.md" "$package_dir/usr/share/doc/cloudtolocalllm/"
    fi

    if [[ -f "$PROJECT_ROOT/CHANGELOG.md" ]]; then
        cp "$PROJECT_ROOT/CHANGELOG.md" "$package_dir/usr/share/doc/cloudtolocalllm/"
    fi

    if [[ -f "$PROJECT_ROOT/LICENSE" ]]; then
        cp "$PROJECT_ROOT/LICENSE" "$package_dir/usr/share/licenses/cloudtolocalllm/"
    fi

    # Create copyright file
    cat > "$package_dir/usr/share/doc/cloudtolocalllm/copyright" << EOF
Format: https://www.debian.org/doc/packaging-manuals/copyright-format/1.0/
Upstream-Name: CloudToLocalLLM
Upstream-Contact: CloudToLocalLLM Team <support@cloudtolocalllm.online>
Source: https://github.com/imrightguy/CloudToLocalLLM

Files: *
Copyright: $(date +%Y) CloudToLocalLLM Team
License: MIT
 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:
 .
 The above copyright notice and this permission notice shall be included in all
 copies or substantial portions of the Software.
 .
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 SOFTWARE.
EOF

    log_success "Application files copied"
}

# Copy and generate icons
copy_icons() {
    log_info "Copying and generating icons..."

    local package_dir="$BUILD_DIR/package"
    local assets_dir="$PROJECT_ROOT/assets/images"

    if [[ -f "$assets_dir/tray_icon_contrast_16.png" ]]; then
        # Copy existing monochrome tray icons
        cp "$assets_dir/tray_icon_contrast_16.png" "$package_dir/usr/share/icons/hicolor/16x16/apps/cloudtolocalllm.png"
        cp "$assets_dir/tray_icon_contrast_24.png" "$package_dir/usr/share/icons/hicolor/24x24/apps/cloudtolocalllm.png"
        cp "$assets_dir/tray_icon_contrast_32.png" "$package_dir/usr/share/icons/hicolor/32x32/apps/cloudtolocalllm.png"

        # Generate larger sizes if ImageMagick is available
        if command -v convert &> /dev/null; then
            log_info "Generating additional icon sizes..."
            convert "$assets_dir/tray_icon_contrast_32.png" -resize 48x48 "$package_dir/usr/share/icons/hicolor/48x48/apps/cloudtolocalllm.png"
            convert "$assets_dir/tray_icon_contrast_32.png" -resize 64x64 "$package_dir/usr/share/icons/hicolor/64x64/apps/cloudtolocalllm.png"
            convert "$assets_dir/tray_icon_contrast_32.png" -resize 128x128 "$package_dir/usr/share/icons/hicolor/128x128/apps/cloudtolocalllm.png"
            convert "$assets_dir/tray_icon_contrast_32.png" -resize 256x256 "$package_dir/usr/share/icons/hicolor/256x256/apps/cloudtolocalllm.png"
        else
            # Copy base icon to other sizes as fallback
            cp "$assets_dir/tray_icon_contrast_32.png" "$package_dir/usr/share/icons/hicolor/48x48/apps/cloudtolocalllm.png"
            cp "$assets_dir/tray_icon_contrast_32.png" "$package_dir/usr/share/icons/hicolor/64x64/apps/cloudtolocalllm.png"
            cp "$assets_dir/tray_icon_contrast_32.png" "$package_dir/usr/share/icons/hicolor/128x128/apps/cloudtolocalllm.png"
            cp "$assets_dir/tray_icon_contrast_32.png" "$package_dir/usr/share/icons/hicolor/256x256/apps/cloudtolocalllm.png"
        fi

        log_success "Icons copied and generated"
    else
        log_error "Source icons not found in $assets_dir"
        exit 1
    fi
}

# Build Debian package
build_debian_package() {
    log_info "Building Debian package..."

    local version="$1"
    local package_dir="$BUILD_DIR/package"

    cd "$BUILD_DIR"

    # Update installed size in control file
    local installed_size=$(du -sk "$package_dir/usr" | cut -f1)
    sed -i "s/Installed-Size: .*/Installed-Size: $installed_size/" "$package_dir/DEBIAN/control"

    # Set proper permissions
    find "$package_dir" -type d -exec chmod 755 {} \;
    find "$package_dir/usr/bin" -type f -exec chmod 755 {} \;
    find "$package_dir/usr/share" -type f -exec chmod 644 {} \;
    find "$package_dir/DEBIAN" -type f -name "post*" -exec chmod 755 {} \;
    find "$package_dir/DEBIAN" -type f -name "pre*" -exec chmod 755 {} \;
    chmod 644 "$package_dir/DEBIAN/control"

    # Build package using Docker with dpkg-deb
    local package_name="cloudtolocalllm_${version}_amd64.deb"

    # Use Docker to build the package since dpkg-deb might not be available on host
    docker run --rm \
        -v "$BUILD_DIR:/build" \
        -w /build \
        ubuntu:22.04 \
        bash -c "
            apt-get update && apt-get install -y dpkg-dev fakeroot
            fakeroot dpkg-deb --build package $package_name
        "

    if [[ -f "$BUILD_DIR/$package_name" ]]; then
        log_success "Debian package created: $package_name"
    else
        log_error "Debian package creation failed"
        exit 1
    fi
}

# Validate Debian package
validate_package() {
    log_info "Validating Debian package..."

    local version="$1"
    local package_name="cloudtolocalllm_${version}_amd64.deb"

    cd "$BUILD_DIR"

    # Check package with lintian
    if command -v lintian &> /dev/null; then
        log_info "Running lintian checks..."
        if lintian "$package_name"; then
            log_success "Lintian validation passed"
        else
            log_warning "Lintian found issues (may be non-critical)"
        fi
    else
        log_warning "Lintian not available, skipping validation"
    fi

    # Test package installation (dry run) using Docker
    log_info "Testing package installation (dry run)..."
    if docker run --rm -v "$BUILD_DIR:/build" ubuntu:22.04 dpkg --info "/build/$package_name" &> /dev/null; then
        log_success "Package structure validation passed"
    else
        log_error "Package structure validation failed"
        exit 1
    fi
}

# Generate checksums
generate_checksums() {
    log_info "Generating checksums..."

    local version="$1"
    local package_name="cloudtolocalllm_${version}_amd64.deb"

    cd "$BUILD_DIR"

    if [[ -f "$package_name" ]]; then
        sha256sum "$package_name" > "${package_name}.sha256"
        log_success "SHA256 checksum generated"
    fi
}

# Copy to distribution directory
copy_to_dist() {
    log_info "Copying package to distribution directory..."

    local version="$1"
    local package_name="cloudtolocalllm_${version}_amd64.deb"

    mkdir -p "$DIST_DIR"

    # Copy package and checksum
    cp "$BUILD_DIR/$package_name" "$DIST_DIR/"
    cp "$BUILD_DIR/${package_name}.sha256" "$DIST_DIR/"

    log_success "Debian package copied to $DIST_DIR"
}

# Test package in Docker container
test_package_in_docker() {
    log_info "Testing package installation in Docker container..."

    local version="$1"
    local package_name="cloudtolocalllm_${version}_amd64.deb"

    # Test installation in clean Ubuntu container
    docker run --rm \
        -v "$DIST_DIR:/packages" \
        ubuntu:22.04 \
        bash -c "
            set -e
            apt-get update
            apt-get install -y /packages/$package_name
            echo 'Package installed successfully'

            # Test if executable exists and is runnable
            if command -v cloudtolocalllm &> /dev/null; then
                echo 'CloudToLocalLLM executable found'
            else
                echo 'ERROR: CloudToLocalLLM executable not found'
                exit 1
            fi

            # Test desktop file
            if [[ -f /usr/share/applications/cloudtolocalllm.desktop ]]; then
                echo 'Desktop file installed correctly'
            else
                echo 'ERROR: Desktop file not found'
                exit 1
            fi

            # Test icons
            if [[ -f /usr/share/icons/hicolor/32x32/apps/cloudtolocalllm.png ]]; then
                echo 'Icons installed correctly'
            else
                echo 'ERROR: Icons not found'
                exit 1
            fi

            echo 'All package tests passed'
        "

    log_success "Package installation test passed"
}

# Cleanup build artifacts
cleanup() {
    log_info "Cleaning up build artifacts..."

    # Keep the final package but clean intermediate files
    if [[ -d "$BUILD_DIR/package" ]]; then
        rm -rf "$BUILD_DIR/package"
    fi

    log_success "Build artifacts cleaned up"
}

# Main execution function
main() {
    log_info "Starting CloudToLocalLLM Debian package build process..."

    # Get version
    local version=$(get_version)
    log_info "Building version: $version"

    # Create build directories
    mkdir -p "$BUILD_DIR"
    mkdir -p "$DIST_DIR"

    # Execute build steps
    check_docker
    create_docker_environment
    build_docker_image
    build_flutter_in_docker "$version"
    prepare_package_structure
    copy_application_files
    copy_icons
    create_desktop_file "$version"
    create_man_page "$version"
    create_control_files "$version"
    build_debian_package "$version"
    validate_package "$version"
    generate_checksums "$version"
    copy_to_dist "$version"
    test_package_in_docker "$version"
    cleanup

    log_success "Debian package build completed successfully!"
    log_info "Package location: $DIST_DIR/cloudtolocalllm_${version}_amd64.deb"
    log_info "SHA256 checksum: $DIST_DIR/cloudtolocalllm_${version}_amd64.deb.sha256"

    # Display final information
    echo
    echo "=== Debian Package Build Summary ==="
    echo "Version: $version"
    echo "Package: cloudtolocalllm_${version}_amd64.deb"
    echo "Size: $(du -h "$DIST_DIR/cloudtolocalllm_${version}_amd64.deb" | cut -f1)"
    echo "SHA256: $(cat "$DIST_DIR/cloudtolocalllm_${version}_amd64.deb.sha256" | cut -d' ' -f1)"
    echo
    echo "Installation: sudo dpkg -i cloudtolocalllm_${version}_amd64.deb"
    echo "Dependencies: sudo apt-get install -f  # if needed"
    echo
}

# Handle script arguments
case "${1:-}" in
    --help|-h)
        echo "CloudToLocalLLM Debian Package Build Script"
        echo
        echo "Usage: $0 [options]"
        echo
        echo "Options:"
        echo "  --help, -h     Show this help message"
        echo "  --clean        Clean build artifacts before building"
        echo
        echo "This script builds a .deb package for CloudToLocalLLM with:"
        echo "  - Flutter Linux application bundle"
        echo "  - System tray integration support"
        echo "  - Proper Debian package structure"
        echo "  - All required dependencies and metadata"
        echo
        echo "Requirements:"
        echo "  - Docker (for consistent build environment)"
        echo "  - Internet connection (for downloading dependencies)"
        echo
        exit 0
        ;;
    --clean)
        log_info "Cleaning build artifacts..."
        rm -rf "$BUILD_DIR"
        rm -rf "$DIST_DIR"
        rm -rf "$DOCKER_DIR"
        log_success "Build artifacts cleaned"
        ;;
esac

# Run main function
main "$@"
