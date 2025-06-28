#!/bin/bash

# CloudToLocalLLM AUR Package Submission Script
# Submits AUR package updates to the Arch User Repository
# Version: 1.0.0

set -euo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# AUR configuration
AUR_REPO_URL="ssh://aur@aur.archlinux.org/cloudtolocalllm.git"
AUR_PACKAGE_NAME="cloudtolocalllm"
AUR_WORK_DIR="$PROJECT_ROOT/build/aur-submission"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Flags
VERBOSE=false
DRY_RUN=false
FORCE=false

# Logging functions
log() {
    echo -e "${BLUE}[$(date '+%H:%M:%S')] [AUR-SUBMIT]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[$(date '+%H:%M:%S')] [AUR-SUBMIT] ✅${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[$(date '+%H:%M:%S')] [AUR-SUBMIT] ⚠️${NC} $1"
}

log_error() {
    echo -e "${RED}[$(date '+%H:%M:%S')] [AUR-SUBMIT] ❌${NC} $1"
}

log_verbose() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "${BLUE}[$(date '+%H:%M:%S')] [AUR-SUBMIT] [VERBOSE]${NC} $1"
    fi
}

# Usage information
show_usage() {
    cat << EOF
CloudToLocalLLM AUR Package Submission Script

USAGE:
    $0 [OPTIONS]

OPTIONS:
    --force             Force submission even if no changes detected
    --verbose           Enable detailed logging
    --dry-run           Simulate submission without actual operations
    --help              Show this help message

EXAMPLES:
    $0                  # Submit AUR package if changes detected
    $0 --force          # Force submission regardless of changes
    $0 --verbose        # Detailed logging
    $0 --dry-run        # Simulate submission

EXIT CODES:
    0 - Success (or no changes needed)
    1 - General error
    2 - SSH/Git configuration error
    3 - Package preparation error
    4 - Submission failure

PREREQUISITES:
    - SSH key configured for AUR access
    - Git configured with user name and email
    - AUR package files prepared in packaging/aur/ directory
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

# Check prerequisites for AUR submission
check_prerequisites() {
    log "Checking AUR submission prerequisites..."

    if [[ "$DRY_RUN" == "true" ]]; then
        log "DRY RUN: Would check prerequisites"
        return 0
    fi

    # Check if git is available
    if ! command -v git &> /dev/null; then
        log_error "git not found - required for AUR submission"
        return 1
    fi

    # Check if SSH key is configured for AUR
    log_verbose "Testing SSH connection to AUR..."
    if ! ssh -T aur@aur.archlinux.org &> /dev/null; then
        log_error "SSH connection to AUR failed"
        log_error "Please configure SSH key for AUR access:"
        log_error "1. Generate SSH key: ssh-keygen -t ed25519"
        log_error "2. Add public key to AUR account: https://aur.archlinux.org/account/"
        log_error "3. Test connection: ssh -T aur@aur.archlinux.org"
        return 2
    fi

    log_verbose "✓ SSH connection to AUR verified"

    # Check git configuration
    if ! git config user.name &> /dev/null || ! git config user.email &> /dev/null; then
        log_error "Git user configuration missing"
        log_error "Please configure git:"
        log_error "git config --global user.name 'Your Name'"
        log_error "git config --global user.email 'your.email@example.com'"
        return 2
    fi

    log_verbose "✓ Git configuration verified"

    log_success "Prerequisites check completed"
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

# Prepare AUR package files
prepare_aur_package() {
    local version="$1"

    log "Preparing AUR package files for version $version..."

    if [[ "$DRY_RUN" == "true" ]]; then
        log "DRY RUN: Would prepare AUR package files"
        return 0
    fi

    # Check if AUR package files exist
    local aur_source_dir="$PROJECT_ROOT/packaging/aur"
    if [[ ! -d "$aur_source_dir" ]]; then
        log_error "AUR package source directory not found: $aur_source_dir"
        return 3
    fi

    # Check for required files
    if [[ ! -f "$aur_source_dir/PKGBUILD" ]]; then
        log_error "PKGBUILD not found in $aur_source_dir"
        return 3
    fi

    log_verbose "✓ AUR package source files found"

    # Create working directory
    rm -rf "$AUR_WORK_DIR"
    mkdir -p "$AUR_WORK_DIR"

    # Copy AUR package files
    cp -r "$aur_source_dir"/* "$AUR_WORK_DIR/"

    log_verbose "✓ AUR package files copied to working directory"

    # Update version in PKGBUILD if needed
    local pkgbuild_file="$AUR_WORK_DIR/PKGBUILD"
    local current_pkgver=$(grep "^pkgver=" "$pkgbuild_file" | cut -d'=' -f2)

    if [[ "$current_pkgver" != "$version" ]]; then
        log_verbose "Updating PKGBUILD version from $current_pkgver to $version"
        sed -i "s/^pkgver=.*/pkgver=$version/" "$pkgbuild_file"

        # Reset pkgrel to 1 for new version
        sed -i "s/^pkgrel=.*/pkgrel=1/" "$pkgbuild_file"
    fi

    log_success "AUR package files prepared"
    return 0
}

# Clone or update AUR repository
setup_aur_repository() {
    log "Setting up AUR repository..."

    if [[ "$DRY_RUN" == "true" ]]; then
        log "DRY RUN: Would setup AUR repository"
        return 0
    fi

    cd "$AUR_WORK_DIR"

    # Clone AUR repository
    log_verbose "Cloning AUR repository..."
    if [[ "$VERBOSE" == "true" ]]; then
        git clone "$AUR_REPO_URL" aur-repo
    else
        git clone "$AUR_REPO_URL" aur-repo &> /dev/null
    fi

    cd aur-repo

    log_verbose "✓ AUR repository cloned"
    log_success "AUR repository setup completed"
    return 0
}

# Check if submission is needed
check_submission_needed() {
    local version="$1"

    log "Checking if AUR submission is needed..."

    if [[ "$DRY_RUN" == "true" ]]; then
        log "DRY RUN: Would check if submission needed"
        return 0
    fi

    if [[ "$FORCE" == "true" ]]; then
        log "Force flag set - submission will proceed regardless of changes"
        return 0
    fi

    cd "$AUR_WORK_DIR/aur-repo"

    # Compare PKGBUILD files
    if [[ -f "PKGBUILD" ]]; then
        local current_aur_version=$(grep "^pkgver=" PKGBUILD | cut -d'=' -f2)
        log_verbose "Current AUR version: $current_aur_version"
        log_verbose "Target version: $version"

        if [[ "$current_aur_version" == "$version" ]]; then
            # Check if there are any other changes
            cp ../PKGBUILD ./PKGBUILD.new
            if [[ -f ".SRCINFO" ]]; then
                cp ../.SRCINFO ./.SRCINFO.new 2>/dev/null || true
            fi

            if ! git diff --quiet PKGBUILD PKGBUILD.new 2>/dev/null; then
                log "PKGBUILD changes detected - submission needed"
                rm -f PKGBUILD.new .SRCINFO.new
                return 0
            fi

            if [[ -f ".SRCINFO.new" ]] && ! git diff --quiet .SRCINFO .SRCINFO.new 2>/dev/null; then
                log ".SRCINFO changes detected - submission needed"
                rm -f PKGBUILD.new .SRCINFO.new
                return 0
            fi

            rm -f PKGBUILD.new .SRCINFO.new
            log "No changes detected - submission not needed"
            return 1
        fi
    fi

    log "Version update detected - submission needed"
    return 0
}

# Generate .SRCINFO file
generate_srcinfo() {
    log "Generating .SRCINFO file..."

    if [[ "$DRY_RUN" == "true" ]]; then
        log "DRY RUN: Would generate .SRCINFO file"
        return 0
    fi

    cd "$AUR_WORK_DIR/aur-repo"

    # Copy updated PKGBUILD
    cp ../PKGBUILD ./PKGBUILD

    # Generate .SRCINFO
    if command -v makepkg &> /dev/null; then
        log_verbose "Using makepkg to generate .SRCINFO"
        if [[ "$VERBOSE" == "true" ]]; then
            makepkg --printsrcinfo > .SRCINFO
        else
            makepkg --printsrcinfo > .SRCINFO 2>/dev/null
        fi
    else
        log_warning "makepkg not available - .SRCINFO generation skipped"
        log_warning "Please ensure .SRCINFO is manually updated if needed"
    fi

    log_verbose "✓ .SRCINFO file generated"
    log_success ".SRCINFO generation completed"
    return 0
}

# Submit to AUR
submit_to_aur() {
    local version="$1"

    log "Submitting package to AUR..."

    if [[ "$DRY_RUN" == "true" ]]; then
        log "DRY RUN: Would submit package to AUR"
        return 0
    fi

    cd "$AUR_WORK_DIR/aur-repo"

    # Add files to git
    git add PKGBUILD
    if [[ -f ".SRCINFO" ]]; then
        git add .SRCINFO
    fi

    # Check if there are changes to commit
    if git diff --cached --quiet; then
        log "No changes to commit"
        return 0
    fi

    # Commit changes
    local commit_message="Update to v$version"
    log_verbose "Committing changes: $commit_message"

    if [[ "$VERBOSE" == "true" ]]; then
        git commit -m "$commit_message"
    else
        git commit -m "$commit_message" &> /dev/null
    fi

    # Push to AUR
    log_verbose "Pushing to AUR repository..."
    if [[ "$VERBOSE" == "true" ]]; then
        git push origin master
    else
        git push origin master &> /dev/null
    fi

    log_success "✓ Package submitted to AUR"
    return 0
}

# Cleanup working directory
cleanup_working_directory() {
    log "Cleaning up working directory..."

    if [[ "$DRY_RUN" == "true" ]]; then
        log "DRY RUN: Would cleanup working directory"
        return 0
    fi

    # Remove working directory
    rm -rf "$AUR_WORK_DIR"

    log_verbose "✓ Working directory cleaned up"
    log_success "Cleanup completed"
    return 0
}

# Main execution function
main() {
    # Parse command line arguments
    parse_arguments "$@"

    log "CloudToLocalLLM AUR Package Submission"
    log "======================================"

    # Get current version
    local version=$(get_current_version)
    log "Submitting version: $version"

    # Execute submission phases
    if ! check_prerequisites; then
        exit 2
    fi

    if ! prepare_aur_package "$version"; then
        exit 3
    fi

    if ! setup_aur_repository; then
        exit 4
    fi

    if ! check_submission_needed "$version"; then
        log "No submission needed - package is already up to date"
        cleanup_working_directory
        exit 0
    fi

    if ! generate_srcinfo; then
        exit 3
    fi

    if ! submit_to_aur "$version"; then
        exit 4
    fi

    # Cleanup
    cleanup_working_directory

    log_success "🎉 AUR package submission completed successfully!"

    if [[ "$DRY_RUN" == "true" ]]; then
        log "DRY RUN completed - no actual submission performed"
    fi
}

# Execute main function
main "$@"