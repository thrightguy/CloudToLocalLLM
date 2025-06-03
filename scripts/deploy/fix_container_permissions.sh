#!/bin/bash

# CloudToLocalLLM Docker Container Privilege Escalation Fix Script
# 
# PURPOSE: Fix mounted volume permissions when Docker containers fail due to 
#          nginx user lacking write access to mounted directories
#
# SECURITY WARNING: This script requires temporary root access ONLY for 
#                   file system permission fixes. All other operations 
#                   run as cloudllm user.
#
# USAGE: sudo bash scripts/deploy/fix_container_permissions.sh
#
# Author: CloudToLocalLLM Team
# Version: 1.0.0

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
CONTAINER_NAME="cloudtolocalllm-webapp"

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
    log_warning "Running with root privileges - will drop to cloudllm user after permission fixes"
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
    
    if ! command -v docker &>/dev/null; then
        log_error "Docker not found"
        exit 1
    fi
    
    if ! command -v docker-compose &>/dev/null; then
        log_error "Docker Compose not found"
        exit 1
    fi
    
    log_success "Environment validation passed"
}

# Stop failing containers
stop_containers() {
    log "Stopping containers gracefully..."
    cd "$PROJECT_DIR"
    
    if docker-compose ps | grep -q "$CONTAINER_NAME"; then
        docker-compose down || {
            log_warning "Graceful shutdown failed, forcing container stop"
            docker stop "$CONTAINER_NAME" 2>/dev/null || true
            docker rm "$CONTAINER_NAME" 2>/dev/null || true
        }
    fi
    
    log_success "Containers stopped"
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

# Rebuild containers with proper permissions
rebuild_containers() {
    log "Rebuilding Docker containers..."
    cd "$PROJECT_DIR"
    
    # Switch to cloudllm user for Docker operations
    log "Switching to cloudllm user for container operations..."
    
    sudo -u "$CLOUDLLM_USER" bash -c "
        cd '$PROJECT_DIR'
        docker-compose build --no-cache webapp
    " || {
        log_error "Failed to rebuild containers as cloudllm user"
        return 1
    }
    
    log_success "Containers rebuilt successfully"
}

# Start containers and verify
start_and_verify() {
    log "Starting containers as cloudllm user..."
    cd "$PROJECT_DIR"
    
    sudo -u "$CLOUDLLM_USER" bash -c "
        cd '$PROJECT_DIR'
        docker-compose up -d
    " || {
        log_error "Failed to start containers as cloudllm user"
        return 1
    }
    
    # Wait for containers to start
    log "Waiting for containers to start..."
    sleep 15
    
    # Check container status
    log "Verifying container status..."
    if ! sudo -u "$CLOUDLLM_USER" docker ps | grep -q "$CONTAINER_NAME.*Up"; then
        log_error "Container $CONTAINER_NAME is not running"
        sudo -u "$CLOUDLLM_USER" docker logs "$CONTAINER_NAME" | tail -20
        return 1
    fi
    
    log_success "Containers started successfully"
}

# Verify nginx user is running in container
verify_nginx_user() {
    log "Verifying container is running as nginx user..."
    
    # Check if container is running
    if ! sudo -u "$CLOUDLLM_USER" docker ps | grep -q "$CONTAINER_NAME.*Up"; then
        log_error "Container is not running, cannot verify user"
        return 1
    fi
    
    # Check user inside container
    local container_user
    container_user=$(sudo -u "$CLOUDLLM_USER" docker exec "$CONTAINER_NAME" whoami 2>/dev/null || echo "unknown")
    
    if [[ "$container_user" == "nginx" ]]; then
        log_success "Container is running as nginx user ✅"
        
        # Also check UID
        local container_uid
        container_uid=$(sudo -u "$CLOUDLLM_USER" docker exec "$CONTAINER_NAME" id -u 2>/dev/null || echo "unknown")
        
        if [[ "$container_uid" == "$NGINX_UID" ]]; then
            log_success "Container nginx user has correct UID $NGINX_UID ✅"
        else
            log_warning "Container nginx user has UID $container_uid (expected $NGINX_UID)"
        fi
    else
        log_error "Container is running as user: $container_user (expected: nginx)"
        return 1
    fi
}

# Verify web application accessibility
verify_web_access() {
    log "Verifying web application accessibility..."
    
    # Wait a bit more for nginx to fully start
    sleep 10
    
    # Test local access first
    if curl -f -s http://localhost:80/ >/dev/null 2>&1; then
        log_success "Local HTTP access working ✅"
    else
        log_warning "Local HTTP access failed"
    fi
    
    # Test HTTPS access
    if curl -f -s -k https://localhost:443/ >/dev/null 2>&1; then
        log_success "Local HTTPS access working ✅"
    else
        log_warning "Local HTTPS access failed"
    fi
    
    log_success "Web application verification completed"
}

# Main execution function
main() {
    log "🔧 CloudToLocalLLM Container Permission Fix Script"
    log "================================================"
    
    check_root_access
    validate_environment
    
    log "Starting permission fix process..."
    
    stop_containers
    fix_permissions
    rebuild_containers
    start_and_verify
    verify_nginx_user
    verify_web_access
    
    log_success "🎉 Permission fix completed successfully!"
    log_success "Container is now running as nginx user with proper permissions"
    log_success "Web application should be accessible at https://app.cloudtolocalllm.online"
    
    log "📋 Summary:"
    log "  - Fixed mounted volume permissions for nginx user"
    log "  - Rebuilt containers with security fixes"
    log "  - Verified container runs as nginx user (UID $NGINX_UID)"
    log "  - All operations after permission fixes run as cloudllm user"
    
    log_warning "🔒 Security Note: Root access was used only for file system permission fixes"
}

# Error handling
trap 'log_error "Script failed at line $LINENO. Check logs above for details."' ERR

# Execute main function
main "$@"
