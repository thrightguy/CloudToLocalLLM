#!/bin/bash

# CloudToLocalLLM AUR Package Testing Script v3.5.5+
# Automated testing of AUR package build and installation
# Supports non-interactive execution for CI/CD pipelines
# Enhanced with robust timeout handling and error recovery

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
AUR_DIR="$PROJECT_ROOT/aur-package"
TEMP_TEST_DIR="/tmp/cloudtolocalllm-aur-test-$$"

# Load deployment utilities if available
if [[ -f "$SCRIPT_DIR/deployment_utils.sh" ]]; then
    source "$SCRIPT_DIR/deployment_utils.sh"
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Flags
DRY_RUN=false
VERBOSE=false
SKIP_INSTALL=false
FORCE=false

# Logging functions
log() {
    echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[$(date '+%H:%M:%S')] ✅${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[$(date '+%H:%M:%S')] ⚠️${NC} $1"
}

log_error() {
    echo -e "${RED}[$(date '+%H:%M:%S')] ❌${NC} $1"
}

log_verbose() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "${BLUE}[$(date '+%H:%M:%S')] [VERBOSE]${NC} $1"
    fi
}

# Usage information
show_usage() {
    cat << EOF
CloudToLocalLLM AUR Package Testing Script

USAGE:
    $0 [OPTIONS]

OPTIONS:
    --dry-run           Test package build without installation
    --verbose           Enable detailed logging
    --skip-install      Build package but skip installation test
    --force             Force operations without confirmation
    --help              Show this help message

EXAMPLES:
    $0                  # Full test with installation
    $0 --dry-run        # Test build only
    $0 --verbose        # Detailed logging
    $0 --skip-install   # Build without install test

EXIT CODES:
    0 - Success
    1 - General error
    2 - Validation failure
    3 - Build failure
    4 - Installation failure
EOF
}

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run)
                DRY_RUN=true
                SKIP_INSTALL=true
                shift
                ;;
            --verbose)
                VERBOSE=true
                shift
                ;;
            --skip-install)
                SKIP_INSTALL=true
                shift
                ;;
            --force)
                FORCE=true
                shift
                ;;
            --help)
                show_usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
}

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."

    # Check if we're on Arch Linux or have makepkg
    if ! command -v makepkg &> /dev/null; then
        log_error "makepkg not found. This script requires Arch Linux or makepkg."
        exit 2
    fi

    # Check if AUR directory exists
    if [[ ! -d "$AUR_DIR" ]]; then
        log_error "AUR package directory not found: $AUR_DIR"
        exit 2
    fi

    # Check if PKGBUILD exists
    if [[ ! -f "$AUR_DIR/PKGBUILD" ]]; then
        log_error "PKGBUILD not found in $AUR_DIR"
        exit 2
    fi

    log_success "Prerequisites check passed"
}

# Validate PKGBUILD
validate_pkgbuild() {
    log "Validating PKGBUILD..."

    cd "$AUR_DIR"

    # Extract version from PKGBUILD
    local pkgver=$(grep "^pkgver=" PKGBUILD | cut -d'=' -f2)
    local expected_version=$(grep '^version:' "$PROJECT_ROOT/pubspec.yaml" | sed 's/version: *\([0-9.]*\).*/\1/')

    log_verbose "PKGBUILD version: $pkgver"
    log_verbose "Expected version: $expected_version"

    if [[ "$pkgver" != "$expected_version" ]]; then
        log_error "Version mismatch: PKGBUILD has $pkgver, expected $expected_version"
        exit 2
    fi

    # Validate PKGBUILD syntax
    if ! makepkg --printsrcinfo > /dev/null 2>&1; then
        log_error "PKGBUILD syntax validation failed"
        exit 2
    fi

    log_success "PKGBUILD validation passed"
}

# Create test environment
create_test_environment() {
    log "Creating test environment..."

    # Clean up any existing test directory
    rm -rf "$TEMP_TEST_DIR"
    mkdir -p "$TEMP_TEST_DIR"

    # Copy AUR package files to test directory
    cp -r "$AUR_DIR"/* "$TEMP_TEST_DIR/"

    log_verbose "Test environment created at: $TEMP_TEST_DIR"
    log_success "Test environment ready"
}

# Build package
build_package() {
    log "Building AUR package..."

    cd "$TEMP_TEST_DIR"

    # Clean any previous builds
    rm -rf src/ pkg/ *.pkg.tar.zst

    if [[ "$DRY_RUN" == "true" ]]; then
        log "DRY RUN: Would build package with: makepkg --noconfirm"
        log_success "DRY RUN: Package build simulation completed"
        return 0
    fi

    # Build package with timeout to prevent hanging
    local build_timeout=1800  # 30 minutes for makepkg

    if [[ "$VERBOSE" == "true" ]]; then
        if ! timeout $build_timeout makepkg --noconfirm; then
            log_error "Package build timed out or failed"
            exit 3
        fi
    else
        if ! timeout $build_timeout makepkg --noconfirm > /dev/null 2>&1; then
            log_error "Package build timed out or failed"
            exit 3
        fi
    fi

    # Verify package was created
    local package_file=$(ls *.pkg.tar.zst 2>/dev/null | head -1)
    if [[ -z "$package_file" ]]; then
        log_error "Package file not found after build"
        exit 3
    fi

    log_verbose "Package created: $package_file"
    log_success "Package build completed"
}

# Generate .SRCINFO
generate_srcinfo() {
    log "Generating .SRCINFO..."

    cd "$TEMP_TEST_DIR"

    if [[ "$DRY_RUN" == "true" ]]; then
        log "DRY RUN: Would generate .SRCINFO with: makepkg --printsrcinfo"
        log_success "DRY RUN: .SRCINFO generation simulation completed"
        return 0
    fi

    # Generate .SRCINFO
    makepkg --printsrcinfo > .SRCINFO

    # Verify .SRCINFO was created
    if [[ ! -f ".SRCINFO" ]]; then
        log_error ".SRCINFO file not created"
        exit 3
    fi

    # Copy .SRCINFO back to AUR directory
    cp .SRCINFO "$AUR_DIR/"

    log_success ".SRCINFO generated and copied to AUR directory"
}

# Test package installation
test_installation() {
    if [[ "$SKIP_INSTALL" == "true" ]]; then
        log "Skipping installation test (--skip-install flag)"
        return 0
    fi

    log "Testing package installation..."

    cd "$TEMP_TEST_DIR"

    local package_file=$(ls *.pkg.tar.zst 2>/dev/null | head -1)
    if [[ -z "$package_file" ]]; then
        log_error "No package file found for installation test"
        exit 4
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        log "DRY RUN: Would install package with: sudo pacman -U $package_file --noconfirm"
        log_success "DRY RUN: Package installation simulation completed"
        return 0
    fi

    # Install package with timeout
    if [[ "$FORCE" == "true" ]]; then
        local install_timeout=300  # 5 minutes for package installation
        if ! timeout $install_timeout sudo pacman -U "$package_file" --noconfirm; then
            log_error "Package installation timed out or failed"
            exit 4
        fi
    else
        log_warning "Package installation requires sudo privileges"
        log "Install command: sudo pacman -U $package_file --noconfirm"
        log "Run with --force to execute automatically"
        return 0
    fi

    # Test if binary is available
    if command -v cloudtolocalllm &> /dev/null; then
        log_success "Package installation test passed"
    else
        log_error "Package installation failed - binary not found in PATH"
        exit 4
    fi
}

# Validate package integrity
validate_package_integrity() {
    log "Validating package integrity..."

    cd "$TEMP_TEST_DIR"

    local package_file=$(ls *.pkg.tar.zst 2>/dev/null | head -1)
    if [[ -z "$package_file" ]]; then
        log_warning "No package file found for integrity validation"
        return 0
    fi

    # Extract and examine package contents
    local extract_dir="package_contents"
    mkdir -p "$extract_dir"
    tar -xf "$package_file" -C "$extract_dir"

    # Check for required files
    local required_files=(
        "usr/bin/cloudtolocalllm"
        "usr/share/cloudtolocalllm/cloudtolocalllm"
        "usr/share/applications/cloudtolocalllm.desktop"
    )

    for file in "${required_files[@]}"; do
        if [[ ! -f "$extract_dir/$file" ]]; then
            log_error "Required file missing from package: $file"
            exit 2
        fi
        log_verbose "✓ Required file present: $file"
    done

    log_success "Package integrity validation passed"
}

# Cleanup
cleanup() {
    if [[ -d "$TEMP_TEST_DIR" ]]; then
        log "Cleaning up test environment..."
        rm -rf "$TEMP_TEST_DIR"
        log_success "Cleanup completed"
    fi
}

# Main execution
main() {
    # Header
    echo -e "${BLUE}CloudToLocalLLM AUR Package Testing${NC}"
    echo -e "${BLUE}====================================${NC}"
    echo "Test Directory: $TEMP_TEST_DIR"
    echo "AUR Directory: $AUR_DIR"
    echo "Dry Run: $DRY_RUN"
    echo "Skip Install: $SKIP_INSTALL"
    echo ""

    # Set up cleanup trap
    trap cleanup EXIT

    # Execute test phases
    check_prerequisites
    validate_pkgbuild
    create_test_environment
    build_package
    generate_srcinfo
    validate_package_integrity
    test_installation

    echo ""
    log_success "🎉 AUR package testing completed successfully!"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "${YELLOW}📋 DRY RUN completed - no actual changes made${NC}"
    fi
    
    echo -e "${GREEN}📦 Package ready for AUR submission${NC}"
}

# Enhanced error handling with cleanup
cleanup_on_error() {
    local exit_code=$?
    log_error "Script failed at line $LINENO with exit code $exit_code"
    log_error "Check logs above for details"

    # Cleanup test environment
    cleanup

    exit $exit_code
}

# Setup signal handlers for graceful shutdown
if command -v setup_signal_handlers &> /dev/null; then
    setup_signal_handlers cleanup
fi

trap 'cleanup_on_error' ERR

# Parse arguments and execute
parse_arguments "$@"
main "$@"
