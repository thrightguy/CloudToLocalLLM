#!/bin/bash
# CloudToLocalLLM Unified Package Builder v3.3.1
# Builds all applications with proper dependency alignment

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
BUILD_DIR="$PROJECT_ROOT/build"
DIST_DIR="$PROJECT_ROOT/dist"

# Get version from version manager
VERSION=$("$PROJECT_ROOT/scripts/version_manager.sh" get-semantic)
PACKAGE_DIR="$DIST_DIR/cloudtolocalllm-$VERSION"

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



# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."

    # Determine which Flutter to use
    if [[ -f "/opt/flutter/bin/flutter" && (-n "${WSL_DISTRO_NAME:-}" || -f "/proc/version") ]]; then
        export FLUTTER_CMD="/opt/flutter/bin/flutter"
        log_info "Using WSL Flutter: $FLUTTER_CMD"
    elif command -v flutter &> /dev/null; then
        export FLUTTER_CMD="flutter"
        log_info "Using system Flutter: $FLUTTER_CMD"
    else
        log_error "Flutter is not installed or not in PATH"
        exit 1
    fi

    log_success "Prerequisites check completed"
}

# Clean previous builds
clean_builds() {
    log_info "Cleaning previous builds..."
    
    rm -rf "$BUILD_DIR"
    rm -rf "$DIST_DIR"
    
    # Clean Flutter builds
    cd "$PROJECT_ROOT"
    "$FLUTTER_CMD" clean

    # Clean sub-apps
    if [[ -d "apps/main" ]]; then
        cd "apps/main"
        "$FLUTTER_CMD" clean
        cd "$PROJECT_ROOT"
    fi

    if [[ -d "apps/tunnel_manager" ]]; then
        cd "apps/tunnel_manager"
        "$FLUTTER_CMD" clean
        cd "$PROJECT_ROOT"
    fi
    
    log_success "Build cleanup completed"
}

# Build main Flutter application
build_main_app() {
    log_info "Building main Flutter application..."
    
    cd "$PROJECT_ROOT"

    # Get dependencies
    "$FLUTTER_CMD" pub get

    # Build for Linux
    "$FLUTTER_CMD" build linux --release
    
    if [[ ! -d "build/linux/x64/release/bundle" ]]; then
        log_error "Main app build failed"
        exit 1
    fi
    
    log_success "Main application built successfully"
}

# Build tunnel manager application
build_tunnel_manager() {
    log_info "Building tunnel manager application..."
    
    if [[ ! -d "apps/tunnel_manager" ]]; then
        log_warning "Tunnel manager not found, skipping..."
        return 0
    fi
    
    cd "$PROJECT_ROOT/apps/tunnel_manager"

    # Get dependencies
    "$FLUTTER_CMD" pub get

    # Build for Linux
    "$FLUTTER_CMD" build linux --release
    
    if [[ ! -d "build/linux/x64/release/bundle" ]]; then
        log_error "Tunnel manager build failed"
        exit 1
    fi
    
    cd "$PROJECT_ROOT"
    log_success "Tunnel manager built successfully"
}

# Build main chat application
build_main_chat() {
    log_info "Building main chat application..."
    
    if [[ ! -d "apps/main" ]]; then
        log_warning "Main chat app not found, skipping..."
        return 0
    fi
    
    cd "$PROJECT_ROOT/apps/main"

    # Get dependencies
    "$FLUTTER_CMD" pub get

    # Build for Linux
    "$FLUTTER_CMD" build linux --release
    
    if [[ ! -d "build/linux/x64/release/bundle" ]]; then
        log_error "Main chat app build failed"
        exit 1
    fi
    
    cd "$PROJECT_ROOT"
    log_success "Main chat application built successfully"
}



# Create unified package structure
create_package_structure() {
    log_info "Creating unified package structure..."
    
    mkdir -p "$PACKAGE_DIR"/{bin,lib,data,config,scripts}
    
    # Copy main application
    if [[ -d "build/linux/x64/release/bundle" ]]; then
        cp -r build/linux/x64/release/bundle/* "$PACKAGE_DIR/"
        mv "$PACKAGE_DIR/cloudtolocalllm" "$PACKAGE_DIR/bin/cloudtolocalllm_main"
    fi
    
    # Copy tunnel manager if available
    if [[ -d "apps/tunnel_manager/build/linux/x64/release/bundle" ]]; then
        cp apps/tunnel_manager/build/linux/x64/release/bundle/cloudtolocalllm_tunnel_manager "$PACKAGE_DIR/bin/"
        # Copy additional libraries from tunnel manager
        cp -n apps/tunnel_manager/build/linux/x64/release/bundle/lib/* "$PACKAGE_DIR/lib/" 2>/dev/null || true
    fi
    
    # Copy main chat app if available
    if [[ -d "apps/main/build/linux/x64/release/bundle" ]]; then
        cp apps/main/build/linux/x64/release/bundle/cloudtolocalllm_main "$PACKAGE_DIR/bin/"
        # Copy additional libraries from main chat app
        cp -n apps/main/build/linux/x64/release/bundle/lib/* "$PACKAGE_DIR/lib/" 2>/dev/null || true
    fi
    

    
    log_success "Package structure created"
}

# Create wrapper scripts
create_wrapper_scripts() {
    log_info "Creating wrapper scripts..."
    
    # Main wrapper script
    cat > "$PACKAGE_DIR/bin/cloudtolocalllm" << EOF
#!/bin/bash
# CloudToLocalLLM v$VERSION unified wrapper script
# Launches main Flutter application

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Set library path
export LD_LIBRARY_PATH="$APP_DIR/lib:$LD_LIBRARY_PATH"

# Launch main Flutter application
if [[ -x "$SCRIPT_DIR/cloudtolocalllm_main" ]]; then
    exec "$SCRIPT_DIR/cloudtolocalllm_main" "$@"
else
    echo "Error: Main application not found"
    exit 1
fi
EOF
    
    chmod +x "$PACKAGE_DIR/bin/cloudtolocalllm"
    
    # Create individual app launchers
    for app in cloudtolocalllm_main cloudtolocalllm_tunnel_manager; do
        if [[ -f "$PACKAGE_DIR/bin/$app" ]]; then
            cat > "$PACKAGE_DIR/bin/${app%-*}" << EOF
#!/bin/bash
SCRIPT_DIR="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="\$(cd "\$SCRIPT_DIR/.." && pwd)"
export LD_LIBRARY_PATH="\$APP_DIR/lib:\$LD_LIBRARY_PATH"
exec "\$SCRIPT_DIR/$app" "\$@"
EOF
            chmod +x "$PACKAGE_DIR/bin/${app%-*}"
        fi
    done
    
    log_success "Wrapper scripts created"
}

# Main build function
main() {
    log_info "Starting CloudToLocalLLM unified package build v$VERSION"
    
    check_prerequisites
    clean_builds
    build_main_app
    build_tunnel_manager
    build_main_chat
    create_package_structure
    create_wrapper_scripts
    
    # Create version info
    echo "$VERSION" > "$PACKAGE_DIR/VERSION"

    # Create tar.gz archive for distribution
    log_info "Creating distribution archive..."
    local archive_name="cloudtolocalllm-${VERSION}-x86_64.tar.gz"
    local archive_path="$PROJECT_ROOT/dist/$archive_name"

    # Ensure dist directory exists
    mkdir -p "$PROJECT_ROOT/dist"

    # Create the archive from the package directory
    cd "$DIST_DIR"
    if tar -czf "$archive_path" "$(basename "$PACKAGE_DIR")"; then
        log_success "Distribution archive created: $archive_path"

        # Create SHA256 checksum
        cd "$PROJECT_ROOT/dist"
        sha256sum "$archive_name" > "${archive_name}.sha256"
        log_success "SHA256 checksum created: ${archive_name}.sha256"
    else
        log_error "Failed to create distribution archive"
        exit 1
    fi

    cd "$PROJECT_ROOT"

    log_success "Unified package build completed successfully!"
    log_info "Package location: $PACKAGE_DIR"
    log_info "Distribution archive: $archive_path"
    log_info "To install: sudo cp -r $PACKAGE_DIR /usr/share/cloudtolocalllm"
    log_info "To create symlinks: sudo ln -sf /usr/share/cloudtolocalllm/bin/* /usr/bin/"
}

# Run main function
main "$@"
