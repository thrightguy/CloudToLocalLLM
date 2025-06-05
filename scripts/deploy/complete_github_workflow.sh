#!/bin/bash

# CloudToLocalLLM Complete GitHub Release Workflow
# Handles: Build → GitHub Release → AUR Update → VPS Deployment

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
REPO_OWNER="imrightguy"
REPO_NAME="CloudToLocalLLM"

# Default options
AUTO_MODE="false"
FORCE_DEPLOY="false"
SUBMIT_AUR="false"
SKIP_VPS="false"

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --auto)
                AUTO_MODE="true"
                shift
                ;;
            --force)
                FORCE_DEPLOY="true"
                shift
                ;;
            --submit-aur)
                SUBMIT_AUR="true"
                shift
                ;;
            --skip-vps)
                SKIP_VPS="true"
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# Show help
show_help() {
    echo "CloudToLocalLLM Complete GitHub Release Workflow"
    echo "================================================"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --auto              Run without confirmation prompts"
    echo "  --force             Deploy even with uncommitted changes"
    echo "  --submit-aur        Submit updated package to AUR repository"
    echo "  --skip-vps          Skip VPS deployment step"
    echo "  --help, -h          Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 --auto                           # Automated deployment without AUR submission"
    echo "  $0 --auto --submit-aur              # Full deployment with AUR submission"
    echo "  $0 --auto --force --submit-aur      # Force deployment with uncommitted changes"
    echo "  $0 --auto --skip-vps                # Deploy GitHub release and AUR only"
    echo ""
    echo "Workflow Steps:"
    echo "  1. Check prerequisites (GitHub CLI, Flutter, etc.)"
    echo "  2. Build application and create binary packages"
    echo "  3. Create GitHub release with binary assets"
    echo "  4. Update and test AUR package"
    echo "  5. Deploy to VPS (unless --skip-vps)"
    echo "  6. Verify complete deployment"
}

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
    echo -e "\n${YELLOW}=== $1 ===${NC}"
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

# Check prerequisites
check_prerequisites() {
    print_step "Checking Prerequisites"
    
    # Check if we're in the right directory
    if [[ ! -f "$PROJECT_ROOT/pubspec.yaml" ]]; then
        print_error "Not in CloudToLocalLLM project root"
        exit 1
    fi
    
    # Check Flutter
    if ! command -v flutter &> /dev/null; then
        print_error "Flutter is not installed"
        exit 1
    fi
    
    # Check GitHub CLI
    if ! command -v gh &> /dev/null; then
        print_error "GitHub CLI (gh) is not installed"
        print_error "Install with: sudo pacman -S github-cli"
        exit 1
    fi
    
    # Check GitHub authentication
    if ! gh auth status &> /dev/null; then
        print_error "GitHub CLI is not authenticated"
        print_error "Run: gh auth login"
        exit 1
    fi
    
    # Check git status
    if [[ -n $(git status --porcelain) ]]; then
        if [[ "$FORCE_DEPLOY" != "true" ]]; then
            print_error "Working directory has uncommitted changes"
            print_error "Use --force to deploy anyway, or commit changes first"
            exit 1
        else
            print_warning "Working directory has uncommitted changes - continuing due to --force flag"
        fi
    fi
    
    print_success "All prerequisites met"
}

# Step 1: Build Application
build_application() {
    print_step "Building Application"
    
    cd "$PROJECT_ROOT"
    
    # Clean and build Flutter
    print_status "Building Flutter application..."
    flutter clean
    flutter pub get
    flutter build linux --release
    flutter build web --release --no-tree-shake-icons
    
    # Build binary package
    print_status "Creating binary package..."
    if [[ -f "scripts/create_unified_aur_package.sh" ]]; then
        ./scripts/create_unified_aur_package.sh
    elif [[ -f "scripts/create_aur_binary_package.sh" ]]; then
        ./scripts/create_aur_binary_package.sh
    else
        print_error "No AUR package creation script found"
        exit 1
    fi
    
    print_success "Application built successfully"
}

# Step 2: Create GitHub Release
create_github_release() {
    print_step "Creating GitHub Release"
    
    local version=$(get_version)
    print_status "Creating release for version $version"
    
    # Run the GitHub release script
    if [[ -f "$SCRIPT_DIR/../release/create_github_release.sh" ]]; then
        if [[ "$FORCE_DEPLOY" == "true" ]]; then
            "$SCRIPT_DIR/../release/create_github_release.sh" --force
        else
            "$SCRIPT_DIR/../release/create_github_release.sh"
        fi
    else
        print_error "GitHub release script not found"
        exit 1
    fi
    
    print_success "GitHub release created successfully"
}

# Step 3: Update AUR Package
update_aur_package() {
    print_step "Updating AUR Package"
    
    local version=$(get_version)
    cd "$PROJECT_ROOT/aur-package"
    
    # Verify PKGBUILD is configured for GitHub releases
    if ! grep -q "github.com.*releases.*download" PKGBUILD; then
        print_error "PKGBUILD is not configured for GitHub releases"
        print_error "Please update PKGBUILD to use GitHub release URLs"
        exit 1
    fi
    
    # Test the package build
    print_status "Testing AUR package build..."
    makepkg -si --noconfirm
    
    # Generate .SRCINFO
    print_status "Generating .SRCINFO..."
    makepkg --printsrcinfo > .SRCINFO
    
    # Test installation
    print_status "Testing package installation..."
    if command -v cloudtolocalllm &> /dev/null; then
        local installed_version=$(cloudtolocalllm --version 2>/dev/null || echo "unknown")
        print_status "Installed version: $installed_version"
    fi
    
    print_success "AUR package updated and tested"
    
    # Submit to AUR if requested
    if [[ "$SUBMIT_AUR" == "true" ]]; then
        print_status "Submitting to AUR..."
        git add PKGBUILD .SRCINFO
        git commit -m "Update to v$version with GitHub releases"
        git push origin master
        print_success "AUR package submitted"
    else
        print_warning "AUR submission skipped (use --submit-aur to enable)"
    fi
}

# Step 4: Deploy to VPS
deploy_to_vps() {
    if [[ "$SKIP_VPS" == "true" ]]; then
        print_step "Skipping VPS Deployment"
        print_warning "VPS deployment skipped due to --skip-vps flag"
        return 0
    fi

    print_step "Deploying to VPS"

    print_status "Deploying to cloudtolocalllm.online..."

    # Deploy to VPS
    ssh cloudllm@cloudtolocalllm.online "cd /opt/cloudtolocalllm && git pull origin master && ./scripts/deploy/update_and_deploy.sh"

    # Verify deployment
    print_status "Verifying deployment..."
    sleep 5

    local response=$(curl -s https://app.cloudtolocalllm.online/version.json || echo '{"version":"unknown"}')
    local deployed_version=$(echo "$response" | jq -r '.version' 2>/dev/null || echo "unknown")

    print_status "Deployed version: $deployed_version"

    # Run verification script if available
    if [[ -f "$SCRIPT_DIR/verify_deployment.sh" ]]; then
        "$SCRIPT_DIR/verify_deployment.sh"
    fi

    print_success "VPS deployment completed"
}

# Step 5: Final Verification
final_verification() {
    print_step "Final Verification"
    
    local version=$(get_version)
    
    print_status "Verifying complete deployment workflow..."
    
    # Check GitHub release
    if gh release view "v$version" --repo "$REPO_OWNER/$REPO_NAME" &> /dev/null; then
        print_success "✓ GitHub release v$version exists"
    else
        print_error "✗ GitHub release v$version not found"
    fi
    
    # Check VPS deployment (if not skipped)
    if [[ "$SKIP_VPS" != "true" ]]; then
        local vps_response=$(curl -s https://app.cloudtolocalllm.online/version.json || echo '{"version":"unknown"}')
        local vps_version=$(echo "$vps_response" | jq -r '.version' 2>/dev/null || echo "unknown")

        if [[ "$vps_version" == "$version" ]]; then
            print_success "✓ VPS deployment version matches: $vps_version"
        else
            print_warning "⚠ VPS version mismatch: expected $version, got $vps_version"
        fi

        # Check web app accessibility
        if curl -s https://app.cloudtolocalllm.online/ > /dev/null; then
            print_success "✓ Web app is accessible"
        else
            print_error "✗ Web app is not accessible"
        fi
    else
        print_warning "⚠ VPS deployment verification skipped"
    fi
    
    print_success "Deployment workflow completed!"
    print_status "Summary:"
    print_status "- Version: $version"
    print_status "- GitHub Release: https://github.com/$REPO_OWNER/$REPO_NAME/releases/tag/v$version"
    print_status "- Web App: https://app.cloudtolocalllm.online"
    print_status "- AUR Package: https://aur.archlinux.org/packages/cloudtolocalllm"
}

# Main function
main() {
    # Parse command line arguments first
    parse_arguments "$@"

    print_status "CloudToLocalLLM Complete GitHub Release Workflow"
    print_status "================================================"

    local version=$(get_version)
    print_status "Current version: $version"

    # Show configuration
    print_status "Configuration:"
    print_status "  Auto mode: $AUTO_MODE"
    print_status "  Force deploy: $FORCE_DEPLOY"
    print_status "  Submit AUR: $SUBMIT_AUR"
    print_status "  Skip VPS: $SKIP_VPS"
    
    # Skip confirmation if auto mode is enabled
    if [[ "$AUTO_MODE" != "true" ]]; then
        print_error "Interactive mode disabled. Use --auto to run automatically"
        print_status "Available options:"
        print_status "  --auto              Run without confirmation"
        print_status "  --force             Deploy with uncommitted changes"
        print_status "  --submit-aur        Submit to AUR repository"
        print_status "  --skip-vps          Skip VPS deployment"
        print_status "  --help              Show this help"
        exit 1
    fi
    
    # Execute workflow steps
    check_prerequisites
    build_application
    create_github_release
    update_aur_package
    deploy_to_vps
    final_verification
    
    print_success "🎉 Complete deployment workflow finished successfully!"
}

# Execute main function
main "$@"
