#!/bin/bash

# CloudToLocalLLM Sudoless Deployment Configuration Script
# 
# PURPOSE: Configure the VPS environment so that all deployment operations
#          can be performed by the cloudllm user without sudo privileges
#
# USAGE: Run this script ONCE as root during initial VPS setup:
#        sudo bash scripts/setup/configure_sudoless_deployment.sh
#
# After running this script, all deployment operations should work
# without sudo using the cloudllm user account.

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
CLOUDLLM_USER="cloudllm"
PROJECT_DIR="/opt/cloudtolocalllm"
NGINX_UID=101
NGINX_GID=101

# Logging functions
log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] ✅${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] ⚠️${NC} $1"
}

log_error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ❌${NC} $1"
}

# Check if running as root
check_root_access() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root for initial setup"
        log_error "Usage: sudo bash scripts/setup/configure_sudoless_deployment.sh"
        exit 1
    fi
    log_warning "Running with root privileges for one-time setup ONLY"
}

# Ensure cloudllm user exists and has proper group memberships
setup_cloudllm_user() {
    log "Setting up cloudllm user..."
    
    # Create user if it doesn't exist
    if ! id "$CLOUDLLM_USER" &>/dev/null; then
        useradd -m -s /bin/bash "$CLOUDLLM_USER"
        log_success "Created cloudllm user"
    else
        log "cloudllm user already exists"
    fi
    
    # Add to docker group
    if getent group docker > /dev/null; then
        usermod -aG docker "$CLOUDLLM_USER"
        log_success "Added cloudllm to docker group"
    else
        log_warning "Docker group not found - install Docker first"
    fi
    
    # Ensure cloudllm owns the project directory
    if [[ -d "$PROJECT_DIR" ]]; then
        chown -R "$CLOUDLLM_USER:$CLOUDLLM_USER" "$PROJECT_DIR"
        log_success "Set cloudllm ownership of project directory"
    fi
}

# Create necessary directories with proper permissions
setup_directories() {
    log "Setting up directories with proper permissions..."
    
    # Create backup directory within project
    mkdir -p "$PROJECT_DIR/backups"
    chown "$CLOUDLLM_USER:$CLOUDLLM_USER" "$PROJECT_DIR/backups"
    chmod 755 "$PROJECT_DIR/backups"
    
    # Create certbot directories
    mkdir -p "$PROJECT_DIR/certbot/www"
    mkdir -p "$PROJECT_DIR/certbot/live"
    mkdir -p "$PROJECT_DIR/certbot/archive"
    chown -R "$CLOUDLLM_USER:$CLOUDLLM_USER" "$PROJECT_DIR/certbot"
    chmod -R 755 "$PROJECT_DIR/certbot"
    
    # Create static homepage directory
    mkdir -p "$PROJECT_DIR/static_homepage"
    chown "$CLOUDLLM_USER:$CLOUDLLM_USER" "$PROJECT_DIR/static_homepage"
    chmod 755 "$PROJECT_DIR/static_homepage"
    
    # Create dist directory
    mkdir -p "$PROJECT_DIR/dist"
    chown "$CLOUDLLM_USER:$CLOUDLLM_USER" "$PROJECT_DIR/dist"
    chmod 755 "$PROJECT_DIR/dist"
    
    # Create nginx cache directories
    mkdir -p /tmp/nginx-cache/{client_temp,proxy_temp,fastcgi_temp,uwsgi_temp,scgi_temp}
    chown -R $NGINX_UID:$NGINX_GID /tmp/nginx-cache
    chmod -R 755 /tmp/nginx-cache
    
    log_success "Directory setup completed"
}

# Configure Docker to work without sudo
configure_docker() {
    log "Configuring Docker for sudoless operation..."
    
    # Ensure Docker daemon is running
    systemctl enable docker
    systemctl start docker
    
    # Verify cloudllm can use Docker
    if sudo -u "$CLOUDLLM_USER" docker ps &>/dev/null; then
        log_success "Docker configured for sudoless operation"
    else
        log_warning "Docker may require logout/login for group membership to take effect"
    fi
}

# Set up file permissions for web serving
setup_web_permissions() {
    log "Setting up web serving permissions..."
    
    # Ensure build directory can be created and served
    mkdir -p "$PROJECT_DIR/build/web"
    chown -R "$CLOUDLLM_USER:$CLOUDLLM_USER" "$PROJECT_DIR/build"
    chmod -R 755 "$PROJECT_DIR/build"
    
    # Set up proper permissions for nginx to read files
    # Files will be owned by cloudllm but readable by nginx
    find "$PROJECT_DIR" -type d -exec chmod 755 {} \;
    find "$PROJECT_DIR" -type f -exec chmod 644 {} \;
    
    # Make scripts executable
    find "$PROJECT_DIR/scripts" -name "*.sh" -exec chmod +x {} \;
    
    log_success "Web serving permissions configured"
}

# Create a verification script
create_verification_script() {
    log "Creating deployment verification script..."
    
    cat > "$PROJECT_DIR/scripts/verify_sudoless_deployment.sh" << 'EOF'
#!/bin/bash

# Verify that deployment can work without sudo
echo "🔍 Verifying sudoless deployment configuration..."

# Check user and groups
echo "Current user: $(whoami)"
echo "Groups: $(groups)"

# Check Docker access
if docker ps &>/dev/null; then
    echo "✅ Docker access: OK"
else
    echo "❌ Docker access: FAILED"
    exit 1
fi

# Check directory permissions
if [[ -w "/opt/cloudtolocalllm" ]]; then
    echo "✅ Project directory writable: OK"
else
    echo "❌ Project directory writable: FAILED"
    exit 1
fi

# Check backup directory
if mkdir -p "/opt/cloudtolocalllm/backups/test" && rmdir "/opt/cloudtolocalllm/backups/test"; then
    echo "✅ Backup directory writable: OK"
else
    echo "❌ Backup directory writable: FAILED"
    exit 1
fi

echo "🎉 Sudoless deployment verification passed!"
EOF

    chmod +x "$PROJECT_DIR/scripts/verify_sudoless_deployment.sh"
    chown "$CLOUDLLM_USER:$CLOUDLLM_USER" "$PROJECT_DIR/scripts/verify_sudoless_deployment.sh"
    
    log_success "Verification script created"
}

# Main execution function
main() {
    log "🔧 CloudToLocalLLM Sudoless Deployment Configuration"
    log "=================================================="
    
    check_root_access
    
    log "Configuring environment for sudoless deployment..."
    
    setup_cloudllm_user
    setup_directories
    configure_docker
    setup_web_permissions
    create_verification_script
    
    log_success "🎉 Sudoless deployment configuration completed!"
    log ""
    log "📋 Next Steps:"
    log "  1. Switch to cloudllm user: su - cloudllm"
    log "  2. Navigate to project: cd $PROJECT_DIR"
    log "  3. Verify configuration: ./scripts/verify_sudoless_deployment.sh"
    log "  4. Run deployment: ./scripts/deploy/update_and_deploy.sh --force"
    log ""
    log_warning "🔒 Security Note: Root access was used ONLY for one-time setup"
    log_warning "🚀 All future deployments should run as cloudllm user without sudo"
}

# Error handling
trap 'log_error "Script failed at line $LINENO. Check logs above for details."' ERR

# Execute main function
main "$@"
