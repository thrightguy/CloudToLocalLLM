#!/bin/bash

# CloudToLocalLLM Snap Package Build Script
# Builds Snap packages with unified version management

set -euo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
BUILD_DIR="$PROJECT_ROOT/build/snap"
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

# Check dependencies
check_dependencies() {
    log_info "Checking build dependencies..."
    
    # Check if Docker is available
    if ! command -v docker &> /dev/null; then
        log_error "Docker is required but not installed"
        exit 1
    fi
    
    # Check if Docker is running
    if ! docker info &> /dev/null; then
        log_error "Docker is not running"
        exit 1
    fi
    
    log_success "Docker is available and running"
}

# Create build environment
create_build_environment() {
    log_info "Creating Snap build environment..."
    
    # Clean previous builds
    rm -rf "$BUILD_DIR"
    mkdir -p "$BUILD_DIR"
    mkdir -p "$DIST_DIR"
    
    log_success "Build environment created"
}

# Create Docker image for Snap building
create_docker_image() {
    log_info "Building Docker image for Snap packaging..."
    
    cat > "$BUILD_DIR/Dockerfile.snap" << 'EOF'
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# Install system dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
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
    snapcraft \
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

    # Build Docker image
    docker build -f "$BUILD_DIR/Dockerfile.snap" -t cloudtolocalllm-snap-builder "$BUILD_DIR"
    
    log_success "Docker image built successfully"
}

# Create snapcraft.yaml configuration
create_snapcraft_config() {
    local version="$1"
    local build_number="$2"
    
    log_info "Creating snapcraft.yaml configuration..."
    
    mkdir -p "$BUILD_DIR/snap"
    
    cat > "$BUILD_DIR/snapcraft.yaml" << EOF
name: cloudtolocalllm
base: core22
version: '$version'
summary: Manage and run powerful Large Language Models locally
description: |
  CloudToLocalLLM enables you to manage and run powerful Large Language Models 
  locally, orchestrated via a cloud interface. Features include:
  
  - Local LLM management with Ollama integration
  - Cloud-based orchestration and monitoring
  - Cross-platform desktop application
  - System tray integration for seamless operation
  - Secure authentication and user management

grade: stable
confinement: strict

architectures:
  - build-on: amd64
    build-for: amd64

apps:
  cloudtolocalllm:
    command: bin/cloudtolocalllm
    desktop: usr/share/applications/cloudtolocalllm.desktop
    extensions: [gnome]
    plugs:
      - home
      - network
      - network-bind
      - desktop
      - desktop-legacy
      - wayland
      - x11
      - opengl
      - audio-playback
      - unity7
      - gsettings
      - browser-support

parts:
  cloudtolocalllm:
    plugin: nil
    source: .
    build-packages:
      - curl
      - git
      - unzip
      - xz-utils
      - zip
      - libgtk-3-dev
      - libayatana-appindicator3-dev
      - pkg-config
      - cmake
      - ninja-build
      - clang
    stage-packages:
      - libgtk-3-0
      - libayatana-appindicator3-1
      - libglib2.0-0
      - libgdk-pixbuf-2.0-0
      - libcairo2
      - libpango-1.0-0
      - libatk1.0-0
      - libcairo-gobject2
      - libgdk-pixbuf2.0-0
      - libpangocairo-1.0-0
    override-build: |
      # Set up Git safe directories
      git config --global --add safe.directory /opt/flutter
      git config --global --add safe.directory \$CRAFT_PART_SRC
      
      # Clean and get dependencies
      flutter clean
      flutter pub get
      
      # Build Flutter application
      flutter build linux --release
      
      # Copy built application
      mkdir -p \$CRAFT_PART_INSTALL/bin
      cp -r build/linux/x64/release/bundle/* \$CRAFT_PART_INSTALL/bin/
      
      # Make executable
      chmod +x \$CRAFT_PART_INSTALL/bin/cloudtolocalllm
      
      # Copy desktop file
      mkdir -p \$CRAFT_PART_INSTALL/usr/share/applications
      cp assets/linux/cloudtolocalllm.desktop \$CRAFT_PART_INSTALL/usr/share/applications/
      
      # Copy icons
      mkdir -p \$CRAFT_PART_INSTALL/usr/share/icons/hicolor/256x256/apps
      cp assets/images/icon.png \$CRAFT_PART_INSTALL/usr/share/icons/hicolor/256x256/apps/cloudtolocalllm.png
      
      # Generate additional icon sizes
      for size in 16 32 48 64 128; do
        mkdir -p \$CRAFT_PART_INSTALL/usr/share/icons/hicolor/\${size}x\${size}/apps
        convert assets/images/icon.png -resize \${size}x\${size} \$CRAFT_PART_INSTALL/usr/share/icons/hicolor/\${size}x\${size}/apps/cloudtolocalllm.png
      done
EOF

    log_success "snapcraft.yaml configuration created"
}

# Build Flutter application in Docker
build_flutter_app() {
    log_info "Building Flutter application in Docker container..."
    
    # Run Flutter build in Docker container
    docker run --rm \
        -v "$PROJECT_ROOT:/workspace" \
        -w /workspace \
        cloudtolocalllm-snap-builder \
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
    
    log_success "Flutter application built in Docker"
}

# Build Snap package
build_snap_package() {
    local version="$1"
    
    log_info "Building Snap package..."
    
    # Copy snapcraft.yaml to project root
    cp "$BUILD_DIR/snapcraft.yaml" "$PROJECT_ROOT/"
    
    # Build Snap package using Docker
    docker run --rm \
        -v "$PROJECT_ROOT:/workspace" \
        -w /workspace \
        --privileged \
        cloudtolocalllm-snap-builder \
        bash -c "
            set -e
            echo 'Building Snap package...'
            snapcraft --destructive-mode
        "
    
    # Move the generated snap file to dist directory
    local snap_file=$(find "$PROJECT_ROOT" -name "*.snap" -type f | head -1)
    if [[ -n "$snap_file" ]]; then
        local snap_filename="cloudtolocalllm_${version}_amd64.snap"
        mv "$snap_file" "$DIST_DIR/$snap_filename"
        log_success "Snap package created: $snap_filename"
    else
        log_error "Snap package creation failed - no .snap file found"
        exit 1
    fi
    
    # Clean up snapcraft.yaml from project root
    rm -f "$PROJECT_ROOT/snapcraft.yaml"
}

# Generate checksums
generate_checksums() {
    local version="$1"
    
    log_info "Generating checksums..."
    
    cd "$DIST_DIR"
    local snap_file="cloudtolocalllm_${version}_amd64.snap"
    
    if [[ -f "$snap_file" ]]; then
        sha256sum "$snap_file" > "${snap_file}.sha256"
        log_success "SHA256 checksum generated"
    fi
}

# Validate Snap package
validate_snap_package() {
    local version="$1"
    
    log_info "Validating Snap package..."
    
    local snap_file="$DIST_DIR/cloudtolocalllm_${version}_amd64.snap"
    
    if [[ ! -f "$snap_file" ]]; then
        log_error "Snap package not found: $snap_file"
        exit 1
    fi
    
    # Test Snap package structure using Docker
    if docker run --rm -v "$DIST_DIR:/snaps" ubuntu:22.04 bash -c "
        apt-get update && apt-get install -y snapd
        snap info /snaps/cloudtolocalllm_${version}_amd64.snap
    " &> /dev/null; then
        log_success "Snap package structure validation passed"
    else
        log_error "Snap package structure validation failed"
        exit 1
    fi
}

# Clean up build artifacts
cleanup_build_artifacts() {
    log_info "Cleaning up build artifacts..."
    
    # Remove build directory
    rm -rf "$BUILD_DIR"
    
    # Remove any leftover snapcraft files
    rm -f "$PROJECT_ROOT/snapcraft.yaml"
    rm -rf "$PROJECT_ROOT/parts"
    rm -rf "$PROJECT_ROOT/stage"
    rm -rf "$PROJECT_ROOT/prime"
    
    log_success "Build artifacts cleaned up"
}

# Generate build summary
generate_summary() {
    local version="$1"
    
    log_info "Generating build summary..."
    
    local snap_file="$DIST_DIR/cloudtolocalllm_${version}_amd64.snap"
    local file_size=""
    local sha256_hash=""
    
    if [[ -f "$snap_file" ]]; then
        file_size=$(du -h "$snap_file" | cut -f1)
        if [[ -f "${snap_file}.sha256" ]]; then
            sha256_hash=$(cut -d' ' -f1 "${snap_file}.sha256")
        fi
    fi
    
    echo
    echo "=== Snap Package Build Summary ==="
    echo "Version: $version"
    echo "Package: cloudtolocalllm_${version}_amd64.snap"
    echo "Size: $file_size"
    echo "SHA256: $sha256_hash"
    echo
    echo "Installation: sudo snap install cloudtolocalllm_${version}_amd64.snap --dangerous"
    echo "Note: Use --dangerous flag for locally built snaps"
    echo
}

# Main execution function
main() {
    local version
    
    log_info "Starting CloudToLocalLLM Snap package build process..."
    
    # Get version information
    version=$(get_version)
    local build_number=$(get_build_number)
    
    log_info "Building version: $version"
    
    # Execute build steps
    check_dependencies
    create_build_environment
    create_docker_image
    create_snapcraft_config "$version" "$build_number"
    build_flutter_app
    build_snap_package "$version"
    generate_checksums "$version"
    validate_snap_package "$version"
    cleanup_build_artifacts
    generate_summary "$version"
    
    log_success "Snap package build completed successfully!"
    log_info "Package location: $DIST_DIR/cloudtolocalllm_${version}_amd64.snap"
    log_info "SHA256 checksum: $DIST_DIR/cloudtolocalllm_${version}_amd64.snap.sha256"
}

# Handle command line arguments
case "${1:-}" in
    "--help"|"-h")
        echo "CloudToLocalLLM Snap Package Build Script"
        echo
        echo "Usage: $0 [options]"
        echo
        echo "Options:"
        echo "  --help, -h    Show this help message"
        echo
        echo "This script builds a Snap package for CloudToLocalLLM using Docker."
        echo "The version is automatically extracted from pubspec.yaml."
        exit 0
        ;;
    "")
        main
        ;;
    *)
        log_error "Unknown option: $1"
        echo "Use '$0 --help' for usage information"
        exit 1
        ;;
esac
