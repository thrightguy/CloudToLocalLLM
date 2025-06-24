#!/bin/bash

# CloudToLocalLLM Complete Deployment Script
# Orchestrates the full deployment workflow with guided steps and rollback capabilities
# Combines build, deploy, and verification processes with proper error handling

set -euo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# VPS configuration
VPS_HOST="cloudtolocalllm.online"
VPS_USER="cloudllm"
VPS_PROJECT_DIR="/opt/cloudtolocalllm"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
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

log_step() {
    echo -e "${CYAN}[STEP $1]${NC} $2"
}

log_phase() {
    echo -e "${MAGENTA}=== PHASE $1: $2 ===${NC}"
}

# Global variables for rollback
BACKUP_CREATED=false
BACKUP_DIR=""
DEPLOYMENT_STARTED=false

# Cleanup function for rollback
cleanup_and_rollback() {
    local exit_code=$?
    
    if [[ $exit_code -ne 0 ]] && [[ "$DEPLOYMENT_STARTED" == "true" ]]; then
        log_error "Deployment failed. Initiating rollback..."
        
        if [[ "$BACKUP_CREATED" == "true" ]] && [[ -n "$BACKUP_DIR" ]]; then
            log_info "Rolling back to previous version..."
            ssh "$VPS_USER@$VPS_HOST" "cd $VPS_PROJECT_DIR && docker compose down && rm -rf webapp api-backend && mv $BACKUP_DIR/* . && rmdir $BACKUP_DIR && docker compose up -d"
            log_warning "Rollback completed. Previous version restored."
        else
            log_error "No backup available for rollback. Manual intervention required."
        fi
    fi
    
    exit $exit_code
}

# Set trap for cleanup
trap cleanup_and_rollback EXIT

# Get current version
get_version() {
    "$PROJECT_ROOT/scripts/version_manager.sh" get-semantic
}

# Pre-deployment checks
pre_deployment_checks() {
    log_phase 1 "PRE-DEPLOYMENT CHECKS"
    
    log_step 1.1 "Checking local environment..."
    
    # Check if Flutter is available
    if ! command -v flutter &> /dev/null; then
        log_error "Flutter is not installed or not in PATH"
        exit 1
    fi
    
    # Check if we're in the correct directory
    if [[ ! -f "$PROJECT_ROOT/pubspec.yaml" ]]; then
        log_error "Not in CloudToLocalLLM project directory"
        exit 1
    fi
    
    # Check VPS connectivity
    log_step 1.2 "Checking VPS connectivity..."
    if ! ssh -o ConnectTimeout=10 "$VPS_USER@$VPS_HOST" "echo 'VPS accessible'" >/dev/null 2>&1; then
        log_error "Cannot connect to VPS: $VPS_USER@$VPS_HOST"
        exit 1
    fi
    
    # Check if Docker is running on VPS
    log_step 1.3 "Checking Docker on VPS..."
    if ! ssh "$VPS_USER@$VPS_HOST" "docker --version" >/dev/null 2>&1; then
        log_error "Docker is not available on VPS"
        exit 1
    fi
    
    log_success "Pre-deployment checks passed"
}

# Build application
build_application() {
    log_phase 2 "APPLICATION BUILD"
    
    local version=$(get_version)
    log_info "Building CloudToLocalLLM version: $version"
    
    log_step 2.1 "Updating version information..."
    "$PROJECT_ROOT/scripts/version_manager.sh" update-build-number
    
    log_step 2.2 "Installing Flutter dependencies..."
    cd "$PROJECT_ROOT"
    flutter pub get
    
    log_step 2.3 "Building Flutter web application..."
    flutter build web --release --web-renderer html
    
    if [[ ! -d "$PROJECT_ROOT/build/web" ]]; then
        log_error "Flutter web build failed - build directory not found"
        exit 1
    fi
    
    log_success "Application build completed successfully"
}

# Create backup on VPS
create_backup() {
    log_phase 3 "BACKUP CREATION"
    
    log_step 3.1 "Creating backup of current deployment..."
    
    BACKUP_DIR="backup_$(date +%Y%m%d_%H%M%S)"
    
    ssh "$VPS_USER@$VPS_HOST" "cd $VPS_PROJECT_DIR && mkdir -p $BACKUP_DIR && cp -r webapp api-backend docker-compose.yml $BACKUP_DIR/ 2>/dev/null || true"
    
    # Verify backup was created
    if ssh "$VPS_USER@$VPS_HOST" "cd $VPS_PROJECT_DIR && test -d $BACKUP_DIR"; then
        BACKUP_CREATED=true
        log_success "Backup created: $BACKUP_DIR"
    else
        log_warning "Backup creation failed or no existing deployment found"
        BACKUP_CREATED=false
    fi
}

# Deploy to VPS
deploy_to_vps() {
    log_phase 4 "VPS DEPLOYMENT"
    
    DEPLOYMENT_STARTED=true
    
    log_step 4.1 "Stopping existing containers..."
    ssh "$VPS_USER@$VPS_HOST" "cd $VPS_PROJECT_DIR && docker compose down || true"
    
    log_step 4.2 "Uploading new Flutter web build..."
    rsync -avz --delete "$PROJECT_ROOT/build/web/" "$VPS_USER@$VPS_HOST:$VPS_PROJECT_DIR/webapp/"
    
    log_step 4.3 "Uploading API backend..."
    rsync -avz --delete "$PROJECT_ROOT/api-backend/" "$VPS_USER@$VPS_HOST:$VPS_PROJECT_DIR/api-backend/"
    
    log_step 4.4 "Uploading Docker configuration..."
    scp "$PROJECT_ROOT/docker-compose.yml" "$VPS_USER@$VPS_HOST:$VPS_PROJECT_DIR/"
    
    log_step 4.5 "Starting new containers..."
    ssh "$VPS_USER@$VPS_HOST" "cd $VPS_PROJECT_DIR && docker compose up -d"
    
    log_success "Deployment to VPS completed"
}

# Wait for services to start
wait_for_services() {
    log_phase 5 "SERVICE STARTUP"
    
    log_step 5.1 "Waiting for services to start..."
    
    local max_attempts=30
    local attempt=1
    
    while [[ $attempt -le $max_attempts ]]; do
        log_info "Attempt $attempt/$max_attempts - Checking service health..."
        
        if curl -s --connect-timeout 5 "http://app.cloudtolocalllm.online" >/dev/null 2>&1; then
            log_success "Services are responding"
            break
        fi
        
        if [[ $attempt -eq $max_attempts ]]; then
            log_error "Services failed to start within expected time"
            exit 1
        fi
        
        sleep 10
        ((attempt++))
    done
}

# Run deployment verification
run_verification() {
    log_phase 6 "DEPLOYMENT VERIFICATION"
    
    log_step 6.1 "Running comprehensive deployment verification..."
    
    if "$SCRIPT_DIR/verify_deployment.sh"; then
        log_success "Deployment verification passed"
    else
        log_error "Deployment verification failed"
        exit 1
    fi
}

# Cleanup successful deployment
cleanup_successful_deployment() {
    log_phase 7 "CLEANUP"
    
    if [[ "$BACKUP_CREATED" == "true" ]] && [[ -n "$BACKUP_DIR" ]]; then
        log_step 7.1 "Cleaning up backup (deployment successful)..."
        ssh "$VPS_USER@$VPS_HOST" "cd $VPS_PROJECT_DIR && rm -rf $BACKUP_DIR"
        log_success "Backup cleanup completed"
    fi
    
    log_step 7.2 "Cleaning up old Docker images..."
    ssh "$VPS_USER@$VPS_HOST" "docker image prune -f" >/dev/null 2>&1 || true
    
    log_success "Cleanup completed"
}

# Generate deployment report
generate_deployment_report() {
    local version=$(get_version)
    
    echo
    echo "=== CloudToLocalLLM Deployment Report ==="
    echo "Timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "Version Deployed: $version"
    echo "VPS Host: $VPS_HOST"
    echo "Deployment Status: SUCCESS"
    echo
    echo "✅ Application built successfully"
    echo "✅ Deployed to VPS without errors"
    echo "✅ All services started properly"
    echo "✅ Verification checks passed"
    echo "✅ Backup and cleanup completed"
    echo
    echo "Access URLs:"
    echo "- Flutter Homepage: http://cloudtolocalllm.online"
    echo "- Flutter Web App: http://app.cloudtolocalllm.online"
    echo "- HTTPS Homepage: https://cloudtolocalllm.online"
    echo "- HTTPS Web App: https://app.cloudtolocalllm.online"
    echo
    echo "Next steps:"
    echo "1. Monitor application logs for any issues"
    echo "2. Test key functionality manually"
    echo "3. Update documentation if needed"
    echo "4. Notify team of successful deployment"
    echo
}

# Interactive confirmation
confirm_deployment() {
    local version=$(get_version)
    
    echo
    echo "=== CloudToLocalLLM Complete Deployment ==="
    echo "Version to deploy: $version"
    echo "Target VPS: $VPS_USER@$VPS_HOST"
    echo
    echo "This will:"
    echo "1. Build Flutter web application"
    echo "2. Create backup of current deployment"
    echo "3. Deploy new version to VPS"
    echo "4. Verify deployment health"
    echo "5. Cleanup on success or rollback on failure"
    echo
    
    read -p "Do you want to proceed with deployment? (y/N): " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Deployment cancelled by user"
        exit 0
    fi
}

# Main execution function
main() {
    log_info "CloudToLocalLLM Complete Deployment Script"
    echo
    
    # Interactive confirmation unless --yes flag is provided
    if [[ "${1:-}" != "--yes" ]]; then
        confirm_deployment
    fi
    
    # Execute deployment phases
    pre_deployment_checks
    echo
    
    build_application
    echo
    
    create_backup
    echo
    
    deploy_to_vps
    echo
    
    wait_for_services
    echo
    
    run_verification
    echo
    
    cleanup_successful_deployment
    echo
    
    # Generate final report
    generate_deployment_report
    
    log_success "Complete deployment finished successfully!"
    
    # Disable trap since we succeeded
    trap - EXIT
}

# Handle script arguments
case "${1:-}" in
    --help|-h)
        echo "CloudToLocalLLM Complete Deployment Script"
        echo
        echo "Usage: $0 [options]"
        echo
        echo "Options:"
        echo "  --yes          Skip interactive confirmation"
        echo "  --help, -h     Show this help message"
        echo
        echo "This script orchestrates the complete deployment workflow:"
        echo "  1. Pre-deployment environment checks"
        echo "  2. Flutter web application build"
        echo "  3. VPS backup creation"
        echo "  4. Deployment to VPS with Docker"
        echo "  5. Service startup verification"
        echo "  6. Comprehensive health checks"
        echo "  7. Cleanup or automatic rollback"
        echo
        echo "Requirements:"
        echo "  - Flutter SDK installed and in PATH"
        echo "  - SSH access to $VPS_USER@$VPS_HOST"
        echo "  - rsync, curl commands available"
        echo "  - Docker running on VPS"
        echo
        echo "Safety features:"
        echo "  - Automatic backup before deployment"
        echo "  - Rollback on failure"
        echo "  - Comprehensive verification"
        echo "  - Interactive confirmation"
        echo
        exit 0
        ;;
esac

# Run main function
main "$@"
