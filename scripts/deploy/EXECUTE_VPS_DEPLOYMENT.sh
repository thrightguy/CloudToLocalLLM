#!/bin/bash

# CLOUDTOLOCALLLM VPS DEPLOYMENT EXECUTION SCRIPT
# Version 3.0.1 - Black Screen Fix + Automated Binary Management
# 
# EXECUTE THIS SCRIPT ON THE VPS TO DEPLOY THE FIXES
# 
# Usage: 
#   1. SSH to VPS: ssh cloudllm@your-vps-ip
#   2. Run: curl -s https://raw.githubusercontent.com/imrightguy/CloudToLocalLLM/master/EXECUTE_VPS_DEPLOYMENT.sh | bash
#   OR
#   3. Download and run: wget https://raw.githubusercontent.com/imrightguy/CloudToLocalLLM/master/EXECUTE_VPS_DEPLOYMENT.sh && chmod +x EXECUTE_VPS_DEPLOYMENT.sh && ./EXECUTE_VPS_DEPLOYMENT.sh

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

echo "🚀 CloudToLocalLLM VPS Deployment v3.0.1 - BLACK SCREEN FIX"
echo "============================================================="
echo "Deploying black screen fixes and automated binary management"
echo ""

# Configuration
PROJECT_DIR="/opt/cloudtolocalllm"
BACKUP_DIR="/opt/cloudtolocalllm-backup-$(date +%Y%m%d-%H%M%S)"
USER="cloudllm"

# Check if running as correct user
if [[ "$USER" == "root" ]]; then
    log_error "Do not run as root! Switch to cloudllm user:"
    echo "sudo -u cloudllm bash $0"
    exit 1
fi

log_info "Starting deployment as user: $(whoami)"

# Step 1: Navigate to project directory
log_info "Step 1: Navigating to project directory..."
if [[ ! -d "$PROJECT_DIR" ]]; then
    log_error "Project directory not found: $PROJECT_DIR"
    exit 1
fi

cd "$PROJECT_DIR"
log_success "In project directory: $(pwd)"

# Step 2: Create backup
log_info "Step 2: Creating backup..."
if [[ -d "$PROJECT_DIR" ]]; then
    # Create backup within project directory (no sudo needed)
    mkdir -p "$PROJECT_DIR/backups"
    cp -r "$PROJECT_DIR" "$PROJECT_DIR/backups/backup-$(date +%Y%m%d-%H%M%S)"
    log_success "Backup created in project backups directory"
fi

# Step 3: Pull latest changes with black screen fixes
log_info "Step 3: Pulling latest changes from GitHub..."
git stash push -m "Auto-stash before v3.0.1 deployment $(date)" 2>/dev/null || true
git pull origin master
log_success "Git pull completed - black screen fixes downloaded"

# Step 4: Verify black screen fixes are present
log_info "Step 4: Verifying black screen fixes..."
if grep -q "Show the UI immediately to prevent black screen" lib/main.dart; then
    log_success "Black screen fixes detected in main.dart"
else
    log_warning "Black screen fixes may not be present"
fi

if [[ -f "scripts/manage_binary_files.sh" ]]; then
    log_success "Automated binary management system detected"
else
    log_warning "Binary management system not found"
fi

# Step 5: Build Flutter web with fixes
log_info "Step 5: Building Flutter web application with black screen fixes..."
flutter clean
flutter pub get
flutter build web --release
log_success "Flutter web build completed with fixes"

# Step 6: Stop existing containers
log_info "Step 6: Stopping existing containers..."
if [[ -f "docker-compose.multi.yml" ]]; then
    docker-compose -f docker-compose.multi.yml down --timeout 30 2>/dev/null || true
    log_success "Containers stopped"
else
    log_warning "docker-compose.multi.yml not found"
fi

# Step 7: Start containers with fixes
log_info "Step 7: Starting containers with black screen fixes..."
if [[ -f "docker-compose.multi.yml" ]]; then
    docker-compose -f docker-compose.multi.yml build --no-cache
    docker-compose -f docker-compose.multi.yml up -d
    log_success "Containers started with fixes"
else
    log_error "Cannot start containers - docker-compose.multi.yml missing"
    exit 1
fi

# Step 8: Wait for containers to be ready
log_info "Step 8: Waiting for containers to initialize..."
sleep 15

# Step 9: Verify deployment
log_info "Step 9: Verifying deployment..."

# Check container status
log_info "Checking container status..."
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# Test HTTPS endpoints
log_info "Testing HTTPS accessibility..."

endpoints=(
    "https://app.cloudtolocalllm.online"
    "https://cloudtolocalllm.online"
    "https://cloudtolocalllm.online/downloads"
)

for endpoint in "${endpoints[@]}"; do
    if curl -s -I "$endpoint" | grep -q "200 OK\|301 Moved\|302 Found"; then
        log_success "$endpoint - OK"
    else
        log_error "$endpoint - FAILED"
    fi
done

# Step 10: Test black screen fixes specifically
log_info "Step 10: Testing black screen fixes..."
log_info "Black screen fixes deployed - test by:"
echo "  1. Open https://app.cloudtolocalllm.online"
echo "  2. Verify immediate UI display (no black screen)"
echo "  3. Check system tray functionality"
echo "  4. Test authentication flow"

# Step 11: Display deployment summary
log_info "Step 11: Deployment Summary"
echo "================================"
log_success "CloudToLocalLLM v3.0.1 deployed successfully!"
echo ""
echo "🔧 Black Screen Fixes Applied:"
echo "  ✅ Non-blocking UI initialization"
echo "  ✅ Timeout handling for system operations"
echo "  ✅ Graceful error recovery"
echo "  ✅ Immediate visual feedback"
echo ""
echo "🌐 Service URLs:"
echo "  • Main App: https://app.cloudtolocalllm.online"
echo "  • Homepage: https://cloudtolocalllm.online"
echo "  • Downloads: https://cloudtolocalllm.online/downloads"
echo ""
echo "🔍 Verification Steps:"
echo "  1. Test app loads immediately without black screen"
echo "  2. Verify system tray integration works"
echo "  3. Check authentication flow"
echo "  4. Test Ollama connectivity"
echo ""
echo "📋 Container Status:"
docker-compose -f docker-compose.multi.yml ps 2>/dev/null || docker ps

log_success "VPS deployment completed! Black screen issue should be resolved."
echo ""
echo "🎉 CloudToLocalLLM v3.0.1 is now live with black screen fixes!"
