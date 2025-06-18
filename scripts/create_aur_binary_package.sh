#!/bin/bash
# Create binary package for AUR distribution
# This script packages the Flutter app and tray daemon for AUR

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

# Get version from version manager
VERSION=$("$PROJECT_ROOT/scripts/version_manager.sh" get-semantic)

BUILD_DIR="$PROJECT_ROOT/build/linux/x64/release/bundle"
DAEMON_EXECUTABLE="$PROJECT_ROOT/dist/tray_daemon/linux-x64/cloudtolocalllm-tray"
OUTPUT_DIR="$PROJECT_ROOT/dist"
PACKAGE_NAME="cloudtolocalllm-$VERSION-x86_64"

echo -e "${BLUE}CloudToLocalLLM AUR Binary Package Creator${NC}"
echo -e "${BLUE}===========================================${NC}"
echo "Version: $VERSION"
echo "Output: $OUTPUT_DIR/$PACKAGE_NAME.tar.gz"
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

# Check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."

    # Check if Flutter app is built
    if [ ! -f "$BUILD_DIR/cloudtolocalllm" ]; then
        print_error "Flutter app not found: $BUILD_DIR/cloudtolocalllm"
        print_error "Please run: flutter build linux --release"
        exit 1
    fi

    # Check if daemon is built (optional for unified architecture)
    if [ ! -f "$DAEMON_EXECUTABLE" ]; then
        print_warning "Tray daemon not found: $DAEMON_EXECUTABLE"
        print_warning "Creating package without separate tray daemon (unified architecture)"
        DAEMON_EXECUTABLE=""
    fi

    print_status "Prerequisites check passed"
}

# Create package directory structure
create_package_structure() {
    print_status "Creating package structure..."
    
    # Create temporary package directory
    PACKAGE_DIR="$OUTPUT_DIR/$PACKAGE_NAME"
    rm -rf "$PACKAGE_DIR"
    mkdir -p "$PACKAGE_DIR"
    
    print_status "Package directory created: $PACKAGE_DIR"
}

# Copy Flutter application files
copy_flutter_app() {
    print_status "Copying Flutter application files..."
    
    # Copy all Flutter app files
    cp -r "$BUILD_DIR"/* "$PACKAGE_DIR/"
    
    # Verify main executable
    if [ ! -f "$PACKAGE_DIR/cloudtolocalllm" ]; then
        print_error "Failed to copy Flutter app executable"
        exit 1
    fi
    
    # Make executable
    chmod +x "$PACKAGE_DIR/cloudtolocalllm"
    
    print_status "Flutter app files copied successfully"
}

# Copy tray daemon
copy_tray_daemon() {
    if [ -n "$DAEMON_EXECUTABLE" ] && [ -f "$DAEMON_EXECUTABLE" ]; then
        print_status "Copying tray daemon..."

        # Copy daemon executable
        cp "$DAEMON_EXECUTABLE" "$PACKAGE_DIR/cloudtolocalllm-tray"

        # Make executable
        chmod +x "$PACKAGE_DIR/cloudtolocalllm-tray"

        # Verify daemon
        if [ ! -f "$PACKAGE_DIR/cloudtolocalllm-tray" ]; then
            print_error "Failed to copy tray daemon"
            exit 1
        fi

        print_status "Tray daemon copied successfully"
    else
        print_status "Skipping tray daemon copy (unified architecture)"
    fi
}

# Create package archive
create_archive() {
    print_status "Creating package archive..."
    
    cd "$OUTPUT_DIR"
    
    # Create tar.gz archive
    tar -czf "$PACKAGE_NAME.tar.gz" "$PACKAGE_NAME"
    
    # Verify archive was created
    if [ ! -f "$PACKAGE_NAME.tar.gz" ]; then
        print_error "Failed to create package archive"
        exit 1
    fi
    
    # Get archive size
    local size=$(du -h "$PACKAGE_NAME.tar.gz" | cut -f1)
    print_status "Package archive created: $PACKAGE_NAME.tar.gz ($size)"
    
    # Clean up temporary directory
    rm -rf "$PACKAGE_NAME"
    
    cd "$PROJECT_ROOT"
}

# Generate checksums
generate_checksums() {
    print_status "Generating checksums..."
    
    cd "$OUTPUT_DIR"
    
    # Generate SHA256 checksum
    sha256sum "$PACKAGE_NAME.tar.gz" > "$PACKAGE_NAME.tar.gz.sha256"
    
    # Generate MD5 checksum
    md5sum "$PACKAGE_NAME.tar.gz" > "$PACKAGE_NAME.tar.gz.md5"
    
    print_status "Checksums generated:"
    print_status "  SHA256: $PACKAGE_NAME.tar.gz.sha256"
    print_status "  MD5: $PACKAGE_NAME.tar.gz.md5"
    
    cd "$PROJECT_ROOT"
}

# Test package contents
test_package() {
    print_status "Testing package contents..."
    
    cd "$OUTPUT_DIR"
    
    # Extract to temporary directory for testing
    local test_dir="test_$PACKAGE_NAME"
    rm -rf "$test_dir"
    mkdir "$test_dir"
    
    tar -xzf "$PACKAGE_NAME.tar.gz" -C "$test_dir"
    
    # Check required files
    local required_files=(
        "cloudtolocalllm"
        "data/flutter_assets/AssetManifest.json"
        "lib/libapp.so"
    )

    # Add tray daemon to required files if it exists
    if [ -n "$DAEMON_EXECUTABLE" ] && [ -f "$DAEMON_EXECUTABLE" ]; then
        required_files+=("cloudtolocalllm-tray")
    fi
    
    local missing_files=0
    for file in "${required_files[@]}"; do
        if [ ! -f "$test_dir/$PACKAGE_NAME/$file" ]; then
            print_error "Missing required file: $file"
            missing_files=$((missing_files + 1))
        fi
    done
    
    if [ $missing_files -eq 0 ]; then
        print_status "All required files present in package"
    else
        print_error "$missing_files required files missing"
        exit 1
    fi
    
    # Test executables
    if [ -x "$test_dir/$PACKAGE_NAME/cloudtolocalllm" ]; then
        print_status "Flutter app executable is valid"
    else
        print_error "Flutter app is not executable"
        exit 1
    fi
    
    if [ -f "$test_dir/$PACKAGE_NAME/cloudtolocalllm-tray" ]; then
        if [ -x "$test_dir/$PACKAGE_NAME/cloudtolocalllm-tray" ]; then
            print_status "Tray daemon executable is valid"
        else
            print_error "Tray daemon is not executable"
            exit 1
        fi
    else
        print_status "Tray daemon not included (unified architecture)"
    fi
    
    # Clean up test directory
    rm -rf "$test_dir"
    
    cd "$PROJECT_ROOT"
}

# Display package information
display_package_info() {
    print_status "Package information:"
    echo ""
    echo -e "${GREEN}Package Details:${NC}"
    echo "  Name: $PACKAGE_NAME"
    echo "  Version: $VERSION"
    echo "  Architecture: x86_64"
    echo "  Location: $OUTPUT_DIR/$PACKAGE_NAME.tar.gz"
    echo ""
    
    cd "$OUTPUT_DIR"
    local size=$(du -h "$PACKAGE_NAME.tar.gz" | cut -f1)
    echo -e "${GREEN}File Information:${NC}"
    echo "  Size: $size"
    echo "  SHA256: $(cat "$PACKAGE_NAME.tar.gz.sha256" | cut -d' ' -f1)"
    echo "  MD5: $(cat "$PACKAGE_NAME.tar.gz.md5" | cut -d' ' -f1)"
    echo ""
    
    echo -e "${GREEN}Contents:${NC}"
    echo "  ✅ Flutter application (cloudtolocalllm)"
    echo "  ✅ System tray daemon (cloudtolocalllm-tray)"
    echo "  ✅ Application data and libraries"
    echo "  ✅ Flutter assets and fonts"
    echo ""
    
    echo -e "${GREEN}Usage:${NC}"
    echo "  1. Upload $PACKAGE_NAME.tar.gz to cloudtolocalllm.online"
    echo "  2. Update AUR PKGBUILD with new version and checksum"
    echo "  3. Test AUR package installation"
    echo ""
    
    cd "$PROJECT_ROOT"
}

# Manage binary files for GitHub compatibility
manage_binary_files() {
    print_status "Managing binary files for GitHub compatibility..."

    # Skip binary file management during package creation to avoid conflicts
    print_status "Skipping binary file management during package creation"
}

# Main execution
main() {
    manage_binary_files
    check_prerequisites
    create_package_structure
    copy_flutter_app
    copy_tray_daemon
    create_archive
    generate_checksums
    test_package
    display_package_info

    echo -e "${GREEN}✅ AUR binary package created successfully!${NC}"
    echo -e "${GREEN}📦 Ready for distribution: $OUTPUT_DIR/$PACKAGE_NAME.tar.gz${NC}"

    # Final binary file management after package creation
    print_status "Final binary file management..."
    print_status "Skipping final binary file management - package creation complete"
}

# Run main function
main
