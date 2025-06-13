#!/bin/bash

# CloudToLocalLLM AUR Package Submission Script v3.5.5+
# Submits the AUR package update following the script-first resolution principle
# Enhanced with robust network operations and timeout handling

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
AUR_DIR="$PROJECT_ROOT/aur-package"

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
FORCE=false
VERBOSE=false
DRY_RUN=false

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
CloudToLocalLLM AUR Package Submission Script

USAGE:
    $0 [OPTIONS]

OPTIONS:
    --force             Skip confirmation prompts
    --verbose           Enable detailed logging
    --dry-run           Simulate submission without actual changes
    --help              Show this help message

EXAMPLES:
    $0                  # Interactive submission
    $0 --force          # Automated submission (CI/CD compatible)
    $0 --verbose        # Detailed logging
    $0 --dry-run        # Simulate submission

EXIT CODES:
    0 - Success
    1 - General error
    2 - Validation failure
    3 - Submission failure
EOF
}

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --force)
                FORCE=true
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
        log_warning "PKGBUILD version mismatch:"
        log_warning "  Expected: $expected_version"
        log_warning "  Found: $pkgbuild_version"

        if [[ "$FORCE" == "true" ]]; then
            log "Force mode enabled, attempting to fix version mismatch..."

            # Get the SHA256 checksum for the expected version
            local package_file="cloudtolocalllm-${expected_version}-x86_64.tar.gz"
            local sha256_file="../dist/${package_file}.sha256"

            if [[ -f "$sha256_file" ]]; then
                local new_sha256=$(cat "$sha256_file")
                log_verbose "Found SHA256 for $expected_version: $new_sha256"

                # Update PKGBUILD version and checksum
                sed -i "s/^pkgver=.*/pkgver=$expected_version/" PKGBUILD
                sed -i "s/'[a-f0-9]\{64\}'/'$new_sha256'/" PKGBUILD

                # Regenerate .SRCINFO
                if command -v makepkg &> /dev/null; then
                    makepkg --printsrcinfo > .SRCINFO
                    log_success "Updated PKGBUILD to version $expected_version"
                else
                    log_error "makepkg not available, cannot regenerate .SRCINFO"
                    exit 1
                fi
            else
                log_error "SHA256 file not found: $sha256_file"
                log_error "Cannot automatically fix version mismatch"
                exit 1
            fi
        else
            log_error "Use --force flag to automatically fix version mismatch"
            exit 1
        fi
    fi
    
    log_success "PKGBUILD version verified: $pkgbuild_version"
}

# Update .SRCINFO
update_srcinfo() {
    log "Updating .SRCINFO..."

    if [[ "$DRY_RUN" == "true" ]]; then
        log "DRY RUN: Would update .SRCINFO"
        log_success "DRY RUN: .SRCINFO update simulation completed"
        return 0
    fi

    cd "$AUR_DIR"

    if ! command -v makepkg &> /dev/null; then
        log_error "makepkg not found - required for .SRCINFO generation"
        log_error "Please install base-devel package"
        exit 1
    fi

    if [[ "$VERBOSE" == "true" ]]; then
        makepkg --printsrcinfo > .SRCINFO
    else
        makepkg --printsrcinfo > .SRCINFO 2>/dev/null
    fi

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

    if [[ "$DRY_RUN" == "true" ]]; then
        log "DRY RUN: Would check for changes"
        log_success "DRY RUN: Change detection simulation completed"
        return 0
    fi

    cd "$AUR_DIR"

    if git diff --quiet && git diff --cached --quiet; then
        log_warning "No changes detected in AUR package"
        log_warning "Package may already be up to date"
        return 1
    fi

    log "Changes detected:"
    if [[ "$VERBOSE" == "true" ]]; then
        git status --porcelain
    else
        git status --porcelain | head -5
    fi
    log_success "Changes ready for commit"
    return 0
}

# Commit and push changes
submit_to_aur() {
    local version="$1"

    log "Submitting AUR package update..."

    if [[ "$DRY_RUN" == "true" ]]; then
        log "DRY RUN: Would commit and push to AUR"
        log "DRY RUN: Commit message: Update to v$version - unified Flutter architecture"
        log_success "DRY RUN: AUR submission simulation completed"
        return 0
    fi

    cd "$AUR_DIR"

    # Add files
    log_verbose "Adding PKGBUILD and .SRCINFO to git..."
    git add PKGBUILD .SRCINFO

    # Commit with version-specific message
    local commit_message="Update to v$version - unified Flutter architecture"
    log_verbose "Committing with message: $commit_message"
    git commit -m "$commit_message"

    # Push to AUR with enhanced error handling
    log "Pushing to AUR repository..."

    # Use enhanced git operations if available, otherwise fallback
    if command -v git_execute &> /dev/null; then
        if ! git_execute push origin master; then
            log_error "Failed to push to AUR repository"
            exit 3
        fi
    else
        # Fallback with timeout
        if [[ "$VERBOSE" == "true" ]]; then
            if ! timeout 120 git push origin master; then
                log_error "Git push to AUR timed out or failed"
                exit 3
            fi
        else
            if ! timeout 120 git push origin master 2>/dev/null; then
                log_error "Git push to AUR timed out or failed"
                exit 3
            fi
        fi
    fi

    log_success "AUR package submitted successfully"
}

# Verify submission
verify_submission() {
    local version="$1"

    log "Verifying AUR submission..."

    if [[ "$DRY_RUN" == "true" ]]; then
        log "DRY RUN: Would verify AUR submission"
        log_success "DRY RUN: Verification simulation completed"
        return 0
    fi

    # Wait a moment for AUR to update
    log_verbose "Waiting for AUR to update..."
    sleep 5

    # Check if package appears on AUR website with enhanced retry
    local aur_url="https://aur.archlinux.org/packages/cloudtolocalllm"
    log_verbose "Checking AUR package page: $aur_url"

    # Use enhanced curl if available, otherwise fallback
    if command -v curl_with_retry &> /dev/null; then
        if curl_with_retry "$aur_url" --max-retries 3 > /dev/null; then
            log_success "AUR package page accessible"
        else
            log_warning "AUR package page not immediately accessible (may take time to update)"
        fi
    else
        # Fallback implementation
        if curl -f -s --connect-timeout 10 "$aur_url" > /dev/null 2>&1; then
            log_success "AUR package page accessible"
        else
            log_warning "AUR package page not immediately accessible (may take time to update)"
        fi
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
    echo "Force: $FORCE | Verbose: $VERBOSE | Dry Run: $DRY_RUN"
    echo ""

    # Get current version
    version=$(get_version)
    log "Submitting version: $version"

    # Execute submission steps
    verify_aur_setup
    verify_pkgbuild_version "$version"
    update_srcinfo

    if check_changes; then
        # Non-interactive execution for force mode
        if [[ "$FORCE" != "true" && "$DRY_RUN" != "true" ]]; then
            log_warning "About to submit AUR package update for v$version"
            log_warning "This will commit and push changes to the AUR repository"
            log_warning "Use --force flag for automated/CI environments"
            log "Proceeding with submission in 5 seconds..."
            sleep 5
        fi

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

# Parse arguments and execute main function
parse_arguments "$@"
main
