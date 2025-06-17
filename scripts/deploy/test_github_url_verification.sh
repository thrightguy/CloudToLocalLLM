#!/bin/bash

# CloudToLocalLLM GitHub URL Verification Test
# Tests the GitHub raw URL accessibility and checksum verification

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log() { echo -e "${BLUE}[$(date +'%H:%M:%S')]${NC} $*"; }
log_success() { echo -e "${GREEN}[$(date +'%H:%M:%S')]${NC} ✅ $*"; }
log_error() { echo -e "${RED}[$(date +'%H:%M:%S')]${NC} ❌ $*"; }
log_warning() { echo -e "${YELLOW}[$(date +'%H:%M:%S')]${NC} ⚠️ $*"; }

# Test GitHub URL verification
test_github_url_verification() {
    log "Testing GitHub raw URL verification..."
    
    cd "$PROJECT_ROOT"
    
    # Get current version
    local current_version=$(grep '^version:' pubspec.yaml | sed 's/version: *\([0-9.]*\).*/\1/')
    local package_file="cloudtolocalllm-${current_version}-x86_64.tar.gz"
    local github_url="https://raw.githubusercontent.com/imrightguy/CloudToLocalLLM/master/dist/${package_file}"
    
    log "Testing version: $current_version"
    log "Package file: $package_file"
    log "GitHub URL: $github_url"
    
    # Test 1: Check if local file exists
    if [[ -f "dist/$package_file" ]]; then
        log_success "Local package file exists"
    else
        log_error "Local package file not found: dist/$package_file"
        return 1
    fi
    
    # Test 2: Check if local SHA256 file exists
    if [[ -f "dist/${package_file}.sha256" ]]; then
        local local_sha256=$(cat "dist/${package_file}.sha256" | cut -d' ' -f1)
        log_success "Local SHA256 file exists: $local_sha256"
    else
        log_error "Local SHA256 file not found: dist/${package_file}.sha256"
        return 1
    fi
    
    # Test 3: Check GitHub URL accessibility
    log "Testing GitHub URL accessibility..."
    local http_status=$(curl -s -I "$github_url" | head -1)
    if echo "$http_status" | grep -q "200"; then
        log_success "GitHub URL is accessible ($http_status)"
    else
        log_error "GitHub URL is not accessible ($http_status)"
        log_error "This will cause AUR installation failures"
        return 1
    fi
    
    # Test 4: Verify checksum consistency
    log "Verifying checksum consistency..."
    local github_sha256=$(curl -s "$github_url" | sha256sum | cut -d' ' -f1)
    
    if [[ "$local_sha256" == "$github_sha256" ]]; then
        log_success "Checksum verification passed"
        log_success "Local:  $local_sha256"
        log_success "GitHub: $github_sha256"
    else
        log_error "Checksum mismatch detected"
        log_error "Local:  $local_sha256"
        log_error "GitHub: $github_sha256"
        return 1
    fi
    
    log_success "All GitHub URL verification tests passed"
    return 0
}

# Main execution
main() {
    echo -e "${BLUE}CloudToLocalLLM GitHub URL Verification Test${NC}"
    echo -e "${BLUE}============================================${NC}"
    echo ""
    
    if test_github_url_verification; then
        echo ""
        log_success "🎉 GitHub URL verification test completed successfully!"
        log_success "AUR package installation should work correctly"
    else
        echo ""
        log_error "❌ GitHub URL verification test failed!"
        log_error "AUR package installation will likely fail"
        exit 1
    fi
}

# Execute main function
main "$@"
