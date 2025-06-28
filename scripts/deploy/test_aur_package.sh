#!/bin/bash

# CloudToLocalLLM AUR Package Testing Script
# Tests AUR package installation and functionality
# Version: 1.0.0

set -euo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Flags
VERBOSE=false
DRY_RUN=false
SKIP_INSTALL=false

# Logging functions
log() {
    echo -e "${BLUE}[$(date '+%H:%M:%S')] [AUR-TEST]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[$(date '+%H:%M:%S')] [AUR-TEST] ✅${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[$(date '+%H:%M:%S')] [AUR-TEST] ⚠️${NC} $1"
}

log_error() {
    echo -e "${RED}[$(date '+%H:%M:%S')] [AUR-TEST] ❌${NC} $1"
}

log_verbose() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "${BLUE}[$(date '+%H:%M:%S')] [AUR-TEST] [VERBOSE]${NC} $1"
    fi
}

# Usage information
show_usage() {
    cat << EOF
CloudToLocalLLM AUR Package Testing Script

USAGE:
    $0 [OPTIONS]

OPTIONS:
    --skip-install      Skip actual package installation (test package metadata only)
    --verbose           Enable detailed logging
    --dry-run           Simulate testing without actual operations
    --help              Show this help message

EXAMPLES:
    $0                  # Full AUR package test with installation
    $0 --skip-install   # Test package metadata only
    $0 --verbose        # Detailed logging
    $0 --dry-run        # Simulate testing

EXIT CODES:
    0 - Success
    1 - General error
    2 - Package not found
    3 - Installation failure
    4 - Functionality test failure
EOF
}

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --skip-install)
                SKIP_INSTALL=true
                shift
                ;;
            --verbose)
                VERBOSE=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
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

# Check if running on Arch Linux or if yay is available
check_aur_environment() {
    log "Checking AUR testing environment..."

    if [[ "$DRY_RUN" == "true" ]]; then
        log "DRY RUN: Would check AUR environment"
        return 0
    fi

    # Check if yay is available
    if ! command -v yay &> /dev/null; then
        log_error "yay AUR helper not found"
        log_error "Please install yay: https://github.com/Jguer/yay"
        return 1
    fi

    log_verbose "✓ yay AUR helper available"

    # Check if we're on Arch Linux
    if [[ -f /etc/arch-release ]]; then
        log_verbose "✓ Running on Arch Linux"
    else
        log_warning "Not running on Arch Linux - AUR testing may not work correctly"
    fi

    log_success "AUR testing environment validated"
    return 0
}

# Get current version from project
get_current_version() {
    local version
    if [[ -f "$PROJECT_ROOT/scripts/version_manager.sh" ]]; then
        version=$("$PROJECT_ROOT/scripts/version_manager.sh" get-semantic 2>/dev/null || echo "unknown")
    else
        version=$(grep '^version:' "$PROJECT_ROOT/pubspec.yaml" | sed 's/version: *\([0-9.]*\).*/\1/' || echo "unknown")
    fi
    echo "$version"
}

# Test AUR package metadata
test_package_metadata() {
    local version="$1"

    log "Testing AUR package metadata for version $version..."

    if [[ "$DRY_RUN" == "true" ]]; then
        log "DRY RUN: Would test package metadata"
        return 0
    fi

    # Check if package exists in AUR
    log_verbose "Checking if cloudtolocalllm package exists in AUR..."
    if ! yay -Si cloudtolocalllm &> /dev/null; then
        log_error "cloudtolocalllm package not found in AUR"
        return 2
    fi

    # Get package information
    local aur_version=$(yay -Si cloudtolocalllm | grep "Version" | awk '{print $3}' | cut -d'-' -f1)
    log_verbose "AUR package version: $aur_version"
    log_verbose "Expected version: $version"

    # Check if versions match (allow for build number differences)
    if [[ "$aur_version" == "$version" ]]; then
        log_success "✓ AUR package version matches expected version"
    else
        log_warning "AUR package version ($aur_version) differs from expected ($version)"
        log_warning "This may indicate the AUR package needs updating"
    fi

    log_success "Package metadata test completed"
    return 0
}

# Test AUR package installation
test_package_installation() {
    local version="$1"

    log "Testing AUR package installation for version $version..."

    if [[ "$DRY_RUN" == "true" ]]; then
        log "DRY RUN: Would test package installation"
        return 0
    fi

    if [[ "$SKIP_INSTALL" == "true" ]]; then
        log "Skipping package installation (--skip-install flag)"
        return 0
    fi

    # Clear yay cache to ensure fresh download
    log_verbose "Clearing yay cache for cloudtolocalllm..."
    yay -Sc --noconfirm &> /dev/null || true
    rm -rf ~/.cache/yay/cloudtolocalllm &> /dev/null || true

    # Install package
    log_verbose "Installing cloudtolocalllm from AUR..."
    if [[ "$VERBOSE" == "true" ]]; then
        if ! yay -S cloudtolocalllm --noconfirm; then
            log_error "Failed to install cloudtolocalllm from AUR"
            return 3
        fi
    else
        if ! yay -S cloudtolocalllm --noconfirm &> /dev/null; then
            log_error "Failed to install cloudtolocalllm from AUR"
            return 3
        fi
    fi

    log_success "✓ Package installed successfully"
    return 0
}

# Test package functionality
test_package_functionality() {
    local version="$1"

    log "Testing package functionality..."

    if [[ "$DRY_RUN" == "true" ]]; then
        log "DRY RUN: Would test package functionality"
        return 0
    fi

    if [[ "$SKIP_INSTALL" == "true" ]]; then
        log "Skipping functionality test (--skip-install flag)"
        return 0
    fi

    # Check if executable exists
    if ! command -v cloudtolocalllm &> /dev/null; then
        log_error "cloudtolocalllm executable not found in PATH"
        return 4
    fi

    log_verbose "✓ cloudtolocalllm executable found"

    # Test version command
    log_verbose "Testing version command..."
    local installed_version
    if installed_version=$(cloudtolocalllm --version 2>/dev/null | head -1); then
        log_verbose "Installed version output: $installed_version"
        log_success "✓ Version command works"
    else
        log_warning "Version command failed or returned unexpected output"
    fi

    # Test help command
    log_verbose "Testing help command..."
    if cloudtolocalllm --help &> /dev/null; then
        log_verbose "✓ Help command works"
    else
        log_warning "Help command failed"
    fi

    log_success "Package functionality test completed"
    return 0
}

# Cleanup test installation
cleanup_test_installation() {
    log "Cleaning up test installation..."

    if [[ "$DRY_RUN" == "true" ]]; then
        log "DRY RUN: Would cleanup test installation"
        return 0
    fi

    if [[ "$SKIP_INSTALL" == "true" ]]; then
        log "Skipping cleanup (--skip-install flag)"
        return 0
    fi

    # Remove installed package
    log_verbose "Removing cloudtolocalllm package..."
    if [[ "$VERBOSE" == "true" ]]; then
        yay -R cloudtolocalllm --noconfirm || true
    else
        yay -R cloudtolocalllm --noconfirm &> /dev/null || true
    fi

    log_success "Test installation cleaned up"
    return 0
}

# Main execution function
main() {
    # Parse command line arguments
    parse_arguments "$@"

    log "CloudToLocalLLM AUR Package Testing"
    log "===================================="

    # Get current version
    local version=$(get_current_version)
    log "Testing version: $version"

    # Execute test phases
    if ! check_aur_environment; then
        exit 1
    fi

    if ! test_package_metadata "$version"; then
        exit 2
    fi

    if ! test_package_installation "$version"; then
        exit 3
    fi

    if ! test_package_functionality "$version"; then
        exit 4
    fi

    # Cleanup
    cleanup_test_installation

    log_success "🎉 AUR package testing completed successfully!"

    if [[ "$DRY_RUN" == "true" ]]; then
        log "DRY RUN completed - no actual testing performed"
    fi
}

# Execute main function
main "$@"