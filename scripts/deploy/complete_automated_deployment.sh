#!/bin/bash

# CloudToLocalLLM Complete Automated Deployment Script v3.4.0+
# Implements the six-phase deployment workflow with full automation
# Zero manual operations principle with comprehensive error handling

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

# Flags
FORCE=false
VERBOSE=false
SKIP_BACKUP=false
DRY_RUN=false

# Phase tracking
CURRENT_PHASE=0
TOTAL_PHASES=6

# Logging functions
log() {
    echo -e "${BLUE}[$(date '+%H:%M:%S')] [Phase $CURRENT_PHASE/$TOTAL_PHASES]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[$(date '+%H:%M:%S')] [Phase $CURRENT_PHASE/$TOTAL_PHASES] ✅${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[$(date '+%H:%M:%S')] [Phase $CURRENT_PHASE/$TOTAL_PHASES] ⚠️${NC} $1"
}

log_error() {
    echo -e "${RED}[$(date '+%H:%M:%S')] [Phase $CURRENT_PHASE/$TOTAL_PHASES] ❌${NC} $1"
}

log_verbose() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "${BLUE}[$(date '+%H:%M:%S')] [Phase $CURRENT_PHASE/$TOTAL_PHASES] [VERBOSE]${NC} $1"
    fi
}

log_phase() {
    echo ""
    echo -e "${BLUE}🔄 Phase $1/$TOTAL_PHASES: $2${NC}"
    echo -e "${BLUE}$(printf '=%.0s' {1..50})${NC}"
    CURRENT_PHASE=$1
}

# Usage information
show_usage() {
    cat << EOF
CloudToLocalLLM Complete Automated Deployment Script

USAGE:
    $0 [OPTIONS]

OPTIONS:
    --force             Skip all confirmation prompts
    --verbose           Enable detailed logging
    --skip-backup       Skip backup creation for faster deployment
    --dry-run           Simulate deployment without actual changes
    --help              Show this help message

EXAMPLES:
    $0                  # Interactive deployment
    $0 --force          # Fully automated deployment
    $0 --verbose        # Detailed logging
    $0 --dry-run        # Simulate entire deployment

EXIT CODES:
    0 - Success
    1 - General error
    2 - Validation failure
    3 - Build failure
    4 - Deployment failure
    5 - Verification failure

DEPLOYMENT PHASES:
    1. Pre-Flight Validation
    2. Version Management
    3. Multi-Platform Build
    4. Distribution Execution
    5. Comprehensive Verification
    6. Operational Readiness
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
            --skip-backup)
                SKIP_BACKUP=true
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

# Phase 1: Pre-Flight Validation
phase1_preflight_validation() {
    log_phase 1 "Pre-Flight Validation"
    
    log "Checking environment and repository state..."
    
    # Change to project root
    cd "$PROJECT_ROOT"
    
    # Check Git status
    if ! git diff --quiet || ! git diff --cached --quiet; then
        if [[ "$FORCE" != "true" ]]; then
            log_error "Uncommitted changes detected. Commit or stash changes first."
            exit 2
        else
            log_warning "Uncommitted changes detected but continuing with --force"
        fi
    fi
    
    # Check required tools
    local required_tools=("flutter" "git" "ssh" "scp" "makepkg")
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            log_error "Required tool not found: $tool"
            exit 2
        fi
        log_verbose "✓ Tool available: $tool"
    done
    
    # Check SSH connection to VPS
    if ! ssh -o ConnectTimeout=10 -o BatchMode=yes cloudllm@cloudtolocalllm.online "echo 'SSH test'" &> /dev/null; then
        log_error "SSH connection to VPS failed"
        exit 2
    fi
    
    log_success "Pre-flight validation completed"
}

# Phase 2: Version Management
phase2_version_management() {
    log_phase 2 "Version Management"
    
    log "Version already incremented to v3.4.0+001"
    log "Verifying version synchronization..."
    
    # Verify version consistency
    local pubspec_version=$(grep '^version:' pubspec.yaml | sed 's/version: *\([0-9.]*\).*/\1/')
    local assets_version=$(grep '"version"' assets/version.json | cut -d'"' -f4)
    local aur_version=$(grep '^pkgver=' aur-package/PKGBUILD | cut -d'=' -f2)
    
    log_verbose "pubspec.yaml: $pubspec_version"
    log_verbose "assets/version.json: $assets_version"
    log_verbose "AUR PKGBUILD: $aur_version"
    
    if [[ "$pubspec_version" != "$assets_version" ]] || [[ "$pubspec_version" != "$aur_version" ]]; then
        log_error "Version mismatch detected"
        exit 2
    fi
    
    log_success "Version management validation completed"
}

# Phase 3: Multi-Platform Build
phase3_multiplatform_build() {
    log_phase 3 "Multi-Platform Build"
    
    log "Building unified package and web application..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log "DRY RUN: Would execute build scripts"
        log_success "DRY RUN: Multi-platform build simulation completed"
        return 0
    fi
    
    # Build unified package (already completed)
    if [[ ! -f "dist/cloudtolocalllm-3.4.0-x86_64.tar.gz" ]]; then
        log_error "Unified package not found. Run ./scripts/create_unified_package.sh first"
        exit 3
    fi
    
    # Build web application
    log_verbose "Building web application..."
    if [[ "$VERBOSE" == "true" ]]; then
        flutter build web --release --no-tree-shake-icons
    else
        flutter build web --release --no-tree-shake-icons &> /dev/null
    fi
    
    log_success "Multi-platform build completed"
}

# Phase 4: Distribution Execution
phase4_distribution_execution() {
    log_phase 4 "Distribution Execution"
    
    log "Executing distribution deployment..."
    
    # Upload to static distribution
    local upload_flags=""
    if [[ "$FORCE" == "true" ]]; then
        upload_flags="$upload_flags --force"
    fi
    if [[ "$VERBOSE" == "true" ]]; then
        upload_flags="$upload_flags --verbose"
    fi
    if [[ "$DRY_RUN" == "true" ]]; then
        upload_flags="$upload_flags --dry-run"
    fi
    
    log_verbose "Uploading to static distribution..."
    ./scripts/deploy/upload_static_distribution.sh $upload_flags
    
    # Test AUR package
    local aur_flags="--skip-install"
    if [[ "$VERBOSE" == "true" ]]; then
        aur_flags="$aur_flags --verbose"
    fi
    if [[ "$DRY_RUN" == "true" ]]; then
        aur_flags="$aur_flags --dry-run"
    fi
    
    log_verbose "Testing AUR package..."
    ./scripts/deploy/test_aur_package.sh $aur_flags
    
    # Deploy to VPS
    local vps_flags=""
    if [[ "$FORCE" == "true" ]]; then
        vps_flags="$vps_flags --force"
    fi
    if [[ "$VERBOSE" == "true" ]]; then
        vps_flags="$vps_flags --verbose"
    fi
    if [[ "$SKIP_BACKUP" == "true" ]]; then
        vps_flags="$vps_flags --skip-backup"
    fi
    if [[ "$DRY_RUN" == "true" ]]; then
        vps_flags="$vps_flags --dry-run"
    fi
    
    log_verbose "Deploying to VPS..."
    ssh cloudllm@cloudtolocalllm.online "cd /opt/cloudtolocalllm && git pull origin master && ./scripts/deploy/update_and_deploy.sh $vps_flags"
    
    log_success "Distribution execution completed"
}

# Phase 5: Comprehensive Verification
phase5_comprehensive_verification() {
    log_phase 5 "Comprehensive Verification"
    
    log "Performing comprehensive verification..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log "DRY RUN: Would perform verification checks"
        log_success "DRY RUN: Verification simulation completed"
        return 0
    fi
    
    # Test web platform
    log_verbose "Testing web platform..."
    local web_response=$(curl -s -o /dev/null -w "%{http_code}" https://app.cloudtolocalllm.online)
    if [[ "$web_response" =~ ^(200|301|302)$ ]]; then
        log_verbose "✓ Web platform accessible"
    else
        log_error "Web platform accessibility failed (HTTP $web_response)"
        exit 5
    fi
    
    # Test version endpoint
    log_verbose "Testing version endpoint..."
    local version_response=$(curl -s https://app.cloudtolocalllm.online/version.json | grep -o '"version":"[^"]*"' | cut -d'"' -f4)
    if [[ "$version_response" == "3.4.0" ]]; then
        log_verbose "✓ Version endpoint correct"
    else
        log_error "Version endpoint mismatch: expected 3.4.0, got $version_response"
        exit 5
    fi
    
    log_success "Comprehensive verification completed"
}

# Phase 6: Operational Readiness
phase6_operational_readiness() {
    log_phase 6 "Operational Readiness"
    
    log "Confirming operational readiness..."
    
    # Display deployment summary
    echo ""
    echo -e "${GREEN}🎉 CloudToLocalLLM v3.4.0+001 Deployment Completed Successfully!${NC}"
    echo -e "${GREEN}================================================================${NC}"
    echo ""
    echo -e "${BLUE}📋 Deployment Summary:${NC}"
    echo "  ✅ Version: v3.4.0+001"
    echo "  ✅ Static Distribution: https://cloudtolocalllm.online/download/"
    echo "  ✅ Web Platform: https://app.cloudtolocalllm.online"
    echo "  ✅ AUR Package: Ready for submission"
    echo ""
    echo -e "${BLUE}📋 Next Steps:${NC}"
    echo "  1. Submit AUR package: cd aur-package && git add . && git commit -m 'Update to v3.4.0' && git push"
    echo "  2. Test AUR installation: yay -S cloudtolocalllm"
    echo "  3. Verify platform-specific UI features"
    echo "  4. Monitor deployment health"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        echo ""
        echo -e "${YELLOW}📋 DRY RUN completed - no actual deployment performed${NC}"
    fi
    
    log_success "Operational readiness confirmed"
}

# Main execution
main() {
    # Header
    echo -e "${BLUE}CloudToLocalLLM Complete Automated Deployment v3.4.0+${NC}"
    echo -e "${BLUE}======================================================${NC}"
    echo "Target: CloudToLocalLLM v3.4.0+001 Production Deployment"
    echo "Strategy: Six-Phase Automated Workflow"
    echo "Distribution: Static Download + AUR + VPS"
    echo ""
    
    # Parse arguments
    parse_arguments "$@"
    
    # Confirmation prompt (unless force or dry-run)
    if [[ "$FORCE" != "true" && "$DRY_RUN" != "true" ]]; then
        echo -e "${YELLOW}⚠️  About to execute complete production deployment${NC}"
        echo -e "${YELLOW}This will deploy CloudToLocalLLM v3.4.0+001 to all distribution channels${NC}"
        read -p "Continue? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log "Deployment cancelled by user"
            exit 0
        fi
    fi
    
    # Execute six-phase deployment workflow
    phase1_preflight_validation
    phase2_version_management
    phase3_multiplatform_build
    phase4_distribution_execution
    phase5_comprehensive_verification
    phase6_operational_readiness
}

# Error handling
trap 'log_error "Deployment failed at line $LINENO in phase $CURRENT_PHASE. Check logs above for details."' ERR

# Execute main function
main "$@"
