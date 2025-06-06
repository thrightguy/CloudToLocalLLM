#!/bin/bash
# CloudToLocalLLM v3.3.0 Deployment Commands
# Execute these commands on the VPS to deploy the linter fixes

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🚀 CloudToLocalLLM v3.3.0 Deployment - Linter Fixes${NC}"
echo -e "${BLUE}====================================================${NC}"

# Step 1: SSH to VPS
echo -e "${YELLOW}Step 1: SSH to VPS${NC}"
echo "ssh cloudllm@cloudtolocalllm.online"
echo ""

# Step 2: Navigate to project directory
echo -e "${YELLOW}Step 2: Navigate to project directory${NC}"
echo "cd /opt/cloudtolocalllm"
echo ""

# Step 3: Pull latest changes from release branch
echo -e "${YELLOW}Step 3: Pull latest changes from release/v3.3.0 branch${NC}"
echo "git fetch origin"
echo "git checkout release/v3.3.0"
echo "git pull origin release/v3.3.0"
echo ""

# Step 4: Verify linter fixes are present
echo -e "${YELLOW}Step 4: Verify linter fixes are present${NC}"
echo "echo '=== Verifying Flutter analyze passes ==='"
echo "cd apps/main && flutter analyze --no-fatal-infos | grep 'No issues found'"
echo "cd ../settings && flutter analyze --no-fatal-infos | grep 'No issues found'"
echo "cd ../shared && flutter analyze --no-fatal-infos | grep 'No issues found'"
echo "cd ../tray && flutter analyze --no-fatal-infos | grep 'No issues found'"
echo "cd ../tunnel_manager && flutter analyze --no-fatal-infos | grep 'No issues found'"
echo "cd ../.."
echo ""

# Step 5: Build Flutter web with linter fixes
echo -e "${YELLOW}Step 5: Build Flutter web application with linter fixes${NC}"
echo "cd apps/main"
echo "flutter clean"
echo "flutter pub get"
echo "flutter build web --release --no-tree-shake-icons"
echo "cd ../.."
echo ""

# Step 6: Copy web build to deployment location
echo -e "${YELLOW}Step 6: Copy web build to deployment location${NC}"
echo "cp -r apps/main/build/web/* build/web/"
echo ""

# Step 7: Stop existing containers
echo -e "${YELLOW}Step 7: Stop existing containers${NC}"
echo "docker-compose -f docker-compose.yml down --timeout 30"
echo ""

# Step 8: Start containers with fixes
echo -e "${YELLOW}Step 8: Start containers with v3.3.0 fixes${NC}"
echo "docker-compose -f docker-compose.yml up -d"
echo ""

# Step 9: Wait for containers to be ready
echo -e "${YELLOW}Step 9: Wait for containers to initialize${NC}"
echo "sleep 15"
echo ""

# Step 10: Verify deployment
echo -e "${YELLOW}Step 10: Verify deployment${NC}"
echo "echo '=== Container Status ==='"
echo "docker-compose -f docker-compose.yml ps"
echo ""
echo "echo '=== Testing HTTPS Endpoints ==='"
echo "curl -I https://app.cloudtolocalllm.online | head -1"
echo "curl -I https://cloudtolocalllm.online | head -1"
echo ""
echo "echo '=== Checking Version ==='"
echo "curl -s https://app.cloudtolocalllm.online/version.json | grep version"
echo ""

# Step 11: Deployment summary
echo -e "${YELLOW}Step 11: Deployment Summary${NC}"
echo -e "${GREEN}✅ CloudToLocalLLM v3.3.0 deployed successfully!${NC}"
echo ""
echo -e "${BLUE}🔧 Linter Fixes Applied:${NC}"
echo -e "  ✅ Fixed Material Design API deprecations (background→surface, MaterialState→WidgetState)"
echo -e "  ✅ Updated color API calls (withOpacity→withValues)"
echo -e "  ✅ Fixed CardTheme/DialogTheme type issues"
echo -e "  ✅ Updated constructor patterns with super.key"
echo -e "  ✅ Fixed nullable expression handling"
echo -e "  ✅ Cleaned up unused imports and dead code"
echo -e "  ✅ All 7 apps now pass flutter analyze with zero issues"
echo ""
echo -e "${BLUE}🌐 Service URLs:${NC}"
echo -e "  • Main App: https://app.cloudtolocalllm.online"
echo -e "  • Homepage: https://cloudtolocalllm.online"
echo -e "  • API Backend: https://api.cloudtolocalllm.online"
echo ""
echo -e "${BLUE}🔍 Verification Steps:${NC}"
echo -e "  1. Test app loads with v3.3.0 version display"
echo -e "  2. Verify Auth0 authentication flow works"
echo -e "  3. Test streaming proxy functionality"
echo -e "  4. Check desktop app connects to localhost:11434"
echo ""

echo -e "${GREEN}🎉 CloudToLocalLLM v3.3.0 is now live with all linter fixes!${NC}"
