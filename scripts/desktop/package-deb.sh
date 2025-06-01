#!/bin/bash

# Debian package creation script for CloudToLocalLLM Desktop Bridge
set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
BUILD_DIR="$PROJECT_ROOT/build/desktop-bridge"
DIST_DIR="$PROJECT_ROOT/dist"
PACKAGE_DIR="$PROJECT_ROOT/build/package/deb"

# Package information
PACKAGE_NAME="cloudtolocalllm-bridge"
PACKAGE_VERSION="1.0.0"
PACKAGE_ARCH="amd64"
PACKAGE_MAINTAINER="CloudToLocalLLM Team <support@cloudtolocalllm.online>"

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

# Check if build exists
check_build() {
    if [ ! -d "$BUILD_DIR/bundle" ]; then
        log_error "Built Flutter application not found. Please run build-flutter-bridge.sh first."
        exit 1
    fi

    if [ ! -f "$BUILD_DIR/bundle/opt/cloudtolocalllm-bridge/cloudtolocalllm-bridge" ]; then
        log_error "Flutter bridge executable not found. Please run build-flutter-bridge.sh first."
        exit 1
    fi

    if [ ! -f "$BUILD_DIR/bundle/usr/share/pixmaps/cloudtolocalllm-bridge.png" ] && [ ! -f "$BUILD_DIR/bundle/usr/share/pixmaps/cloudtolocalllm-bridge.svg" ]; then
        log_warning "Icon not found. Package will be created without icon."
    fi
}

# Create package directory structure
create_package_structure() {
    log_info "Creating package directory structure..."
    
    rm -rf "$PACKAGE_DIR"
    mkdir -p "$PACKAGE_DIR"
    
    # Create DEBIAN directory
    mkdir -p "$PACKAGE_DIR/DEBIAN"
    
    # Create application directories
    mkdir -p "$PACKAGE_DIR/opt/cloudtolocalllm-bridge"
    mkdir -p "$PACKAGE_DIR/usr/bin"
    mkdir -p "$PACKAGE_DIR/usr/share/applications"
    mkdir -p "$PACKAGE_DIR/usr/share/pixmaps"
    mkdir -p "$PACKAGE_DIR/usr/lib/systemd/user"
    mkdir -p "$PACKAGE_DIR/usr/share/doc/$PACKAGE_NAME"
}

# Copy application files
copy_application_files() {
    log_info "Copying application files..."

    # Copy entire Flutter application bundle
    cp -r "$BUILD_DIR/bundle"/* "$PACKAGE_DIR/"

    # Ensure executable permissions
    chmod 755 "$PACKAGE_DIR/opt/cloudtolocalllm-bridge/cloudtolocalllm-bridge"
    chmod 755 "$PACKAGE_DIR/opt/cloudtolocalllm-bridge/cloudtolocalllm-bridge-wrapper"

    # Copy systemd service file
    cp "$PROJECT_ROOT/packaging/linux/systemd/cloudtolocalllm-bridge.service" "$PACKAGE_DIR/usr/lib/systemd/user/"
}

# Create control file
create_control_file() {
    log_info "Creating control file..."
    
    cat > "$PACKAGE_DIR/DEBIAN/control" << EOF
Package: $PACKAGE_NAME
Version: $PACKAGE_VERSION
Section: net
Priority: optional
Architecture: $PACKAGE_ARCH
Depends: libc6 (>= 2.17), libgtk-3-0, libnotify4, libglib2.0-0, libgstreamer1.0-0, libgstreamer-plugins-base1.0-0
Maintainer: $PACKAGE_MAINTAINER
Description: CloudToLocalLLM Desktop Bridge (Flutter)
 A secure Flutter-based bridge connecting your local Ollama instance to the
 CloudToLocalLLM cloud service. Features include:
 .
  * Secure Auth0 authentication with PKCE flow
  * WebSocket tunnel to cloud relay
  * Native system tray integration
  * Automatic reconnection with exponential backoff
  * Material Design 3 user interface
  * Cross-platform Flutter architecture
  * Linux desktop integration
 .
 This package provides the Flutter desktop bridge application that enables
 secure communication between your local Ollama installation and the
 CloudToLocalLLM cloud platform.
Homepage: https://cloudtolocalllm.online
Documentation: https://docs.cloudtolocalllm.online
EOF
}

# Copy package scripts
copy_package_scripts() {
    log_info "Copying package scripts..."
    
    # Copy and make executable
    cp "$PROJECT_ROOT/packaging/linux/debian/postinst" "$PACKAGE_DIR/DEBIAN/"
    cp "$PROJECT_ROOT/packaging/linux/debian/prerm" "$PACKAGE_DIR/DEBIAN/"
    cp "$PROJECT_ROOT/packaging/linux/debian/postrm" "$PACKAGE_DIR/DEBIAN/"
    
    chmod 755 "$PACKAGE_DIR/DEBIAN/postinst"
    chmod 755 "$PACKAGE_DIR/DEBIAN/prerm"
    chmod 755 "$PACKAGE_DIR/DEBIAN/postrm"
}

# Create documentation
create_documentation() {
    log_info "Creating documentation..."
    
    # Create README
    cat > "$PACKAGE_DIR/usr/share/doc/$PACKAGE_NAME/README" << EOF
CloudToLocalLLM Desktop Bridge
==============================

A secure bridge connecting your local Ollama instance to the CloudToLocalLLM
cloud service.

Usage:
  cloudtolocalllm-bridge              # Run with system tray
  cloudtolocalllm-bridge --daemon     # Run as daemon
  cloudtolocalllm-bridge --help       # Show help

Configuration:
  Configuration file: ~/.config/cloudtolocalllm/bridge.yaml
  Authentication tokens: ~/.config/cloudtolocalllm/tokens.json

For more information, visit: https://cloudtolocalllm.online
EOF
    
    # Create changelog
    cat > "$PACKAGE_DIR/usr/share/doc/$PACKAGE_NAME/changelog" << EOF
cloudtolocalllm-bridge (1.0.0) stable; urgency=low

  * Initial release
  * Auth0 authentication support
  * WebSocket tunnel to cloud relay
  * System tray integration
  * Automatic reconnection
  * Linux desktop integration

 -- CloudToLocalLLM Team <support@cloudtolocalllm.online>  $(date -R)
EOF
    
    # Create copyright
    cat > "$PACKAGE_DIR/usr/share/doc/$PACKAGE_NAME/copyright" << EOF
Format: https://www.debian.org/doc/packaging-manuals/copyright-format/1.0/
Upstream-Name: cloudtolocalllm-bridge
Source: https://github.com/imrightguy/CloudToLocalLLM

Files: *
Copyright: 2024 CloudToLocalLLM Team
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
    
    # Compress changelog
    gzip -9 "$PACKAGE_DIR/usr/share/doc/$PACKAGE_NAME/changelog"
}

# Build the package
build_package() {
    log_info "Building Debian package..."
    
    # Calculate installed size
    INSTALLED_SIZE=$(du -sk "$PACKAGE_DIR" | cut -f1)
    echo "Installed-Size: $INSTALLED_SIZE" >> "$PACKAGE_DIR/DEBIAN/control"
    
    # Build package
    PACKAGE_FILE="$DIST_DIR/${PACKAGE_NAME}_${PACKAGE_VERSION}_${PACKAGE_ARCH}.deb"
    
    if command -v dpkg-deb &> /dev/null; then
        dpkg-deb --build "$PACKAGE_DIR" "$PACKAGE_FILE"
    else
        log_error "dpkg-deb not found. Cannot build Debian package."
        exit 1
    fi
    
    log_success "Debian package created: $PACKAGE_FILE"
}

# Verify the package
verify_package() {
    log_info "Verifying package..."
    
    PACKAGE_FILE="$DIST_DIR/${PACKAGE_NAME}_${PACKAGE_VERSION}_${PACKAGE_ARCH}.deb"
    
    if command -v dpkg &> /dev/null; then
        dpkg --info "$PACKAGE_FILE"
        dpkg --contents "$PACKAGE_FILE"
    else
        log_warning "dpkg not found. Cannot verify package."
    fi
    
    # Check if lintian is available for additional checks
    if command -v lintian &> /dev/null; then
        log_info "Running lintian checks..."
        lintian "$PACKAGE_FILE" || log_warning "Lintian found some issues (non-critical)"
    fi
}

# Main packaging process
main() {
    log_info "Starting Debian package creation..."
    
    check_build
    create_package_structure
    copy_application_files
    create_control_file
    copy_package_scripts
    create_documentation
    build_package
    verify_package
    
    log_success "Debian package creation completed!"
    log_info ""
    log_info "Package file: $DIST_DIR/${PACKAGE_NAME}_${PACKAGE_VERSION}_${PACKAGE_ARCH}.deb"
    log_info ""
    log_info "To install:"
    log_info "  sudo dpkg -i $DIST_DIR/${PACKAGE_NAME}_${PACKAGE_VERSION}_${PACKAGE_ARCH}.deb"
    log_info "  sudo apt-get install -f  # Fix dependencies if needed"
}

# Run main function
main "$@"
