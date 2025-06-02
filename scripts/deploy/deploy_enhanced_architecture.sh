#!/bin/bash
# CloudToLocalLLM Enhanced Architecture Deployment Script
# 
# This script handles the complete deployment of the enhanced system tray architecture
# including building, packaging, testing, and distribution across all channels.

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
VERSION="3.0.0"
BUILD_DIR="$PROJECT_ROOT/build"
DIST_DIR="$PROJECT_ROOT/dist"
PACKAGING_DIR="$PROJECT_ROOT/packaging"

# Platform detection
PLATFORM=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)

case "$ARCH" in
    x86_64|amd64) ARCH="x64" ;;
    aarch64|arm64) ARCH="arm64" ;;
    *) echo -e "${RED}Unsupported architecture: $ARCH${NC}"; exit 1 ;;
esac

echo -e "${BLUE}CloudToLocalLLM Enhanced Architecture Deployment${NC}"
echo -e "${BLUE}===============================================${NC}"
echo "Version: $VERSION"
echo "Platform: $PLATFORM-$ARCH"
echo "Project Root: $PROJECT_ROOT"
echo ""

# Function to print status messages
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_section() {
    echo -e "${PURPLE}[SECTION]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    print_section "Checking Prerequisites"
    
    # Check Flutter
    if ! command -v flutter &> /dev/null; then
        print_error "Flutter not found. Please install Flutter."
        exit 1
    fi
    
    # Check Python
    if ! command -v python3 &> /dev/null; then
        print_error "Python 3 not found. Please install Python 3.8+."
        exit 1
    fi
    
    # Check Git
    if ! command -v git &> /dev/null; then
        print_error "Git not found. Please install Git."
        exit 1
    fi
    
    print_status "All prerequisites satisfied"
}

# Clean previous builds
clean_builds() {
    print_section "Cleaning Previous Builds"
    
    if [ -d "$BUILD_DIR" ]; then
        rm -rf "$BUILD_DIR"
        print_status "Removed build directory"
    fi
    
    if [ -d "$DIST_DIR" ]; then
        rm -rf "$DIST_DIR"
        print_status "Removed dist directory"
    fi
    
    # Clean Flutter
    cd "$PROJECT_ROOT"
    flutter clean
    print_status "Flutter clean completed"
}

# Build Flutter application
build_flutter_app() {
    print_section "Building Flutter Application"
    
    cd "$PROJECT_ROOT"
    
    # Configure Flutter
    flutter config --enable-linux-desktop
    
    # Get dependencies
    flutter pub get
    
    # Build for Linux
    flutter build linux --release
    
    print_status "Flutter application built successfully"
}

# Build enhanced tray daemon
build_enhanced_daemon() {
    print_section "Building Enhanced Tray Daemon"
    
    cd "$PROJECT_ROOT"
    
    # Run the enhanced tray daemon build script
    if [ -f "scripts/build/build_tray_daemon.sh" ]; then
        ./scripts/build/build_tray_daemon.sh
        print_status "Enhanced tray daemon built successfully"
    else
        print_error "Tray daemon build script not found"
        exit 1
    fi
}

# Create AppImage package
create_appimage() {
    print_section "Creating AppImage Package"
    
    local appdir="$PACKAGING_DIR/appimage/CloudToLocalLLM.AppDir"
    
    # Prepare AppDir
    if [ -d "$appdir" ]; then
        rm -rf "$appdir"
    fi
    mkdir -p "$appdir"
    
    # Copy Flutter app
    cp -r "$BUILD_DIR/linux/$ARCH/release/bundle"/* "$appdir/"
    
    # Copy enhanced tray daemon
    mkdir -p "$appdir/tray_daemon"
    cp -r "$DIST_DIR/tray_daemon/$PLATFORM-$ARCH"/* "$appdir/tray_daemon/"
    
    # Create AppRun script
    cat > "$appdir/AppRun" << 'EOF'
#!/bin/bash
HERE="$(dirname "$(readlink -f "${0}")")"
export PATH="${HERE}/tray_daemon:${PATH}"
cd "${HERE}"
exec ./cloudtolocalllm "$@"
EOF
    chmod +x "$appdir/AppRun"
    
    # Copy desktop file and icon
    # Try multiple locations for the desktop file
    if [ -f "$PACKAGING_DIR/linux/desktop/cloudtolocalllm.desktop" ]; then
        cp "$PACKAGING_DIR/linux/desktop/cloudtolocalllm.desktop" "$appdir/"
    elif [ -f "$PROJECT_ROOT/aur-package/cloudtolocalllm.desktop" ]; then
        cp "$PROJECT_ROOT/aur-package/cloudtolocalllm.desktop" "$appdir/"
    else
        print_error "Desktop file not found in expected locations"
        exit 1
    fi

    # Copy icon with fallback options
    if [ -f "$PROJECT_ROOT/assets/images/app_icon.png" ]; then
        cp "$PROJECT_ROOT/assets/images/app_icon.png" "$appdir/cloudtolocalllm.png"
    elif [ -f "$PROJECT_ROOT/assets/images/tray_icon.png" ]; then
        cp "$PROJECT_ROOT/assets/images/tray_icon.png" "$appdir/cloudtolocalllm.png"
    elif [ -f "$PROJECT_ROOT/assets/linux/app_icon.png" ]; then
        cp "$PROJECT_ROOT/assets/linux/app_icon.png" "$appdir/cloudtolocalllm.png"
    else
        print_warning "No suitable icon found, AppImage may not display properly"
    fi
    
    # Create AppImage
    cd "$PACKAGING_DIR"
    if [ -f "appimagetool-x86_64.AppImage" ]; then
        ./appimagetool-x86_64.AppImage appimage/CloudToLocalLLM.AppDir "$DIST_DIR/CloudToLocalLLM-$VERSION-x86_64.AppImage"
        print_status "AppImage created: $DIST_DIR/CloudToLocalLLM-$VERSION-x86_64.AppImage"
    else
        print_warning "AppImageTool not found, skipping AppImage creation"
    fi
}

# Create DEB package
create_deb_package() {
    print_section "Creating DEB Package"
    
    if command -v dpkg-deb &> /dev/null; then
        cd "$PACKAGING_DIR"
        if [ -f "build_deb.sh" ]; then
            ./build_deb.sh
            print_status "DEB package created"
        else
            print_warning "DEB build script not found"
        fi
    else
        print_warning "dpkg-deb not available, skipping DEB package creation"
    fi
}

# Update AUR package
update_aur_package() {
    print_section "Updating AUR Package"
    
    # Update PKGBUILD version
    sed -i "s/pkgver=.*/pkgver=$VERSION/" "$PACKAGING_DIR/aur/PKGBUILD"
    
    print_status "AUR PKGBUILD updated to version $VERSION"
    print_status "Manual steps required:"
    print_status "  1. Test build: cd packaging/aur && makepkg -si"
    print_status "  2. Update AUR repository with new PKGBUILD"
}

# Run tests
run_tests() {
    print_section "Running Tests"
    
    # Test Flutter app
    cd "$PROJECT_ROOT"
    if [ -f "$BUILD_DIR/linux/$ARCH/release/bundle/cloudtolocalllm" ]; then
        print_status "Flutter executable exists"
    else
        print_error "Flutter executable not found"
        exit 1
    fi
    
    # Test enhanced tray daemon
    local daemon_exe="$DIST_DIR/tray_daemon/$PLATFORM-$ARCH/cloudtolocalllm-enhanced-tray"
    if [ -f "$daemon_exe" ]; then
        print_status "Enhanced tray daemon executable exists"
        
        # Test version flag
        if timeout 5 "$daemon_exe" --version &> /dev/null; then
            print_status "Daemon version test passed"
        else
            print_warning "Daemon version test failed or timed out"
        fi
    else
        print_error "Enhanced tray daemon executable not found"
        exit 1
    fi
    
    # Test settings app
    local settings_exe="$DIST_DIR/tray_daemon/$PLATFORM-$ARCH/cloudtolocalllm-settings"
    if [ -f "$settings_exe" ]; then
        print_status "Settings application executable exists"
    else
        print_warning "Settings application executable not found"
    fi
    
    print_status "All tests passed"
}

# Generate deployment summary
generate_summary() {
    print_section "Generating Deployment Summary"
    
    local summary_file="$DIST_DIR/DEPLOYMENT_SUMMARY.txt"
    
    cat > "$summary_file" << EOF
CloudToLocalLLM Enhanced Architecture Deployment Summary
========================================================

Version: $VERSION
Build Date: $(date)
Platform: $PLATFORM-$ARCH

Built Components:
EOF
    
    # List built files
    if [ -f "$BUILD_DIR/linux/$ARCH/release/bundle/cloudtolocalllm" ]; then
        echo "✅ Flutter Application: $(du -h "$BUILD_DIR/linux/$ARCH/release/bundle/cloudtolocalllm" | cut -f1)" >> "$summary_file"
    fi
    
    if [ -f "$DIST_DIR/tray_daemon/$PLATFORM-$ARCH/cloudtolocalllm-enhanced-tray" ]; then
        echo "✅ Enhanced Tray Daemon: $(du -h "$DIST_DIR/tray_daemon/$PLATFORM-$ARCH/cloudtolocalllm-enhanced-tray" | cut -f1)" >> "$summary_file"
    fi
    
    if [ -f "$DIST_DIR/tray_daemon/$PLATFORM-$ARCH/cloudtolocalllm-settings" ]; then
        echo "✅ Settings Application: $(du -h "$DIST_DIR/tray_daemon/$PLATFORM-$ARCH/cloudtolocalllm-settings" | cut -f1)" >> "$summary_file"
    fi
    
    if [ -f "$DIST_DIR/CloudToLocalLLM-$VERSION-x86_64.AppImage" ]; then
        echo "✅ AppImage Package: $(du -h "$DIST_DIR/CloudToLocalLLM-$VERSION-x86_64.AppImage" | cut -f1)" >> "$summary_file"
    fi
    
    cat >> "$summary_file" << EOF

Distribution Packages:
$(find "$DIST_DIR" -name "*.AppImage" -o -name "*.deb" -o -name "*.tar.gz" | while read file; do
    echo "📦 $(basename "$file"): $(du -h "$file" | cut -f1)"
done)

Next Steps:
1. Test packages on target systems
2. Upload to GitHub releases
3. Update AUR repository
4. Update download page
5. Announce release

EOF
    
    print_status "Deployment summary generated: $summary_file"
}

# Main deployment process
main() {
    local action="${1:-all}"
    
    case "$action" in
        "clean")
            clean_builds
            ;;
        "flutter")
            build_flutter_app
            ;;
        "daemon")
            build_enhanced_daemon
            ;;
        "appimage")
            create_appimage
            ;;
        "deb")
            create_deb_package
            ;;
        "aur")
            update_aur_package
            ;;
        "test")
            run_tests
            ;;
        "summary")
            generate_summary
            ;;
        "all")
            check_prerequisites
            clean_builds
            build_flutter_app
            build_enhanced_daemon
            create_appimage
            create_deb_package
            update_aur_package
            run_tests
            generate_summary
            
            echo ""
            print_section "Deployment Complete!"
            echo -e "${GREEN}✅ Enhanced System Tray Architecture deployed successfully!${NC}"
            echo -e "${GREEN}📁 Output directory: $DIST_DIR${NC}"
            echo -e "${GREEN}📋 Summary: $DIST_DIR/DEPLOYMENT_SUMMARY.txt${NC}"
            echo ""
            ;;
        "--help"|"-h")
            echo "Usage: $0 [action]"
            echo ""
            echo "Actions:"
            echo "  all       Complete deployment (default)"
            echo "  clean     Clean previous builds"
            echo "  flutter   Build Flutter application only"
            echo "  daemon    Build enhanced tray daemon only"
            echo "  appimage  Create AppImage package only"
            echo "  deb       Create DEB package only"
            echo "  aur       Update AUR package only"
            echo "  test      Run tests only"
            echo "  summary   Generate deployment summary only"
            echo "  --help    Show this help"
            exit 0
            ;;
        *)
            print_error "Unknown action: $action"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"
