#!/bin/bash

# CloudToLocalLLM GitHub Release Creator
# Creates GitHub releases with binary artifacts for AUR distribution

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

# Check if GitHub CLI is installed
check_gh_cli() {
    if ! command -v gh &> /dev/null; then
        print_error "GitHub CLI (gh) is not installed"
        print_error "Install with: sudo pacman -S github-cli"
        print_error "Then authenticate with: gh auth login"
        exit 1
    fi

    # Check if authenticated
    if ! gh auth status &> /dev/null; then
        print_error "GitHub CLI is not authenticated"
        print_error "Run: gh auth login"
        exit 1
    fi
}

# Check if release already exists
check_existing_release() {
    local version="$1"
    local tag="v$version"
    local force_recreate="${2:-false}"

    if gh release view "$tag" --repo "$REPO_OWNER/$REPO_NAME" &> /dev/null; then
        if [[ "$force_recreate" == "true" ]]; then
            print_warning "Release $tag already exists - recreating due to force flag"
            print_status "Deleting existing release $tag..."
            gh release delete "$tag" --repo "$REPO_OWNER/$REPO_NAME" --yes
            git tag -d "$tag" 2>/dev/null || true
            git push origin --delete "$tag" 2>/dev/null || true
        else
            print_error "Release $tag already exists"
            print_error "Use --force to recreate the release"
            exit 1
        fi
    fi
}

# Build binary packages if they don't exist
build_packages() {
    local version="$1"
    local package_file="$PROJECT_ROOT/aur-package/cloudtolocalllm-$version-x86_64.tar.gz"
    local checksum_file="$package_file.sha256"
    
    if [[ ! -f "$package_file" ]]; then
        print_status "Building binary package for version $version..."
        cd "$PROJECT_ROOT"
        
        # Build Flutter application
        print_status "Building Flutter application..."
        flutter clean
        flutter pub get
        flutter build linux --release
        
        # Create AUR binary package
        print_status "Creating AUR binary package..."
        if [[ -f "scripts/create_unified_aur_package.sh" ]]; then
            ./scripts/create_unified_aur_package.sh
        elif [[ -f "scripts/create_aur_binary_package.sh" ]]; then
            ./scripts/create_aur_binary_package.sh
        else
            print_error "No AUR package creation script found"
            exit 1
        fi
        
        # Move package to aur-package directory if not already there
        if [[ -f "dist/cloudtolocalllm-$version-x86_64.tar.gz" ]]; then
            mv "dist/cloudtolocalllm-$version-x86_64.tar.gz" "$package_file"
            mv "dist/cloudtolocalllm-$version-x86_64.tar.gz.sha256" "$checksum_file"
        fi
    fi
    
    if [[ ! -f "$package_file" ]]; then
        print_error "Binary package not found: $package_file"
        exit 1
    fi
    
    print_success "Binary package ready: $package_file"
}

# Generate release notes
generate_release_notes() {
    local version="$1"
    local notes_file="/tmp/release_notes_$version.md"
    
    cat > "$notes_file" << EOF
# CloudToLocalLLM v$version

## 🚀 New Features & Improvements

### Enhanced Architecture
- **Unified Flutter application** with integrated system tray functionality
- **Improved deployment workflow** with GitHub releases as primary distribution
- **Streamlined AUR package** with automated GitHub release downloads
- **Enhanced build pipeline** with automated version management

### System Integration
- **Python-based system tray daemon** for improved Linux compatibility
- **TCP socket IPC** communication between components
- **Authentication-aware menus** with dynamic state updates
- **Cross-platform compatibility** improvements

### Security & Performance
- **Non-root container architecture** with proper privilege dropping
- **Enhanced authentication flow** with Auth0 PKCE support
- **Improved error handling** and logging
- **Memory optimization** and resource management

### User Interface
- **Material Design 3 compliance** with comprehensive dark theme
- **Production-quality interface** matching homepage design
- **ChatGPT-like chat interface** for improved user experience
- **Responsive design** with mobile-first breakpoints

## 📦 Installation

### Linux (AUR Package)
\`\`\`bash
# Install from AUR (recommended)
yay -S cloudtolocalllm

# Or build manually
git clone https://aur.archlinux.org/cloudtolocalllm.git
cd cloudtolocalllm
makepkg -si
\`\`\`

### Manual Installation
1. Download the binary package: \`cloudtolocalllm-$version-x86_64.tar.gz\`
2. Verify integrity: \`sha256sum -c cloudtolocalllm-$version-x86_64.tar.gz.sha256\`
3. Extract and install according to included instructions

### System Requirements
- **Linux**: Ubuntu 20.04+, Debian 11+, Arch Linux, or compatible
- **Memory**: 4GB RAM minimum, 8GB recommended
- **Storage**: 2GB available space
- **Network**: Internet connection for cloud features

## 🔗 Links

- **Homepage**: https://cloudtolocalllm.online
- **Web App**: https://app.cloudtolocalllm.online
- **Documentation**: https://github.com/$REPO_OWNER/$REPO_NAME/wiki
- **Issues**: https://github.com/$REPO_OWNER/$REPO_NAME/issues

## 🙏 Acknowledgments

Thanks to the community for feedback and contributions that made this release possible.

---

**Full Changelog**: https://github.com/$REPO_OWNER/$REPO_NAME/compare/v3.0.3...v$version
EOF

    echo "$notes_file"
}

# Create GitHub release
create_release() {
    local version="$1"
    local tag="v$version"
    local package_file="$PROJECT_ROOT/aur-package/cloudtolocalllm-$version-x86_64.tar.gz"
    local checksum_file="$package_file.sha256"
    local notes_file=$(generate_release_notes "$version")
    
    print_status "Creating GitHub release $tag..."
    
    # Create and push tag
    print_status "Creating and pushing tag $tag..."
    git tag -a "$tag" -m "CloudToLocalLLM v$version"
    git push origin "$tag"
    
    # Create release with binary assets
    print_status "Creating GitHub release with binary assets..."
    gh release create "$tag" \
        --repo "$REPO_OWNER/$REPO_NAME" \
        --title "CloudToLocalLLM v$version" \
        --notes-file "$notes_file" \
        "$package_file" \
        "$checksum_file"
    
    print_success "GitHub release created successfully!"
    print_success "Release URL: https://github.com/$REPO_OWNER/$REPO_NAME/releases/tag/$tag"
    
    # Clean up
    rm -f "$notes_file"
}

# Parse command line arguments
parse_arguments() {
    FORCE_RECREATE="false"

    while [[ $# -gt 0 ]]; do
        case $1 in
            --force)
                FORCE_RECREATE="true"
                shift
                ;;
            --help|-h)
                echo "CloudToLocalLLM GitHub Release Creator"
                echo "Usage: $0 [OPTIONS]"
                echo ""
                echo "Options:"
                echo "  --force     Recreate release if it already exists"
                echo "  --help, -h  Show this help message"
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done
}

# Main function
main() {
    # Parse arguments
    parse_arguments "$@"

    print_status "CloudToLocalLLM GitHub Release Creator"
    print_status "======================================"

    # Change to project root
    cd "$PROJECT_ROOT"

    # Check prerequisites
    check_gh_cli

    # Get version
    local version=$(get_version)
    print_status "Current version: $version"

    # Check for existing release
    check_existing_release "$version" "$FORCE_RECREATE"

    # Build packages if needed
    build_packages "$version"

    # Create GitHub release
    create_release "$version"

    print_success "GitHub release creation completed!"
    print_status "Next steps:"
    print_status "1. Update AUR package to use GitHub release"
    print_status "2. Test AUR package installation"
    print_status "3. Deploy to VPS"
}

# Execute main function
main "$@"
