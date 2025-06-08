#!/bin/bash

# CloudToLocalLLM AUR Package Submission Script
# Submits the AUR package update following the script-first resolution principle

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
AUR_DIR="$PROJECT_ROOT/aur-package"

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

# Get current version
get_version() {
    "$PROJECT_ROOT/scripts/version_manager.sh" get-semantic
}

# Verify AUR directory and files
verify_aur_setup() {
    log "Verifying AUR package setup..."
    
    if [[ ! -d "$AUR_DIR" ]]; then
        log_error "AUR directory not found: $AUR_DIR"
        exit 1
    fi
    
    if [[ ! -f "$AUR_DIR/PKGBUILD" ]]; then
        log_error "PKGBUILD not found in AUR directory"
        exit 1
    fi
    
    # Check if it's a git repository
    if [[ ! -d "$AUR_DIR/.git" ]]; then
        log_error "AUR directory is not a git repository"
        log_error "Please clone the AUR repository first"
        exit 1
    fi
    
    log_success "AUR setup verification passed"
}

# Verify PKGBUILD version
verify_pkgbuild_version() {
    local expected_version="$1"
    
    log "Verifying PKGBUILD version..."
    
    cd "$AUR_DIR"
    local pkgbuild_version=$(grep "^pkgver=" PKGBUILD | cut -d'=' -f2)
    
    if [[ "$pkgbuild_version" != "$expected_version" ]]; then
        log_error "PKGBUILD version mismatch:"
        log_error "  Expected: $expected_version"
        log_error "  Found: $pkgbuild_version"
        log_error "Please run version synchronization first"
        exit 1
    fi
    
    log_success "PKGBUILD version verified: $pkgbuild_version"
}

# Update .SRCINFO
update_srcinfo() {
    log "Updating .SRCINFO..."
    
    cd "$AUR_DIR"
    
    if ! command -v makepkg &> /dev/null; then
        log_error "makepkg not found - required for .SRCINFO generation"
        log_error "Please install base-devel package"
        exit 1
    fi
    
    makepkg --printsrcinfo > .SRCINFO
    
    if [[ $? -eq 0 ]]; then
        log_success ".SRCINFO updated successfully"
    else
        log_error "Failed to update .SRCINFO"
        exit 1
    fi
}

# Check for changes
check_changes() {
    log "Checking for changes to commit..."
    
    cd "$AUR_DIR"
    
    if git diff --quiet && git diff --cached --quiet; then
        log_warning "No changes detected in AUR package"
        log_warning "Package may already be up to date"
        return 1
    fi
    
    log "Changes detected:"
    git status --porcelain
    log_success "Changes ready for commit"
    return 0
}

# Commit and push changes
submit_to_aur() {
    local version="$1"
    
    log "Submitting AUR package update..."
    
    cd "$AUR_DIR"
    
    # Add files
    git add PKGBUILD .SRCINFO
    
    # Commit with version-specific message
    local commit_message="Update to v$version - unified Flutter architecture"
    git commit -m "$commit_message"
    
    # Push to AUR
    log "Pushing to AUR repository..."
    git push origin master
    
    log_success "AUR package submitted successfully"
}

# Verify submission
verify_submission() {
    local version="$1"
    
    log "Verifying AUR submission..."
    
    # Wait a moment for AUR to update
    sleep 5
    
    # Check if package appears on AUR website
    local aur_url="https://aur.archlinux.org/packages/cloudtolocalllm"
    log "Checking AUR package page: $aur_url"
    
    if curl -s -f "$aur_url" > /dev/null; then
        log_success "AUR package page accessible"
    else
        log_warning "AUR package page not immediately accessible (may take time to update)"
    fi
}

# Display summary
display_summary() {
    local version="$1"
    
    echo ""
    log_success "🎉 AUR package submission completed!"
    echo ""
    echo -e "${GREEN}📋 Submission Summary${NC}"
    echo -e "${GREEN}=====================${NC}"
    echo "  - Version: v$version"
    echo "  - Package: cloudtolocalllm"
    echo "  - AUR URL: https://aur.archlinux.org/packages/cloudtolocalllm"
    echo ""
    echo -e "${BLUE}📋 Next Steps:${NC}"
    echo "  1. Monitor AUR page for update: https://aur.archlinux.org/packages/cloudtolocalllm"
    echo "  2. Test installation: yay -S cloudtolocalllm"
    echo "  3. Verify package functionality"
    echo ""
}

# Main execution function
main() {
    local version
    
    log "🚀 CloudToLocalLLM AUR Package Submission"
    log "========================================"
    
    # Get current version
    version=$(get_version)
    log "Submitting version: $version"
    
    # Execute submission steps
    verify_aur_setup
    verify_pkgbuild_version "$version"
    update_srcinfo
    
    if check_changes; then
        submit_to_aur "$version"
        verify_submission "$version"
        display_summary "$version"
    else
        log_warning "No submission needed - package already up to date"
        exit 0
    fi
}

# Error handling
trap 'log_error "AUR submission failed at line $LINENO. Check logs above for details."' ERR

# Execute main function
main "$@"
