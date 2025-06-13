#!/bin/bash

# CloudToLocalLLM VPS Deployment Script
# Deploy the latest changes to the VPS with updated packages

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Configuration
PROJECT_DIR="/opt/cloudtolocalllm"
COMPOSE_FILE="docker-compose.multi.yml"
BACKUP_DIR="/opt/cloudtolocalllm/backups"

# Check if running as cloudllm user
check_user() {
    if [[ "$USER" == "root" ]]; then
        log_error "This script should not be run as root user"
        log_info "Please run as cloudllm user: sudo -u cloudllm $0"
        exit 1
    fi
    
    if [[ "$USER" != "cloudllm" ]]; then
        log_warning "Running as user: $USER (expected: cloudllm)"
        log_info "Continuing anyway..."
    fi
    
    log_success "User check passed"
}

# Check if we're in the right directory
check_directory() {
    if [[ ! -d "$PROJECT_DIR" ]]; then
        log_error "Project directory not found: $PROJECT_DIR"
        exit 1
    fi
    
    cd "$PROJECT_DIR"
    
    if [[ ! -f "$COMPOSE_FILE" ]]; then
        log_error "Docker compose file not found: $COMPOSE_FILE"
        exit 1
    fi
    
    log_success "Directory check passed"
}

# Create backup of current deployment
create_backup() {
    log_info "Creating backup of current deployment..."
    
    local backup_timestamp=$(date +"%Y%m%d_%H%M%S")
    local backup_path="$BACKUP_DIR/backup_$backup_timestamp"
    
    mkdir -p "$backup_path"
    
    # Backup docker-compose files
    cp docker-compose*.yml "$backup_path/" 2>/dev/null || true
    
    # Backup Flutter web build
    if [[ -d "build/web" ]]; then
        cp -r build/web "$backup_path/"
    fi
    
    # Backup nginx config
    if [[ -d "nginx" ]]; then
        cp -r nginx "$backup_path/"
    fi
    
    log_success "Backup created: $backup_path"
}

# Pull latest changes from Git
pull_latest_changes() {
    log_info "Pulling latest changes from Git..."
    
    # Stash any local changes
    git stash push -m "Auto-stash before deployment $(date)" || true
    
    # Pull latest changes
    git pull origin master
    
    log_success "Git pull completed"
}

# Stop existing containers
stop_containers() {
    log_info "Stopping existing containers..."
    
    # Stop containers gracefully
    docker-compose -f "$COMPOSE_FILE" down --timeout 30 || true
    
    # Clean up any orphaned containers
    docker container prune -f || true
    
    log_success "Containers stopped"
}

# Build and start containers
start_containers() {
    log_info "Building and starting containers..."
    
    # Build containers with no cache for updated static files
    docker-compose -f "$COMPOSE_FILE" build --no-cache
    
    # Start containers
    docker-compose -f "$COMPOSE_FILE" up -d
    
    log_success "Containers started"
}

# Verify deployment
verify_deployment() {
    log_info "Verifying deployment..."
    
    # Wait for containers to be ready
    sleep 10
    
    # Check container status
    local containers_status=$(docker-compose -f "$COMPOSE_FILE" ps --services --filter "status=running" | wc -l)
    local total_containers=$(docker-compose -f "$COMPOSE_FILE" ps --services | wc -l)
    
    if [[ "$containers_status" -eq "$total_containers" ]]; then
        log_success "All containers are running ($containers_status/$total_containers)"
    else
        log_error "Some containers are not running ($containers_status/$total_containers)"
        docker-compose -f "$COMPOSE_FILE" ps
        return 1
    fi
    
    # Test HTTPS accessibility
    log_info "Testing HTTPS accessibility..."
    
    if curl -I -s -f https://app.cloudtolocalllm.online > /dev/null; then
        log_success "HTTPS endpoint is accessible"
    else
        log_error "HTTPS endpoint is not accessible"
        return 1
    fi
    
    # Test download page
    if curl -I -s -f https://cloudtolocalllm.online/downloads.html > /dev/null; then
        log_success "Downloads page is accessible"
    else
        log_error "Downloads page is not accessible"
        return 1
    fi
    
    # Test package downloads
    if curl -I -s -f https://cloudtolocalllm.online/dist/debian/cloudtolocalllm_2.1.1_amd64.deb > /dev/null; then
        log_success "Debian package is downloadable"
    else
        log_error "Debian package is not accessible"
        return 1
    fi
    
    log_success "Deployment verification passed"
}

# Show deployment summary
show_summary() {
    log_info "Deployment Summary"
    echo "===================="
    echo "Project Directory: $PROJECT_DIR"
    echo "Compose File: $COMPOSE_FILE"
    echo "Deployment Time: $(date)"
    echo
    echo "Container Status:"
    docker-compose -f "$COMPOSE_FILE" ps
    echo
    echo "Available Endpoints:"
    echo "  - Homepage: https://cloudtolocalllm.online"
    echo "  - Web App: https://app.cloudtolocalllm.online"
    echo "  - Downloads: https://cloudtolocalllm.online/downloads.html"
    echo "  - Debian Package: https://cloudtolocalllm.online/dist/debian/cloudtolocalllm_2.1.1_amd64.deb"
    echo
    echo "Logs:"
    echo "  docker-compose -f $COMPOSE_FILE logs -f"
    echo
}

# Main deployment function
main() {
    log_info "Starting CloudToLocalLLM VPS deployment..."
    
    # Pre-deployment checks
    check_user
    check_directory
    
    # Create backup
    create_backup
    
    # Deploy
    pull_latest_changes
    stop_containers
    start_containers
    
    # Verify
    verify_deployment
    
    # Summary
    show_summary
    
    log_success "CloudToLocalLLM deployment completed successfully!"
}

# Handle command line arguments
case "${1:-}" in
    "--help"|"-h")
        echo "CloudToLocalLLM VPS Deployment Script"
        echo
        echo "Usage: $0 [options]"
        echo
        echo "Options:"
        echo "  --help, -h    Show this help message"
        echo
        echo "This script deploys the latest CloudToLocalLLM changes to the VPS."
        echo "It should be run as the cloudllm user on the VPS."
        exit 0
        ;;
    "")
        main
        ;;
    *)
        log_error "Unknown option: $1"
        echo "Use '$0 --help' for usage information"
        exit 1
        ;;
esac
