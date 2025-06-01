#!/bin/bash

# Build script for CloudToLocalLLM Desktop Bridge
set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
BRIDGE_DIR="$PROJECT_ROOT/desktop-bridge"
BUILD_DIR="$PROJECT_ROOT/build/desktop-bridge"
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
    
    if ! command -v go &> /dev/null; then
        log_error "Go is not installed. Please install Go 1.21 or later."
        exit 1
    fi
    
    GO_VERSION=$(go version | grep -oE 'go[0-9]+\.[0-9]+' | sed 's/go//')
    log_info "Found Go version: $GO_VERSION"
    
    if ! command -v pkg-config &> /dev/null; then
        log_warning "pkg-config not found. Some features may not work."
    fi
    
    # Check for GTK development libraries
    if ! pkg-config --exists gtk+-3.0; then
        log_warning "GTK+3 development libraries not found. System tray may not work."
        log_warning "Install with: sudo apt-get install libgtk-3-dev (Ubuntu/Debian)"
        log_warning "            or: sudo dnf install gtk3-devel (Fedora/RHEL)"
    fi
}

# Clean build directory
clean_build() {
    log_info "Cleaning build directory..."
    rm -rf "$BUILD_DIR"
    mkdir -p "$BUILD_DIR"
    mkdir -p "$DIST_DIR"
}

# Build the Go application
build_go_app() {
    log_info "Building Go application..."
    
    cd "$BRIDGE_DIR"
    
    # Download dependencies
    log_info "Downloading Go dependencies..."
    go mod download
    go mod tidy
    
    # Build for Linux
    log_info "Building for Linux amd64..."
    CGO_ENABLED=1 GOOS=linux GOARCH=amd64 go build \
        -ldflags "-X main.AppVersion=1.0.0 -X main.BuildTime=$(date -u +%Y-%m-%dT%H:%M:%SZ) -s -w" \
        -o "$BUILD_DIR/cloudtolocalllm-bridge" \
        .
    
    # Make executable
    chmod +x "$BUILD_DIR/cloudtolocalllm-bridge"
    
    log_success "Go application built successfully"
}

# Create application icons
create_icons() {
    log_info "Creating application icons..."
    
    # Create a simple SVG icon (placeholder)
    cat > "$BUILD_DIR/cloudtolocalllm-bridge.svg" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<svg width="64" height="64" viewBox="0 0 64 64" xmlns="http://www.w3.org/2000/svg">
  <rect width="64" height="64" rx="8" fill="#2563eb"/>
  <circle cx="32" cy="20" r="8" fill="white"/>
  <rect x="16" y="32" width="32" height="4" rx="2" fill="white"/>
  <rect x="20" y="40" width="24" height="4" rx="2" fill="white"/>
  <rect x="24" y="48" width="16" height="4" rx="2" fill="white"/>
</svg>
EOF
    
    # Convert to PNG if imagemagick is available
    if command -v convert &> /dev/null; then
        log_info "Converting SVG to PNG icons..."
        convert "$BUILD_DIR/cloudtolocalllm-bridge.svg" -resize 64x64 "$BUILD_DIR/cloudtolocalllm-bridge.png"
        convert "$BUILD_DIR/cloudtolocalllm-bridge.svg" -resize 48x48 "$BUILD_DIR/cloudtolocalllm-bridge-48.png"
        convert "$BUILD_DIR/cloudtolocalllm-bridge.svg" -resize 32x32 "$BUILD_DIR/cloudtolocalllm-bridge-32.png"
        convert "$BUILD_DIR/cloudtolocalllm-bridge.svg" -resize 16x16 "$BUILD_DIR/cloudtolocalllm-bridge-16.png"
    else
        log_warning "ImageMagick not found. Using SVG icon only."
        cp "$BUILD_DIR/cloudtolocalllm-bridge.svg" "$BUILD_DIR/cloudtolocalllm-bridge.png"
    fi
}

# Test the built application
test_build() {
    log_info "Testing built application..."
    
    # Test version flag
    if "$BUILD_DIR/cloudtolocalllm-bridge" --version; then
        log_success "Application version test passed"
    else
        log_error "Application version test failed"
        exit 1
    fi
    
    # Test help flag
    if "$BUILD_DIR/cloudtolocalllm-bridge" --help > /dev/null; then
        log_success "Application help test passed"
    else
        log_error "Application help test failed"
        exit 1
    fi
}

# Main build process
main() {
    log_info "Starting CloudToLocalLLM Desktop Bridge build..."
    log_info "Project root: $PROJECT_ROOT"
    log_info "Build directory: $BUILD_DIR"
    
    check_dependencies
    clean_build
    build_go_app
    create_icons
    test_build
    
    log_success "Build completed successfully!"
    log_info "Built files are in: $BUILD_DIR"
    log_info ""
    log_info "To test the application:"
    log_info "  $BUILD_DIR/cloudtolocalllm-bridge --help"
    log_info ""
    log_info "To create packages, run:"
    log_info "  $SCRIPT_DIR/package-deb.sh"
    log_info "  $SCRIPT_DIR/package-appimage.sh"
}

# Run main function
main "$@"
