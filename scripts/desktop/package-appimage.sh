#!/bin/bash

# AppImage creation script for CloudToLocalLLM Desktop Bridge
set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
BUILD_DIR="$PROJECT_ROOT/build/desktop-bridge"
DIST_DIR="$PROJECT_ROOT/dist"
APPIMAGE_DIR="$PROJECT_ROOT/build/appimage"

# AppImage information
APP_NAME="CloudToLocalLLM-Bridge"
APP_VERSION="1.0.0"

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
}

# Download AppImage tools
download_appimage_tools() {
    log_info "Downloading AppImage tools..."
    
    mkdir -p "$PROJECT_ROOT/tools"
    
    # Download appimagetool if not present
    if [ ! -f "$PROJECT_ROOT/tools/appimagetool" ]; then
        log_info "Downloading appimagetool..."
        wget -O "$PROJECT_ROOT/tools/appimagetool" \
            "https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage"
        chmod +x "$PROJECT_ROOT/tools/appimagetool"
    fi
    
    # Download linuxdeploy if not present
    if [ ! -f "$PROJECT_ROOT/tools/linuxdeploy" ]; then
        log_info "Downloading linuxdeploy..."
        wget -O "$PROJECT_ROOT/tools/linuxdeploy" \
            "https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-x86_64.AppImage"
        chmod +x "$PROJECT_ROOT/tools/linuxdeploy"
    fi
}

# Create AppDir structure
create_appdir() {
    log_info "Creating AppDir structure..."
    
    rm -rf "$APPIMAGE_DIR"
    mkdir -p "$APPIMAGE_DIR"
    
    # Create standard AppDir structure
    mkdir -p "$APPIMAGE_DIR/usr/bin"
    mkdir -p "$APPIMAGE_DIR/usr/lib"
    mkdir -p "$APPIMAGE_DIR/usr/share/applications"
    mkdir -p "$APPIMAGE_DIR/usr/share/pixmaps"
    mkdir -p "$APPIMAGE_DIR/usr/share/icons/hicolor/64x64/apps"
}

# Copy application files
copy_application_files() {
    log_info "Copying application files..."

    # Copy Flutter application bundle
    cp -r "$BUILD_DIR/bundle/opt/cloudtolocalllm-bridge" "$APPIMAGE_DIR/usr/bin/"

    # Create main executable symlink
    ln -sf "/usr/bin/cloudtolocalllm-bridge/cloudtolocalllm-bridge-wrapper" "$APPIMAGE_DIR/usr/bin/cloudtolocalllm-bridge"

    # Copy icon
    if [ -f "$BUILD_DIR/bundle/usr/share/pixmaps/cloudtolocalllm-bridge.png" ]; then
        cp "$BUILD_DIR/bundle/usr/share/pixmaps/cloudtolocalllm-bridge.png" "$APPIMAGE_DIR/usr/share/pixmaps/"
        cp "$BUILD_DIR/bundle/usr/share/pixmaps/cloudtolocalllm-bridge.png" "$APPIMAGE_DIR/usr/share/icons/hicolor/64x64/apps/"

        # Create AppImage icon (required at root level)
        cp "$BUILD_DIR/bundle/usr/share/pixmaps/cloudtolocalllm-bridge.png" "$APPIMAGE_DIR/cloudtolocalllm-bridge.png"
    elif [ -f "$BUILD_DIR/bundle/usr/share/pixmaps/cloudtolocalllm-bridge.svg" ]; then
        cp "$BUILD_DIR/bundle/usr/share/pixmaps/cloudtolocalllm-bridge.svg" "$APPIMAGE_DIR/usr/share/pixmaps/"
        cp "$BUILD_DIR/bundle/usr/share/pixmaps/cloudtolocalllm-bridge.svg" "$APPIMAGE_DIR/cloudtolocalllm-bridge.svg"
    fi
}

# Create desktop file for AppImage
create_appimage_desktop_file() {
    log_info "Creating AppImage desktop file..."
    
    cat > "$APPIMAGE_DIR/cloudtolocalllm-bridge.desktop" << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=CloudToLocalLLM Bridge
Comment=Secure bridge for local Ollama to cloud service
GenericName=LLM Bridge
Exec=cloudtolocalllm-bridge
Icon=cloudtolocalllm-bridge
Terminal=false
StartupNotify=true
Categories=Network;Utility;
Keywords=ollama;llm;ai;bridge;cloud;
StartupWMClass=cloudtolocalllm-bridge
EOF
    
    # Also copy to standard location
    cp "$APPIMAGE_DIR/cloudtolocalllm-bridge.desktop" "$APPIMAGE_DIR/usr/share/applications/"
}

# Create AppRun script
create_apprun() {
    log_info "Creating AppRun script..."
    
    cat > "$APPIMAGE_DIR/AppRun" << 'EOF'
#!/bin/bash

# AppRun script for CloudToLocalLLM Bridge

# Get the directory where this AppImage is mounted
HERE="$(dirname "$(readlink -f "${0}")")"

# Set up environment
export PATH="${HERE}/usr/bin:${PATH}"
export LD_LIBRARY_PATH="${HERE}/usr/lib:${LD_LIBRARY_PATH}"
export XDG_DATA_DIRS="${HERE}/usr/share:${XDG_DATA_DIRS}"

# Set GTK theme path if available
if [ -d "${HERE}/usr/share/themes" ]; then
    export GTK_THEME_PATH="${HERE}/usr/share/themes:${GTK_THEME_PATH}"
fi

# Run the application
exec "${HERE}/usr/bin/cloudtolocalllm-bridge" "$@"
EOF
    
    chmod +x "$APPIMAGE_DIR/AppRun"
}

# Bundle dependencies
bundle_dependencies() {
    log_info "Bundling dependencies..."
    
    # Use linuxdeploy to bundle dependencies
    if [ -f "$PROJECT_ROOT/tools/linuxdeploy" ]; then
        log_info "Using linuxdeploy to bundle dependencies..."
        
        cd "$APPIMAGE_DIR"
        "$PROJECT_ROOT/tools/linuxdeploy" \
            --appdir "$APPIMAGE_DIR" \
            --executable "$APPIMAGE_DIR/usr/bin/cloudtolocalllm-bridge" \
            --desktop-file "$APPIMAGE_DIR/cloudtolocalllm-bridge.desktop" \
            --icon-file "$APPIMAGE_DIR/cloudtolocalllm-bridge.png" \
            --output appimage || log_warning "linuxdeploy failed, continuing anyway..."
    else
        log_warning "linuxdeploy not available, skipping dependency bundling"
    fi
}

# Create AppImage
create_appimage() {
    log_info "Creating AppImage..."
    
    # Set environment variables for appimagetool
    export ARCH=x86_64
    export VERSION="$APP_VERSION"
    
    # Create AppImage
    APPIMAGE_FILE="$DIST_DIR/${APP_NAME}-${APP_VERSION}-x86_64.AppImage"
    
    if [ -f "$PROJECT_ROOT/tools/appimagetool" ]; then
        "$PROJECT_ROOT/tools/appimagetool" "$APPIMAGE_DIR" "$APPIMAGE_FILE"
    else
        log_error "appimagetool not found. Cannot create AppImage."
        exit 1
    fi
    
    # Make executable
    chmod +x "$APPIMAGE_FILE"
    
    log_success "AppImage created: $APPIMAGE_FILE"
}

# Test AppImage
test_appimage() {
    log_info "Testing AppImage..."
    
    APPIMAGE_FILE="$DIST_DIR/${APP_NAME}-${APP_VERSION}-x86_64.AppImage"
    
    # Test version flag
    if "$APPIMAGE_FILE" --version; then
        log_success "AppImage version test passed"
    else
        log_error "AppImage version test failed"
        exit 1
    fi
    
    # Test help flag
    if "$APPIMAGE_FILE" --help > /dev/null; then
        log_success "AppImage help test passed"
    else
        log_error "AppImage help test failed"
        exit 1
    fi
}

# Create AppImage info
create_appimage_info() {
    log_info "Creating AppImage info..."
    
    APPIMAGE_FILE="$DIST_DIR/${APP_NAME}-${APP_VERSION}-x86_64.AppImage"
    INFO_FILE="$DIST_DIR/${APP_NAME}-${APP_VERSION}-x86_64.AppImage.info"
    
    cat > "$INFO_FILE" << EOF
CloudToLocalLLM Desktop Bridge AppImage
======================================

Version: $APP_VERSION
Architecture: x86_64
Created: $(date)

This AppImage contains the CloudToLocalLLM Desktop Bridge application
and all its dependencies. It should run on most Linux distributions
without additional installation.

Usage:
  ./${APP_NAME}-${APP_VERSION}-x86_64.AppImage              # Run with system tray
  ./${APP_NAME}-${APP_VERSION}-x86_64.AppImage --daemon     # Run as daemon
  ./${APP_NAME}-${APP_VERSION}-x86_64.AppImage --help       # Show help

To integrate with your desktop:
  1. Make the AppImage executable: chmod +x ${APP_NAME}-${APP_VERSION}-x86_64.AppImage
  2. Run it once to register with the system
  3. It will appear in your applications menu

For more information, visit: https://cloudtolocalllm.online
EOF
    
    log_info "AppImage info created: $INFO_FILE"
}

# Main packaging process
main() {
    log_info "Starting AppImage creation..."
    
    check_build
    download_appimage_tools
    create_appdir
    copy_application_files
    create_appimage_desktop_file
    create_apprun
    bundle_dependencies
    create_appimage
    test_appimage
    create_appimage_info
    
    log_success "AppImage creation completed!"
    log_info ""
    log_info "AppImage file: $DIST_DIR/${APP_NAME}-${APP_VERSION}-x86_64.AppImage"
    log_info ""
    log_info "To test:"
    log_info "  chmod +x $DIST_DIR/${APP_NAME}-${APP_VERSION}-x86_64.AppImage"
    log_info "  $DIST_DIR/${APP_NAME}-${APP_VERSION}-x86_64.AppImage --version"
}

# Run main function
main "$@"
