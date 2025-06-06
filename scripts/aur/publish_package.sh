#!/bin/bash

# CloudToLocalLLM AUR Package Publication Automation Script
# Handles complete AUR publication workflow with error handling and rollback

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
AUR_PACKAGE_DIR="$PROJECT_ROOT/aur-package"
BACKUP_DIR="/tmp/cloudtolocalllm-aur-backup-$(date +%s)"

# Default options
AUTO_MODE="false"
FORCE_PUBLISH="false"
SKIP_TESTS="false"
DRY_RUN="false"

# Functions
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_step() {
    echo -e "\n${GREEN}=== $1 ===${NC}"
}

# Show usage information
show_usage() {
    echo "CloudToLocalLLM AUR Package Publication Script"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --auto              Run without interactive confirmation"
    echo "  --force             Force publication even with uncommitted changes"
    echo "  --skip-tests        Skip local package testing"
    echo "  --dry-run           Show what would be done without executing"
    echo "  --help              Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                           # Interactive mode with full testing"
    echo "  $0 --auto                    # Automated publication"
    echo "  $0 --auto --skip-tests       # Fast automated publication"
    echo "  $0 --dry-run                 # Preview actions without execution"
}

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --auto)
                AUTO_MODE="true"
                shift
                ;;
            --force)
                FORCE_PUBLISH="true"
                shift
                ;;
            --skip-tests)
                SKIP_TESTS="true"
                shift
                ;;
            --dry-run)
                DRY_RUN="true"
                shift
                ;;
            --help)
                show_usage
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
}

# Get current version
get_version() {
    if [[ -f "$PROJECT_ROOT/version.txt" ]]; then
        cat "$PROJECT_ROOT/version.txt" | tr -d '\n'
    else
        print_error "version.txt not found"
        exit 1
    fi
}

# Create backup of current AUR package state
create_backup() {
    print_step "Creating Backup"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        print_status "DRY RUN: Would create backup at $BACKUP_DIR"
        return 0
    fi
    
    mkdir -p "$BACKUP_DIR"
    
    if [[ -d "$AUR_PACKAGE_DIR/.git" ]]; then
        cp -r "$AUR_PACKAGE_DIR" "$BACKUP_DIR/"
        print_success "Backup created at $BACKUP_DIR"
    else
        print_warning "No git repository found in AUR package directory"
    fi
}

# Restore from backup
restore_backup() {
    print_error "Restoring from backup due to error..."
    
    if [[ -d "$BACKUP_DIR/aur-package" ]]; then
        rm -rf "$AUR_PACKAGE_DIR"
        cp -r "$BACKUP_DIR/aur-package" "$AUR_PACKAGE_DIR"
        print_success "Backup restored successfully"
    else
        print_error "Backup not found, manual recovery may be required"
    fi
}

# Check prerequisites
check_prerequisites() {
    print_step "Checking Prerequisites"
    
    # Check if we're in the right directory structure
    if [[ ! -d "$AUR_PACKAGE_DIR" ]]; then
        print_error "AUR package directory not found: $AUR_PACKAGE_DIR"
        exit 1
    fi
    
    # Check for required files
    if [[ ! -f "$AUR_PACKAGE_DIR/PKGBUILD" ]]; then
        print_error "PKGBUILD not found in AUR package directory"
        exit 1
    fi
    
    # Check git repository
    cd "$AUR_PACKAGE_DIR"
    if [[ ! -d ".git" ]]; then
        print_error "AUR package directory is not a git repository"
        print_status "Please clone the AUR repository first:"
        print_status "git clone ssh://aur@aur.archlinux.org/cloudtolocalllm.git"
        exit 1
    fi
    
    # Check for uncommitted changes (unless forced)
    if [[ "$FORCE_PUBLISH" != "true" ]]; then
        if ! git diff-index --quiet HEAD --; then
            print_error "Uncommitted changes detected in AUR package directory"
            print_status "Use --force to publish anyway, or commit changes first"
            exit 1
        fi
    fi
    
    # Check required tools
    local required_tools=("makepkg" "git" "yay")
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            print_error "Required tool not found: $tool"
            exit 1
        fi
    done
    
    print_success "All prerequisites satisfied"
}

# Generate .SRCINFO
generate_srcinfo() {
    print_step "Generating .SRCINFO"
    
    cd "$AUR_PACKAGE_DIR"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        print_status "DRY RUN: Would generate .SRCINFO from PKGBUILD"
        return 0
    fi
    
    makepkg --printsrcinfo > .SRCINFO
    
    # Verify .SRCINFO was generated correctly
    if [[ ! -f ".SRCINFO" ]]; then
        print_error "Failed to generate .SRCINFO"
        exit 1
    fi
    
    local version=$(get_version)
    if ! grep -q "pkgver = $version" .SRCINFO; then
        print_error ".SRCINFO does not contain expected version: $version"
        exit 1
    fi
    
    print_success ".SRCINFO generated successfully"
}

# Test package build
test_package_build() {
    if [[ "$SKIP_TESTS" == "true" ]]; then
        print_step "Skipping Package Tests"
        print_warning "Package testing skipped due to --skip-tests flag"
        return 0
    fi
    
    print_step "Testing Package Build"
    
    cd "$AUR_PACKAGE_DIR"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        print_status "DRY RUN: Would test package build with makepkg"
        return 0
    fi
    
    # Clean any previous build artifacts
    rm -rf src pkg *.pkg.tar.zst
    
    # Test build
    print_status "Building package for testing..."
    makepkg -f --noconfirm
    
    # Verify package was created
    local pkg_file=$(find . -name "*.pkg.tar.zst" -type f | head -1)
    if [[ -z "$pkg_file" ]]; then
        print_error "Package build failed - no .pkg.tar.zst file found"
        exit 1
    fi
    
    print_success "Package built successfully: $(basename "$pkg_file")"
    
    # Clean up test artifacts
    rm -rf src pkg *.pkg.tar.zst
}

# Commit and push to AUR
publish_to_aur() {
    print_step "Publishing to AUR"
    
    cd "$AUR_PACKAGE_DIR"
    local version=$(get_version)
    
    if [[ "$DRY_RUN" == "true" ]]; then
        print_status "DRY RUN: Would commit and push to AUR repository"
        print_status "DRY RUN: Commit message: 'Update to v$version: Multi-app Flutter architecture with GitHub releases'"
        return 0
    fi
    
    # Stage files
    git add PKGBUILD .SRCINFO
    
    # Create commit
    git commit -m "Update to v$version: Multi-app Flutter architecture with GitHub releases

- Update to CloudToLocalLLM v$version with multi-app architecture
- Add support for main, chat, tray, and settings applications
- Switch to GitHub releases for binary distribution
- Update package structure for new build system
- Maintain unified wrapper script for seamless user experience
- All executables properly installed and functional

Architecture: Multi-app Flutter package with system tray integration
Distribution: GitHub releases with automated checksum verification"
    
    # Push to AUR
    print_status "Pushing to AUR repository..."
    git push origin master
    
    print_success "Successfully published to AUR"
}

# Verify publication
verify_publication() {
    print_step "Verifying Publication"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        print_status "DRY RUN: Would verify AUR package publication"
        return 0
    fi
    
    print_status "Waiting for AUR indexing (30 seconds)..."
    sleep 30
    
    # Check if package is available
    print_status "Checking package availability..."
    if yay -Ss cloudtolocalllm | grep -q "cloudtolocalllm"; then
        print_success "Package is available in AUR"
    else
        print_warning "Package may not be indexed yet (this can take a few minutes)"
    fi
}

# Install and test published package
install_and_test() {
    if [[ "$SKIP_TESTS" == "true" ]]; then
        print_step "Skipping Installation Test"
        print_warning "Installation testing skipped due to --skip-tests flag"
        return 0
    fi
    
    print_step "Installing and Testing Published Package"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        print_status "DRY RUN: Would install package with: yay -S cloudtolocalllm --noconfirm"
        return 0
    fi
    
    # Install the package
    print_status "Installing cloudtolocalllm from AUR..."
    yay -S cloudtolocalllm --noconfirm
    
    # Verify installation
    if command -v cloudtolocalllm &> /dev/null; then
        print_success "Package installed successfully"
        print_status "Available executables:"
        ls -la /usr/bin/cloudtolocalllm*
    else
        print_error "Package installation verification failed"
        exit 1
    fi
}

# Cleanup backup
cleanup_backup() {
    if [[ -d "$BACKUP_DIR" ]] && [[ "$DRY_RUN" != "true" ]]; then
        rm -rf "$BACKUP_DIR"
        print_status "Backup cleaned up"
    fi
}

# Main execution function
main() {
    parse_arguments "$@"
    
    print_step "CloudToLocalLLM AUR Package Publication"
    print_status "Version: $(get_version)"
    print_status "Mode: $([ "$AUTO_MODE" == "true" ] && echo "Automated" || echo "Interactive")"
    print_status "Dry Run: $([ "$DRY_RUN" == "true" ] && echo "Yes" || echo "No")"
    
    # Confirmation for non-auto mode
    if [[ "$AUTO_MODE" != "true" ]] && [[ "$DRY_RUN" != "true" ]]; then
        echo ""
        read -p "Proceed with AUR publication? (y/N): " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_status "Publication cancelled by user"
            exit 0
        fi
    fi
    
    # Set up error handling with backup restoration
    if [[ "$DRY_RUN" != "true" ]]; then
        trap 'restore_backup; exit 1' ERR
    fi
    
    # Execute workflow steps
    create_backup
    check_prerequisites
    generate_srcinfo
    test_package_build
    publish_to_aur
    verify_publication
    install_and_test
    cleanup_backup
    
    print_success "🎉 AUR package publication completed successfully!"
    print_status ""
    print_status "Package Details:"
    print_status "  • Name: cloudtolocalllm"
    print_status "  • Version: $(get_version)"
    print_status "  • Install: yay -S cloudtolocalllm"
    print_status "  • Launch: cloudtolocalllm"
    print_status ""
    print_status "Next Steps:"
    print_status "  1. Test application functionality"
    print_status "  2. Verify system tray integration"
    print_status "  3. Test tunnel/proxy connectivity"
    print_status "  4. Document any issues for next iteration"
}

# Execute main function
main "$@"
