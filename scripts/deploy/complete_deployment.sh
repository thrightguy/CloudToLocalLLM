#!/bin/bash
# scripts/deploy/complete_deployment.sh
# Executes the full deployment workflow

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Change to project root
cd "$PROJECT_ROOT"

echo -e "${BLUE}🚀 CloudToLocalLLM Complete Deployment Workflow${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""

# Check prerequisites
echo -e "${BLUE}🔍 Checking prerequisites...${NC}"

# Check if version manager exists
if [[ ! -f "scripts/version_manager.sh" ]]; then
    echo -e "${RED}❌ Version manager script not found!${NC}"
    exit 1
fi

# Check if Flutter is available
if ! command -v flutter &> /dev/null; then
    echo -e "${RED}❌ Flutter not found in PATH!${NC}"
    exit 1
fi

# Check if Git is available
if ! command -v git &> /dev/null; then
    echo -e "${RED}❌ Git not found in PATH!${NC}"
    exit 1
fi

# Check if we're in a Git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo -e "${RED}❌ Not in a Git repository!${NC}"
    exit 1
fi

echo -e "${GREEN}✅ All prerequisites met${NC}"
echo ""

# Show current version
CURRENT_VERSION=$(./scripts/version_manager.sh get)
echo -e "${YELLOW}📋 Current version: $CURRENT_VERSION${NC}"
echo ""

# Phase 1: Version Management
echo -e "${BLUE}📋 Phase 1: Version Management${NC}"
echo -e "${BLUE}==============================${NC}"

# Ask for increment type
echo -e "${YELLOW}Select version increment type:${NC}"
echo "  1) major - Significant changes (creates GitHub release)"
echo "  2) minor - Feature additions"
echo "  3) patch - Bug fixes"
echo "  4) build - Build increments"
echo ""

while true; do
    read -p "Enter choice (1-4): " choice
    case $choice in
        1) INCREMENT_TYPE="major"; break;;
        2) INCREMENT_TYPE="minor"; break;;
        3) INCREMENT_TYPE="patch"; break;;
        4) INCREMENT_TYPE="build"; break;;
        *) echo "Invalid choice. Please enter 1-4.";;
    esac
done

echo -e "${BLUE}🔄 Incrementing version ($INCREMENT_TYPE)...${NC}"
./scripts/version_manager.sh increment "$INCREMENT_TYPE"

NEW_VERSION=$(./scripts/version_manager.sh get)
echo -e "${GREEN}✅ Version updated to: $NEW_VERSION${NC}"

# Synchronize all version references
echo -e "${BLUE}🔄 Synchronizing version references...${NC}"
./scripts/deploy/sync_versions.sh

echo ""

# Phase 2: Build & Package
echo -e "${BLUE}🔨 Phase 2: Build & Package${NC}"
echo -e "${BLUE}============================${NC}"

echo -e "${BLUE}🧹 Cleaning previous builds...${NC}"
flutter clean

echo -e "${BLUE}📦 Getting dependencies...${NC}"
flutter pub get

echo -e "${BLUE}🏗️  Building Linux desktop application...${NC}"
flutter build linux --release

echo -e "${BLUE}🌐 Building web application...${NC}"
flutter build web --release --no-tree-shake-icons

# Check if unified package script exists
if [[ -f "scripts/build/create_unified_package.sh" ]]; then
    echo -e "${BLUE}📦 Creating unified binary package...${NC}"
    ./scripts/build/create_unified_package.sh
else
    echo -e "${YELLOW}⚠️  Unified package script not found, skipping...${NC}"
fi

echo -e "${GREEN}✅ Build phase completed${NC}"
echo ""

# Phase 3: Git Operations
echo -e "${BLUE}📤 Phase 3: Git Operations${NC}"
echo -e "${BLUE}===========================${NC}"

# Check for uncommitted changes
if ! git diff --quiet || ! git diff --cached --quiet; then
    echo -e "${BLUE}📝 Committing version changes...${NC}"
    git add pubspec.yaml assets/version.json
    
    # Add AUR PKGBUILD if it exists
    if [[ -f "aur-package/PKGBUILD" ]]; then
        git add aur-package/PKGBUILD
    fi
    
    git commit -m "Version bump to $NEW_VERSION"
    echo -e "${GREEN}✅ Changes committed${NC}"
else
    echo -e "${YELLOW}⚠️  No changes to commit${NC}"
fi

# Push to SourceForge (primary remote)
echo -e "${BLUE}📤 Pushing to SourceForge Git...${NC}"
if git remote | grep -q "sourceforge"; then
    git push sourceforge master
    echo -e "${GREEN}✅ Pushed to SourceForge${NC}"
else
    echo -e "${YELLOW}⚠️  SourceForge remote not configured, pushing to origin...${NC}"
    git push origin master
fi

echo ""

# Phase 4: Manual Steps Reminder
echo -e "${BLUE}📋 Phase 4: Manual Steps Required${NC}"
echo -e "${BLUE}===================================${NC}"

echo -e "${YELLOW}🔧 The following steps require manual intervention:${NC}"
echo ""

echo -e "${BLUE}1. Upload binaries to SourceForge file hosting:${NC}"
echo "   - Connect: sftp imrightguy@frs.sourceforge.net"
echo "   - Navigate: cd /home/frs/project/cloudtolocalllm/releases/"
echo "   - Upload: put dist/cloudtolocalllm-$NEW_VERSION-x86_64.tar.gz"
echo "   - Upload: put dist/cloudtolocalllm-$NEW_VERSION-x86_64.tar.gz.sha256"
echo ""

echo -e "${BLUE}2. Test and submit AUR package:${NC}"
echo "   - cd aur-package/"
echo "   - makepkg -si --noconfirm"
echo "   - yay -U cloudtolocalllm-*.pkg.tar.zst"
echo "   - Test: cloudtolocalllm --version"
echo "   - Submit: git add PKGBUILD .SRCINFO && git commit && git push"
echo ""

echo -e "${BLUE}3. Deploy to VPS:${NC}"
echo "   - ssh cloudllm@cloudtolocalllm.online"
echo "   - cd /opt/cloudtolocalllm"
echo "   - ./scripts/deploy/update_and_deploy.sh"
echo ""

echo -e "${BLUE}4. Run verification:${NC}"
echo "   - ./scripts/deploy/verify_deployment.sh"
echo ""

# Final summary
echo -e "${GREEN}🎉 Deployment preparation completed successfully!${NC}"
echo -e "${GREEN}Version: $NEW_VERSION${NC}"
echo ""
echo -e "${YELLOW}📋 Next Steps Summary:${NC}"
echo "1. Upload binaries to SourceForge"
echo "2. Test and submit AUR package"
echo "3. Deploy to VPS"
echo "4. Run verification checks"
echo ""
echo -e "${RED}⚠️  DEPLOYMENT IS NOT COMPLETE UNTIL ALL MANUAL STEPS ARE FINISHED${NC}"
echo -e "${RED}   AND VERIFICATION PASSES!${NC}"
