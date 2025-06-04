#!/bin/bash
# scripts/deploy/verify_deployment.sh
# Comprehensive deployment verification

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

echo -e "${BLUE}🔍 CloudToLocalLLM Deployment Verification${NC}"
echo -e "${BLUE}===========================================${NC}"

# Get expected version
if [[ ! -f "scripts/version_manager.sh" ]]; then
    echo -e "${RED}❌ Version manager script not found!${NC}"
    exit 1
fi

EXPECTED_VERSION=$(./scripts/version_manager.sh get-semantic)
EXPECTED_BUILD=$(./scripts/version_manager.sh get-build)
EXPECTED_FULL=$(./scripts/version_manager.sh get)

echo -e "${YELLOW}📋 Expected version: $EXPECTED_FULL${NC}"
echo ""

# Verification results
VERIFICATION_PASSED=true

# 1. Check Git repository
echo -e "${BLUE}📂 Checking Git repository...${NC}"
CURRENT_VERSION=$(./scripts/version_manager.sh get-semantic)
CURRENT_BUILD=$(./scripts/version_manager.sh get-build)
CURRENT_FULL=$(./scripts/version_manager.sh get)

if [[ "$CURRENT_FULL" = "$EXPECTED_FULL" ]]; then
    echo -e "${GREEN}✅ Git repository version: $CURRENT_FULL${NC}"
else
    echo -e "${RED}❌ Git repository version mismatch: $CURRENT_FULL != $EXPECTED_FULL${NC}"
    VERIFICATION_PASSED=false
fi

# Check if latest changes are committed
if git diff --quiet && git diff --cached --quiet; then
    echo -e "${GREEN}✅ All changes committed${NC}"
else
    echo -e "${YELLOW}⚠️  Uncommitted changes detected${NC}"
    git status --porcelain
fi

# Check if pushed to remote
LOCAL_COMMIT=$(git rev-parse HEAD)
REMOTE_COMMIT=$(git rev-parse origin/master 2>/dev/null || echo "unknown")
if [[ "$LOCAL_COMMIT" = "$REMOTE_COMMIT" ]]; then
    echo -e "${GREEN}✅ Latest changes pushed to remote${NC}"
else
    echo -e "${YELLOW}⚠️  Local commits not pushed to remote${NC}"
fi

echo ""

# 2. Check assets/version.json
echo -e "${BLUE}📄 Checking assets/version.json...${NC}"
if [[ -f "assets/version.json" ]]; then
    ASSETS_VERSION=$(grep '"version"' assets/version.json | cut -d'"' -f4)
    ASSETS_BUILD=$(grep '"build_number"' assets/version.json | cut -d'"' -f4)
    
    if [[ "$ASSETS_VERSION" = "$EXPECTED_VERSION" && "$ASSETS_BUILD" = "$EXPECTED_BUILD" ]]; then
        echo -e "${GREEN}✅ assets/version.json: $ASSETS_VERSION+$ASSETS_BUILD${NC}"
    else
        echo -e "${RED}❌ assets/version.json version mismatch: $ASSETS_VERSION+$ASSETS_BUILD != $EXPECTED_FULL${NC}"
        VERIFICATION_PASSED=false
    fi
else
    echo -e "${RED}❌ assets/version.json not found${NC}"
    VERIFICATION_PASSED=false
fi

echo ""

# 3. Check AUR package
echo -e "${BLUE}📦 Checking AUR package...${NC}"
if [[ -f "aur-package/PKGBUILD" ]]; then
    AUR_VERSION=$(grep "^pkgver=" aur-package/PKGBUILD | cut -d'=' -f2)
    
    if [[ "$AUR_VERSION" = "$EXPECTED_VERSION" ]]; then
        echo -e "${GREEN}✅ AUR package version: $AUR_VERSION${NC}"
        
        # Check if PKGBUILD is valid
        cd aur-package
        if makepkg --printsrcinfo > .SRCINFO.test 2>/dev/null; then
            echo -e "${GREEN}✅ AUR PKGBUILD is valid${NC}"
            rm -f .SRCINFO.test
        else
            echo -e "${RED}❌ AUR PKGBUILD has syntax errors${NC}"
            VERIFICATION_PASSED=false
        fi
        cd "$PROJECT_ROOT"
    else
        echo -e "${RED}❌ AUR package version mismatch: $AUR_VERSION != $EXPECTED_VERSION${NC}"
        VERIFICATION_PASSED=false
    fi
else
    echo -e "${YELLOW}⚠️  AUR PKGBUILD not found${NC}"
fi

echo ""

# 4. Check VPS deployment
echo -e "${BLUE}🌐 Checking VPS deployment...${NC}"

# Check VPS web app accessibility first
if curl -s --connect-timeout 10 -I https://app.cloudtolocalllm.online | grep -q "200\|301\|302"; then
    echo -e "${GREEN}✅ VPS web app accessible${NC}"

    # Try to get version from version.json
    VPS_RESPONSE=$(curl -s --connect-timeout 10 https://app.cloudtolocalllm.online/version.json 2>/dev/null || echo "ERROR")

    if [[ "$VPS_RESPONSE" != "ERROR" ]]; then
        # Try to parse JSON response
        VPS_VERSION=$(echo "$VPS_RESPONSE" | grep -o '"version":"[^"]*"' | cut -d'"' -f4 2>/dev/null || echo "unknown")

        if [[ "$VPS_VERSION" = "$EXPECTED_VERSION" ]]; then
            echo -e "${GREEN}✅ VPS deployment version: $VPS_VERSION${NC}"
        elif [[ "$VPS_VERSION" = "unknown" ]]; then
            echo -e "${YELLOW}⚠️  VPS version format unrecognized: $VPS_RESPONSE${NC}"
        else
            echo -e "${RED}❌ VPS deployment version mismatch: $VPS_VERSION != $EXPECTED_VERSION${NC}"
            VERIFICATION_PASSED=false
        fi
    else
        echo -e "${YELLOW}⚠️  VPS version endpoint not accessible, but web app is running${NC}"
    fi

    # Check main site accessibility
    if curl -s --connect-timeout 10 -I https://cloudtolocalllm.online | grep -q "200\|301\|302"; then
        echo -e "${GREEN}✅ VPS main site accessible${NC}"
    else
        echo -e "${YELLOW}⚠️  VPS main site not accessible${NC}"
    fi
else
    echo -e "${RED}❌ VPS web app not accessible${NC}"
    VERIFICATION_PASSED=false
fi

echo ""

# 5. Check build artifacts
echo -e "${BLUE}🔨 Checking build artifacts...${NC}"
if [[ -d "build/linux/x64/release/bundle" ]]; then
    echo -e "${GREEN}✅ Linux build artifacts present${NC}"
else
    echo -e "${YELLOW}⚠️  Linux build artifacts missing${NC}"
fi

if [[ -d "build/web" ]]; then
    echo -e "${GREEN}✅ Web build artifacts present${NC}"
else
    echo -e "${YELLOW}⚠️  Web build artifacts missing${NC}"
fi

# Check for binary packages
if ls dist/cloudtolocalllm-*.tar.gz >/dev/null 2>&1; then
    echo -e "${GREEN}✅ Binary packages found in dist/${NC}"
    ls -la dist/cloudtolocalllm-*.tar.gz
else
    echo -e "${YELLOW}⚠️  No binary packages found in dist/${NC}"
fi

echo ""

# Final verification result
echo -e "${BLUE}🎯 Verification Summary${NC}"
echo -e "${BLUE}======================${NC}"

if [[ "$VERIFICATION_PASSED" = true ]]; then
    echo -e "${GREEN}🎉 DEPLOYMENT VERIFICATION PASSED!${NC}"
    echo -e "${GREEN}All components are synchronized with version $EXPECTED_FULL${NC}"
    echo ""
    echo -e "${BLUE}✅ Deployment is complete and ready for production use.${NC}"
    exit 0
else
    echo -e "${RED}❌ DEPLOYMENT VERIFICATION FAILED!${NC}"
    echo -e "${RED}Version mismatches or accessibility issues detected.${NC}"
    echo ""
    echo -e "${YELLOW}🔧 Required actions:${NC}"
    echo -e "  1. Fix version mismatches using: ./scripts/deploy/sync_versions.sh"
    echo -e "  2. Rebuild and redeploy affected components"
    echo -e "  3. Re-run verification: ./scripts/deploy/verify_deployment.sh"
    echo ""
    echo -e "${RED}⚠️  DO NOT CONSIDER DEPLOYMENT COMPLETE UNTIL ALL CHECKS PASS!${NC}"
    exit 1
fi
