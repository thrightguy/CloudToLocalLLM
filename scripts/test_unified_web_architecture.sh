#!/bin/bash

# Test script for unified Flutter web architecture
# Verifies that the new domain routing and marketing pages work correctly

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

echo "🧪 Testing Unified Flutter Web Architecture"
echo "============================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Test 1: Verify Flutter analysis passes
echo
log_info "Test 1: Flutter Analysis"
if flutter analyze --no-fatal-infos --no-fatal-warnings; then
    log_success "Flutter analysis passed"
else
    log_error "Flutter analysis failed"
    exit 1
fi

# Test 2: Verify Flutter web build works
echo
log_info "Test 2: Flutter Web Build"
if flutter build web --release --no-tree-shake-icons > /dev/null 2>&1; then
    log_success "Flutter web build successful"
else
    log_error "Flutter web build failed"
    exit 1
fi

# Test 3: Verify marketing screens exist
echo
log_info "Test 3: Marketing Screens"
if [[ -f "lib/screens/marketing/homepage_screen.dart" ]]; then
    log_success "Homepage screen exists"
else
    log_error "Homepage screen missing"
    exit 1
fi

if [[ -f "lib/screens/marketing/download_screen.dart" ]]; then
    log_success "Download screen exists"
else
    log_error "Download screen missing"
    exit 1
fi

if [[ -f "lib/screens/marketing/documentation_screen.dart" ]]; then
    log_success "Documentation screen exists"
else
    log_error "Documentation screen missing"
    exit 1
fi

# Test 4: Verify router configuration
echo
log_info "Test 4: Router Configuration"
if grep -q "HomepageScreen" lib/config/router.dart; then
    log_success "Homepage route configured"
else
    log_error "Homepage route not found in router"
    exit 1
fi

if grep -q "DownloadScreen" lib/config/router.dart; then
    log_success "Download route configured"
else
    log_error "Download route not found in router"
    exit 1
fi

if grep -q "DocumentationScreen" lib/config/router.dart; then
    log_success "Documentation route configured"
else
    log_error "Documentation route not found in router"
    exit 1
fi

if grep -q "kIsWeb" lib/config/router.dart; then
    log_success "Platform detection configured"
else
    log_error "Platform detection not found in router"
    exit 1
fi

# Test 5: Verify nginx configuration
echo
log_info "Test 5: Nginx Configuration"
if grep -q "Flutter homepage" config/nginx/nginx-proxy.conf; then
    log_success "Nginx routing updated for main domain"
else
    log_error "Nginx configuration not updated"
    exit 1
fi

if grep -q "Chat interface" config/nginx/nginx-proxy.conf; then
    log_success "Nginx routing configured for app subdomain"
else
    log_error "App subdomain configuration missing"
    exit 1
fi

# Test 6: Verify Docker configuration
echo
log_info "Test 6: Docker Configuration"
if grep -q "DEPRECATED" docker-compose.multi.yml; then
    log_success "Static-site container fully deprecated"
else
    log_warning "Static-site container deprecation not found"
fi

if ! grep -q "container_name: cloudtolocalllm-static-site" docker-compose.multi.yml; then
    log_success "Static-site container removed from active services"
else
    log_warning "Static-site container still active"
fi

# Test 7: Verify documentation
echo
log_info "Test 7: Documentation"
if [[ -f "docs/ARCHITECTURE/UNIFIED_FLUTTER_WEB.md" ]]; then
    log_success "Architecture documentation exists"
else
    log_error "Architecture documentation missing"
    exit 1
fi

if grep -q "ARCHITECTURE UPDATE" docs/DEPLOYMENT/COMPLETE_DEPLOYMENT_WORKFLOW.md; then
    log_success "Deployment documentation updated"
else
    log_warning "Deployment documentation not updated"
fi

# Test 8: Verify build output structure
echo
log_info "Test 8: Build Output"
if [[ -d "build/web" ]]; then
    log_success "Web build directory exists"
    
    if [[ -f "build/web/index.html" ]]; then
        log_success "Web index.html exists"
    else
        log_error "Web index.html missing"
        exit 1
    fi
    
    if [[ -f "build/web/main.dart.js" ]]; then
        log_success "Flutter web assets exist"
    else
        log_error "Flutter web assets missing"
        exit 1
    fi
else
    log_error "Web build directory missing"
    exit 1
fi

echo
echo "🎉 All tests passed! Unified Flutter Web Architecture is ready."
echo
echo "Next steps:"
echo "1. Deploy the updated nginx configuration"
echo "2. Test domain routing in staging environment"
echo "3. Verify marketing pages on cloudtolocalllm.online"
echo "4. Confirm chat interface on app.cloudtolocalllm.online"
echo "5. Test documentation on docs.cloudtolocalllm.online"
echo
echo "For deployment, run:"
echo "  ./scripts/deploy/deploy-multi-container.sh"
echo
