#!/bin/bash

# Test script for GitHub release creation
# This script tests the GitHub release workflow without actually creating a release

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
REPO_OWNER="imrightguy"
REPO_NAME="CloudToLocalLLM"

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

# Get version from pubspec.yaml
get_version() {
    if [[ -f "$PROJECT_ROOT/pubspec.yaml" ]]; then
        grep "^version:" "$PROJECT_ROOT/pubspec.yaml" | cut -d' ' -f2 | cut -d'+' -f1
    else
        print_error "pubspec.yaml not found"
        exit 1
    fi
}

# Test GitHub CLI
test_github_cli() {
    print_status "Testing GitHub CLI..."
    
    if ! command -v gh &> /dev/null; then
        print_error "GitHub CLI (gh) is not installed"
        print_error "Install with: sudo pacman -S github-cli"
        return 1
    fi
    
    if ! gh auth status &> /dev/null; then
        print_error "GitHub CLI is not authenticated"
        print_error "Run: gh auth login"
        return 1
    fi
    
    print_success "GitHub CLI is ready"
    return 0
}

# Test repository access
test_repo_access() {
    print_status "Testing repository access..."
    
    if gh repo view "$REPO_OWNER/$REPO_NAME" &> /dev/null; then
        print_success "Repository access confirmed"
        return 0
    else
        print_error "Cannot access repository $REPO_OWNER/$REPO_NAME"
        return 1
    fi
}

# Check existing releases
check_existing_releases() {
    print_status "Checking existing releases..."
    
    local version=$(get_version)
    local tag="v$version"
    
    print_status "Current version: $version"
    
    if gh release view "$tag" --repo "$REPO_OWNER/$REPO_NAME" &> /dev/null; then
        print_warning "Release $tag already exists"
        print_status "Release URL: https://github.com/$REPO_OWNER/$REPO_NAME/releases/tag/$tag"
        return 1
    else
        print_success "No existing release for $tag - ready to create"
        return 0
    fi
}

# Check binary packages
check_binary_packages() {
    print_status "Checking binary packages..."
    
    local version=$(get_version)
    local package_file="$PROJECT_ROOT/aur-package/cloudtolocalllm-$version-x86_64.tar.gz"
    local checksum_file="$package_file.sha256"
    
    if [[ -f "$package_file" ]]; then
        local size=$(du -h "$package_file" | cut -f1)
        print_success "Binary package found: $package_file ($size)"
        
        if [[ -f "$checksum_file" ]]; then
            print_success "Checksum file found: $checksum_file"
            
            # Verify checksum
            cd "$(dirname "$package_file")"
            if sha256sum -c "$(basename "$checksum_file")" &> /dev/null; then
                print_success "Package integrity verified"
            else
                print_warning "Package integrity check failed"
            fi
        else
            print_warning "Checksum file not found: $checksum_file"
        fi
    else
        print_error "Binary package not found: $package_file"
        print_status "Run: ./scripts/create_unified_aur_package.sh"
        return 1
    fi
    
    return 0
}

# Test AUR package configuration
test_aur_config() {
    print_status "Testing AUR package configuration..."
    
    local pkgbuild="$PROJECT_ROOT/aur-package/PKGBUILD"
    
    if [[ ! -f "$pkgbuild" ]]; then
        print_error "PKGBUILD not found: $pkgbuild"
        return 1
    fi
    
    # Check if PKGBUILD uses GitHub releases
    if grep -q "github.com.*releases.*download" "$pkgbuild"; then
        print_success "PKGBUILD is configured for GitHub releases"
    else
        print_warning "PKGBUILD is not configured for GitHub releases"
        print_status "Update PKGBUILD to use GitHub release URLs"
    fi
    
    # Check version consistency
    local pkgbuild_version=$(grep "^pkgver=" "$pkgbuild" | cut -d'=' -f2)
    local pubspec_version=$(get_version)
    
    if [[ "$pkgbuild_version" == "$pubspec_version" ]]; then
        print_success "Version consistency: $pkgbuild_version"
    else
        print_warning "Version mismatch: PKGBUILD=$pkgbuild_version, pubspec.yaml=$pubspec_version"
    fi
    
    return 0
}

# Main test function
main() {
    print_status "CloudToLocalLLM GitHub Release Test"
    print_status "==================================="
    
    cd "$PROJECT_ROOT"
    
    local all_tests_passed=true
    
    # Run tests
    if ! test_github_cli; then
        all_tests_passed=false
    fi
    
    if ! test_repo_access; then
        all_tests_passed=false
    fi
    
    if ! check_existing_releases; then
        # This is a warning, not a failure
        print_status "Note: Release already exists"
    fi
    
    if ! check_binary_packages; then
        all_tests_passed=false
    fi
    
    if ! test_aur_config; then
        # This is informational, not a failure
        print_status "Note: AUR configuration needs attention"
    fi
    
    # Summary
    echo
    print_status "Test Summary:"
    if [[ "$all_tests_passed" == "true" ]]; then
        print_success "✅ All critical tests passed"
        print_success "Ready to create GitHub release!"
        print_status "Run: ./scripts/release/create_github_release.sh"
    else
        print_error "❌ Some tests failed"
        print_status "Fix the issues above before creating a release"
    fi
    
    return 0
}

# Execute main function
main "$@"
