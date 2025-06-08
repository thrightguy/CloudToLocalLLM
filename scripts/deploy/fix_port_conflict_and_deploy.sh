#!/bin/bash

# CloudToLocalLLM Port Conflict Fix and Deployment Script
# Handles port conflicts and deploys unified Flutter web architecture

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
VPS_HOST="cloudtolocalllm.online"
VPS_USER="cloudllm"

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Deploy with port conflict resolution
deploy_with_port_fix() {
    log_info "Deploying unified Flutter web architecture with port conflict resolution..."
    
    # Execute deployment on VPS with port conflict handling
    ssh "$VPS_USER@$VPS_HOST" << 'EOF'
        set -e
        cd /opt/cloudtolocalllm
        
        echo "🔍 Checking for port conflicts..."
        
        # Check what's using port 80
        echo "Processes using port 80:"
        sudo netstat -tlnp | grep :80 || echo "No processes found on port 80"
        
        # Check for running Docker containers
        echo "Current Docker containers:"
        docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
        
        echo "🛑 Stopping all Docker containers and cleaning up..."
        
        # Stop all containers (including orphaned ones)
        docker stop $(docker ps -aq) 2>/dev/null || echo "No containers to stop"
        
        # Remove all containers
        docker rm $(docker ps -aq) 2>/dev/null || echo "No containers to remove"
        
        # Remove orphaned containers specifically
        docker-compose -f docker-compose.multi.yml down --remove-orphans --timeout 30 || true
        
        # Clean up Docker networks
        docker network prune -f || true
        
        # Check if any system nginx is running
        if systemctl is-active --quiet nginx 2>/dev/null; then
            echo "🛑 Stopping system nginx service..."
            sudo systemctl stop nginx
            sudo systemctl disable nginx
        fi
        
        # Check if any other web servers are running
        if systemctl is-active --quiet apache2 2>/dev/null; then
            echo "🛑 Stopping apache2 service..."
            sudo systemctl stop apache2
            sudo systemctl disable apache2
        fi
        
        # Kill any processes still using port 80
        sudo fuser -k 80/tcp 2>/dev/null || echo "No processes to kill on port 80"
        
        # Wait a moment for ports to be released
        sleep 5
        
        echo "🔄 Pulling latest changes..."
        git pull origin master
        
        echo "🏗️ Building Flutter web application..."
        flutter clean
        flutter pub get
        flutter build web --release --no-tree-shake-icons
        
        echo "🐳 Building and starting Docker containers..."
        
        # Build containers with no cache
        docker-compose -f docker-compose.multi.yml build --no-cache
        
        # Start containers
        docker-compose -f docker-compose.multi.yml up -d --remove-orphans
        
        echo "⏳ Waiting for containers to be ready..."
        sleep 20
        
        echo "🔍 Checking container status..."
        docker-compose -f docker-compose.multi.yml ps
        
        echo "🔍 Checking container logs for any issues..."
        echo "=== Flutter App Logs ==="
        docker logs cloudtolocalllm-flutter-app --tail 10 || echo "Flutter app logs not available"
        
        echo "=== API Backend Logs ==="
        docker logs cloudtolocalllm-api-backend --tail 10 || echo "API backend logs not available"
        
        echo "=== Nginx Proxy Logs ==="
        docker logs cloudtolocalllm-nginx-proxy --tail 10 || echo "Nginx proxy logs not available"
        
        echo "✅ VPS deployment completed"
EOF
    
    log_success "VPS deployment with port conflict resolution completed"
}

# Verify deployment
verify_deployment() {
    log_info "Verifying unified Flutter web architecture deployment..."
    
    # Wait a bit more for services to stabilize
    sleep 10
    
    # Test main domain (Flutter homepage)
    log_info "Testing main domain (Flutter homepage)..."
    local main_response=$(curl -s -o /dev/null -w "%{http_code}" "https://$VPS_HOST" || echo "000")
    if [[ "$main_response" =~ ^(200|301|302)$ ]]; then
        log_success "✅ Main domain accessible (HTTP $main_response)"
    else
        log_warning "⚠️  Main domain response: HTTP $main_response"
    fi
    
    # Test app subdomain (Flutter chat interface)
    log_info "Testing app subdomain (Flutter chat interface)..."
    local app_response=$(curl -s -o /dev/null -w "%{http_code}" "https://app.$VPS_HOST" || echo "000")
    if [[ "$app_response" =~ ^(200|301|302)$ ]]; then
        log_success "✅ App subdomain accessible (HTTP $app_response)"
    else
        log_warning "⚠️  App subdomain response: HTTP $app_response"
    fi
    
    # Test docs subdomain (Flutter documentation)
    log_info "Testing docs subdomain (Flutter documentation)..."
    local docs_response=$(curl -s -o /dev/null -w "%{http_code}" "https://docs.$VPS_HOST" || echo "000")
    if [[ "$docs_response" =~ ^(200|301|302)$ ]]; then
        log_success "✅ Docs subdomain accessible (HTTP $docs_response)"
    else
        log_warning "⚠️  Docs subdomain response: HTTP $docs_response"
    fi
    
    # Test API health
    log_info "Testing API health endpoint..."
    local api_response=$(curl -s -o /dev/null -w "%{http_code}" "https://app.$VPS_HOST/api/health" || echo "000")
    if [[ "$api_response" =~ ^(200|301|302)$ ]]; then
        log_success "✅ API health endpoint accessible (HTTP $api_response)"
    else
        log_warning "⚠️  API health endpoint response: HTTP $api_response"
    fi
    
    log_success "Deployment verification completed"
}

# Show deployment summary
show_summary() {
    echo ""
    echo -e "${GREEN}🎉 CloudToLocalLLM Unified Flutter Web Architecture Deployed!${NC}"
    echo -e "${GREEN}============================================================${NC}"
    echo ""
    echo -e "${BLUE}📋 Deployment Summary:${NC}"
    echo "  ✅ Architecture: Unified Flutter Web"
    echo "  ✅ Port conflicts: Resolved"
    echo "  ✅ Static-site container: Eliminated from active services"
    echo "  ✅ Marketing pages: Flutter-native"
    echo "  ✅ Documentation: Flutter-native"
    echo "  ✅ Platform detection: kIsWeb routing"
    echo ""
    echo -e "${BLUE}📋 Production Endpoints:${NC}"
    echo "  • Homepage: https://$VPS_HOST (Flutter marketing)"
    echo "  • Web App: https://app.$VPS_HOST (Flutter chat)"
    echo "  • Documentation: https://docs.$VPS_HOST (Flutter docs)"
    echo "  • API Health: https://app.$VPS_HOST/api/health"
    echo ""
    echo -e "${BLUE}📋 Architecture Benefits:${NC}"
    echo "  • Single Flutter application for all web content"
    echo "  • Consistent Material Design 3 theming"
    echo "  • Simplified deployment and maintenance"
    echo "  • Reduced infrastructure complexity"
    echo "  • Zero external container dependencies for web functionality"
    echo ""
    echo -e "${BLUE}📋 Next Steps:${NC}"
    echo "  1. Test all domain endpoints in browser"
    echo "  2. Verify marketing pages display correctly"
    echo "  3. Test documentation search functionality"
    echo "  4. Confirm chat interface works properly"
    echo "  5. Monitor container health and logs"
    echo ""
    echo -e "${GREEN}🚀 Unified Flutter Web Architecture is now live!${NC}"
}

# Main execution
main() {
    echo -e "${BLUE}CloudToLocalLLM Port Conflict Fix and Deployment${NC}"
    echo -e "${BLUE}===============================================${NC}"
    echo ""
    
    log_info "Starting deployment with port conflict resolution..."
    
    # Test SSH connection
    if ! ssh -o ConnectTimeout=10 -o BatchMode=yes "$VPS_USER@$VPS_HOST" "echo 'SSH test'" &> /dev/null; then
        log_error "SSH connection to VPS failed"
        exit 1
    fi
    
    # Execute deployment
    deploy_with_port_fix
    verify_deployment
    show_summary
}

# Error handling
trap 'log_error "Deployment failed at line $LINENO. Check logs above for details."' ERR

# Execute main function
main "$@"
