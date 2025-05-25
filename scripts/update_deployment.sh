#!/bin/bash

# CloudToLocalLLM Update Deployment Script (Non-Root)
# This script updates the CloudToLocalLLM application with the latest changes
# Requires: Docker group membership, existing deployment

set -e  # Exit on any error
set -u  # Exit on undefined variables

# Colors for output
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly RED='\033[0;31m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
readonly LOG_FILE="${PROJECT_DIR}/update.log"
readonly TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# Logging functions
log() {
    echo -e "${1}" | tee -a "${LOG_FILE}"
}

log_info() {
    log "${BLUE}[INFO ${TIMESTAMP}]${NC} ${1}"
}

log_success() {
    log "${GREEN}[SUCCESS ${TIMESTAMP}]${NC} ${1}"
}

log_warning() {
    log "${YELLOW}[WARNING ${TIMESTAMP}]${NC} ${1}"
}

log_error() {
    log "${RED}[ERROR ${TIMESTAMP}]${NC} ${1}"
}

# Function to pull latest changes from git
pull_changes() {
    log_info "Pulling latest changes from git..."
    
    cd "${PROJECT_DIR}"
    
    # Check if we're in a git repository
    if [ ! -d ".git" ]; then
        log_error "Not in a git repository. Cannot pull changes."
        exit 1
    fi
    
    # Pull latest changes
    git pull origin master || {
        log_error "Failed to pull latest changes from git"
        exit 1
    }
    
    log_success "Latest changes pulled successfully."
}

# Function to rebuild Flutter application
rebuild_flutter() {
    log_info "Rebuilding Flutter application..."
    
    cd "${PROJECT_DIR}"
    
    # Clean previous build
    if [ -d "build" ]; then
        rm -rf build
    fi
    
    # Get dependencies
    flutter pub get || {
        log_error "Failed to get Flutter dependencies"
        exit 1
    }
    
    # Build web application
    flutter build web --release --web-renderer html || {
        log_error "Failed to build Flutter web application"
        exit 1
    }
    
    log_success "Flutter application rebuilt successfully."
}

# Function to restart Docker containers
restart_containers() {
    log_info "Restarting Docker containers..."
    
    cd "${PROJECT_DIR}"
    
    # Stop existing containers
    docker compose down || {
        log_warning "Failed to stop containers gracefully, forcing stop..."
        docker stop $(docker ps -q --filter "name=cloudtolocalllm") 2>/dev/null || true
    }
    
    # Start containers with rebuild
    docker compose up -d --build || {
        log_error "Failed to start Docker containers"
        exit 1
    }
    
    log_success "Docker containers restarted successfully."
}

# Function to verify update
verify_update() {
    log_info "Verifying update..."
    
    # Wait for containers to start
    sleep 10
    
    # Check if containers are running
    if ! docker ps --filter "name=cloudtolocalllm" --format "table {{.Names}}\t{{.Status}}" | grep -q "Up"; then
        log_error "Containers are not running after update"
        docker ps --filter "name=cloudtolocalllm"
        exit 1
    fi
    
    # Check if web application is responding
    local max_attempts=15
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if curl -f http://localhost:80/health_internal >/dev/null 2>&1; then
            log_success "Web application is responding after update."
            break
        fi
        
        log_info "Waiting for web application to respond... (attempt $attempt/$max_attempts)"
        sleep 2
        ((attempt++))
    done
    
    if [ $attempt -gt $max_attempts ]; then
        log_error "Web application failed to respond after update"
        docker logs cloudtolocalllm-webapp --tail 20
        exit 1
    fi
    
    log_success "Update verification completed successfully."
}

# Main function
main() {
    log_info "Starting CloudToLocalLLM update deployment..."
    
    # Pull latest changes
    pull_changes
    
    # Rebuild Flutter application
    rebuild_flutter
    
    # Restart containers
    restart_containers
    
    # Verify update
    verify_update
    
    log_success "CloudToLocalLLM update completed successfully!"
    log_info "Application is available at:"
    log_info "- Homepage: http://cloudtolocalllm.online"
    log_info "- Web App: http://app.cloudtolocalllm.online"
    
    if [ -d "${PROJECT_DIR}/certbot/live/cloudtolocalllm.online" ]; then
        log_info "- HTTPS Homepage: https://cloudtolocalllm.online"
        log_info "- HTTPS Web App: https://app.cloudtolocalllm.online"
    fi
}

# Run main function
main "$@"
