#!/bin/bash

# CloudToLocalLLM Docker Container Permission Fix Script
#
# PURPOSE: Fix mounted volume permissions for nginx user (UID 101)
#          ONLY handles file system permission fixes - NO container operations
#
# SECURITY WARNING: This script requires root access ONLY for file system
#                   permission fixes. Container operations should be run
#                   separately as cloudllm user.
#
# USAGE:
#   1. Run permission fixes as root: sudo bash scripts/deploy/fix_container_permissions.sh
#   2. Switch to cloudllm user: su - cloudllm
#   3. Run deployment: cd /opt/cloudtolocalllm && scripts/deploy/update_and_deploy.sh
#
# Author: CloudToLocalLLM Team
# Version: 2.0.0

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_DIR="/opt/cloudtolocalllm"
NGINX_UID=101
NGINX_GID=101
CLOUDLLM_USER="cloudllm"

# Logging function
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
        log_error "This script must be run as root for permission fixes"
        log_error "Usage: sudo bash scripts/deploy/fix_container_permissions.sh"
        exit 1
    fi
    log_warning "Running with root privileges for file system permission fixes ONLY"
}

# Validate environment
validate_environment() {
    log "Validating environment..."

    if [[ ! -d "$PROJECT_DIR" ]]; then
        log_error "Project directory $PROJECT_DIR not found"
        exit 1
    fi

    if ! id "$CLOUDLLM_USER" &>/dev/null; then
        log_error "User $CLOUDLLM_USER not found"
        exit 1
    fi

    log_success "Environment validation passed"
}

# Fix mounted volume permissions
fix_permissions() {
    log "Fixing mounted volume permissions..."
    
    # Create directories if they don't exist
    mkdir -p /var/www/certbot/.well-known/acme-challenge
    mkdir -p "$PROJECT_DIR/certbot/www"
    mkdir -p "$PROJECT_DIR/certbot/live"
    mkdir -p "$PROJECT_DIR/certbot/archive"
    
    # Fix certbot directory permissions
    log "Setting permissions for certbot directories..."
    chown -R $NGINX_UID:$NGINX_GID /var/www/certbot 2>/dev/null || {
        log_warning "Could not change ownership of /var/www/certbot (might be mounted read-only)"
    }
    chmod -R 755 /var/www/certbot 2>/dev/null || {
        log_warning "Could not change permissions of /var/www/certbot"
    }
    
    # Fix project certbot directories
    if [[ -d "$PROJECT_DIR/certbot" ]]; then
        chown -R $CLOUDLLM_USER:$CLOUDLLM_USER "$PROJECT_DIR/certbot"
        chmod -R 755 "$PROJECT_DIR/certbot"
        log_success "Fixed project certbot directory permissions"
    fi
    
    # Fix SSL certificate directories if they exist
    if [[ -d "$PROJECT_DIR/ssl" ]]; then
        chown -R $NGINX_UID:$NGINX_GID "$PROJECT_DIR/ssl"
        chmod -R 644 "$PROJECT_DIR/ssl"
        log_success "Fixed SSL directory permissions"
    fi
    
    # Create nginx cache directories with proper ownership
    log "Creating nginx cache directories..."
    mkdir -p /tmp/nginx-cache/{client_temp,proxy_temp,fastcgi_temp,uwsgi_temp,scgi_temp}
    chown -R $NGINX_UID:$NGINX_GID /tmp/nginx-cache
    chmod -R 755 /tmp/nginx-cache
    
    log_success "Permission fixes completed"
}



# Main execution function
main() {
    log "🔧 CloudToLocalLLM Permission Fix Script (File System Only)"
    log "========================================================="

    check_root_access
    validate_environment

    log "Starting file system permission fixes..."

    fix_permissions

    log_success "🎉 File system permission fixes completed successfully!"
    log_success "Mounted volumes now have proper permissions for nginx user (UID $NGINX_UID)"

    log "📋 Next Steps:"
    log "  1. Switch to cloudllm user: su - cloudllm"
    log "  2. Navigate to project: cd $PROJECT_DIR"
    log "  3. Run deployment: scripts/deploy/update_and_deploy.sh"

    log_warning "🔒 Security Note: Root access was used ONLY for file system permission fixes"
    log_warning "🚀 Container operations should be run separately as cloudllm user"
}

# Error handling
trap 'log_error "Script failed at line $LINENO. Check logs above for details."' ERR

# Execute main function
main "$@"
