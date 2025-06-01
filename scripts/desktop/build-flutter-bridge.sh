#!/bin/bash

# Build script for CloudToLocalLLM Flutter Desktop Bridge
set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
FLUTTER_BRIDGE_DIR="$PROJECT_ROOT/desktop-bridge-flutter"
BUILD_DIR="$PROJECT_ROOT/build/flutter-bridge"
DIST_DIR="$PROJECT_ROOT/dist"

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

# Check dependencies
check_dependencies() {
    log_info "Checking dependencies..."
    
    if ! command -v flutter &> /dev/null; then
        log_error "Flutter is not installed. Please install Flutter and try again."
        log_error "Visit: https://docs.flutter.dev/get-started/install/linux"
        exit 1
    fi
    
    FLUTTER_VERSION=$(flutter --version | head -n 1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
    log_info "Found Flutter version: $FLUTTER_VERSION"
    
    # Check if desktop support is enabled
    if ! flutter config | grep -q "enable-linux-desktop: true"; then
        log_info "Enabling Flutter desktop support..."
        flutter config --enable-linux-desktop
    fi
    
    # Check for required system packages
    local missing_packages=()
    
    if ! pkg-config --exists gtk+-3.0; then
        missing_packages+=("libgtk-3-dev")
    fi
    
    if ! pkg-config --exists glib-2.0; then
        missing_packages+=("libglib2.0-dev")
    fi
    
    if ! command -v ninja &> /dev/null; then
        missing_packages+=("ninja-build")
    fi
    
    if ! command -v cmake &> /dev/null; then
        missing_packages+=("cmake")
    fi
    
    if [ ${#missing_packages[@]} -gt 0 ]; then
        log_error "Missing required packages: ${missing_packages[*]}"
        log_error "Install with: sudo apt-get install ${missing_packages[*]}"
        exit 1
    fi
    
    log_success "All dependencies are available"
}

# Clean build directory
clean_build() {
    log_info "Cleaning build directory..."
    rm -rf "$BUILD_DIR"
    mkdir -p "$BUILD_DIR"
    mkdir -p "$DIST_DIR"
    
    # Clean Flutter build cache
    cd "$FLUTTER_BRIDGE_DIR"
    flutter clean
    
    log_success "Build directory cleaned"
}

# Generate code
generate_code() {
    log_info "Generating code..."
    
    cd "$FLUTTER_BRIDGE_DIR"
    
    # Run code generation
    flutter packages get
    flutter packages pub run build_runner build --delete-conflicting-outputs
    
    log_success "Code generation completed"
}

# Build Flutter application
build_flutter_app() {
    log_info "Building Flutter desktop application..."
    
    cd "$FLUTTER_BRIDGE_DIR"
    
    # Build for Linux
    flutter build linux --release
    
    # Copy built application to build directory
    cp -r "build/linux/x64/release/bundle" "$BUILD_DIR/app"
    
    # Rename executable
    mv "$BUILD_DIR/app/cloudtolocalllm_bridge" "$BUILD_DIR/app/cloudtolocalllm-bridge"
    
    log_success "Flutter application built successfully"
}

# Create application bundle
create_app_bundle() {
    log_info "Creating application bundle..."
    
    # Create bundle structure
    mkdir -p "$BUILD_DIR/bundle/opt/cloudtolocalllm-bridge"
    mkdir -p "$BUILD_DIR/bundle/usr/bin"
    mkdir -p "$BUILD_DIR/bundle/usr/share/applications"
    mkdir -p "$BUILD_DIR/bundle/usr/share/pixmaps"
    
    # Copy application
    cp -r "$BUILD_DIR/app"/* "$BUILD_DIR/bundle/opt/cloudtolocalllm-bridge/"
    
    # Create wrapper script
    cat > "$BUILD_DIR/bundle/opt/cloudtolocalllm-bridge/cloudtolocalllm-bridge-wrapper" << 'EOF'
#!/bin/bash
# Wrapper script for CloudToLocalLLM Bridge

# Get the directory where this script is located
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Set up environment
export LD_LIBRARY_PATH="$DIR/lib:$LD_LIBRARY_PATH"

# Run the application
exec "$DIR/cloudtolocalllm-bridge" "$@"
EOF
    
    chmod +x "$BUILD_DIR/bundle/opt/cloudtolocalllm-bridge/cloudtolocalllm-bridge-wrapper"
    
    # Create symlink in /usr/bin
    ln -sf "/opt/cloudtolocalllm-bridge/cloudtolocalllm-bridge-wrapper" \
        "$BUILD_DIR/bundle/usr/bin/cloudtolocalllm-bridge"
    
    log_success "Application bundle created"
}

# Create desktop integration files
create_desktop_files() {
    log_info "Creating desktop integration files..."
    
    # Create desktop file
    cat > "$BUILD_DIR/bundle/usr/share/applications/cloudtolocalllm-bridge.desktop" << EOF
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
StartupWMClass=cloudtolocalllm_bridge
EOF
    
    # Create simple icon (SVG)
    cat > "$BUILD_DIR/bundle/usr/share/pixmaps/cloudtolocalllm-bridge.svg" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<svg width="64" height="64" viewBox="0 0 64 64" xmlns="http://www.w3.org/2000/svg">
  <rect width="64" height="64" rx="8" fill="#2563eb"/>
  <circle cx="32" cy="20" r="8" fill="white"/>
  <rect x="16" y="32" width="32" height="4" rx="2" fill="white"/>
  <rect x="20" y="40" width="24" height="4" rx="2" fill="white"/>
  <rect x="24" y="48" width="16" height="4" rx="2" fill="white"/>
</svg>
EOF
    
    # Convert to PNG if possible
    if command -v convert &> /dev/null; then
        convert "$BUILD_DIR/bundle/usr/share/pixmaps/cloudtolocalllm-bridge.svg" \
            -resize 64x64 "$BUILD_DIR/bundle/usr/share/pixmaps/cloudtolocalllm-bridge.png"
    else
        log_warning "ImageMagick not found. Using SVG icon only."
    fi
    
    log_success "Desktop integration files created"
}

# Test the built application
test_build() {
    log_info "Testing built application..."
    
    # Test if executable runs
    if "$BUILD_DIR/bundle/opt/cloudtolocalllm-bridge/cloudtolocalllm-bridge" --help &> /dev/null; then
        log_success "Application test passed"
    else
        log_warning "Application test failed - this may be normal for GUI applications"
    fi
    
    # Check if all required libraries are present
    if ldd "$BUILD_DIR/bundle/opt/cloudtolocalllm-bridge/cloudtolocalllm-bridge" | grep -q "not found"; then
        log_warning "Some libraries may be missing:"
        ldd "$BUILD_DIR/bundle/opt/cloudtolocalllm-bridge/cloudtolocalllm-bridge" | grep "not found"
    else
        log_success "All required libraries are available"
    fi
}

# Create tarball
create_tarball() {
    log_info "Creating distribution tarball..."
    
    cd "$BUILD_DIR"
    tar -czf "$DIST_DIR/cloudtolocalllm-bridge-flutter-1.0.0-linux-x64.tar.gz" \
        -C bundle .
    
    log_success "Distribution tarball created: $DIST_DIR/cloudtolocalllm-bridge-flutter-1.0.0-linux-x64.tar.gz"
}

# Main build process
main() {
    log_info "Starting CloudToLocalLLM Flutter Desktop Bridge build..."
    log_info "Project root: $PROJECT_ROOT"
    log_info "Flutter bridge directory: $FLUTTER_BRIDGE_DIR"
    log_info "Build directory: $BUILD_DIR"
    
    if [ ! -d "$FLUTTER_BRIDGE_DIR" ]; then
        log_error "Flutter bridge directory not found: $FLUTTER_BRIDGE_DIR"
        exit 1
    fi
    
    check_dependencies
    clean_build
    generate_code
    build_flutter_app
    create_app_bundle
    create_desktop_files
    test_build
    create_tarball
    
    log_success "Build completed successfully!"
    log_info ""
    log_info "Built files are in: $BUILD_DIR/bundle"
    log_info "Distribution tarball: $DIST_DIR/cloudtolocalllm-bridge-flutter-1.0.0-linux-x64.tar.gz"
    log_info ""
    log_info "To test the application:"
    log_info "  $BUILD_DIR/bundle/opt/cloudtolocalllm-bridge/cloudtolocalllm-bridge"
    log_info ""
    log_info "To install manually:"
    log_info "  sudo cp -r $BUILD_DIR/bundle/* /"
    log_info "  sudo update-desktop-database"
}

# Run main function
main "$@"
