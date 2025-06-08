#!/bin/bash

# CloudToLocalLLM VPS Deployment Script v3.4.0+
# Enhanced with automation flags for CI/CD pipeline support

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# Flags
FORCE=false
VERBOSE=false
SKIP_BACKUP=false
DRY_RUN=false

# Logging functions
log() {
    echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[$(date '+%H:%M:%S')] ✅${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[$(date '+%H:%M:%S')] ⚠️${NC} $1"
}

log_error() {
    echo -e "${RED}[$(date '+%H:%M:%S')] ❌${NC} $1"
}

log_verbose() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "${BLUE}[$(date '+%H:%M:%S')] [VERBOSE]${NC} $1"
    fi
}

# Usage information
show_usage() {
    cat << EOF
CloudToLocalLLM VPS Deployment Script

USAGE:
    $0 [OPTIONS]

OPTIONS:
    --force             Skip confirmation prompts
    --verbose           Enable detailed logging
    --skip-backup       Skip backup creation for faster deployment
    --dry-run           Simulate deployment without actual changes
    --help              Show this help message

EXAMPLES:
    $0                  # Interactive deployment
    $0 --force          # Automated deployment
    $0 --verbose        # Detailed logging
    $0 --dry-run        # Simulate deployment

EXIT CODES:
    0 - Success
    1 - General error
    2 - Validation failure
    3 - Build failure
    4 - Deployment failure
EOF
}

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --force)
                FORCE=true
                shift
                ;;
            --verbose)
                VERBOSE=true
                shift
                ;;
            --skip-backup)
                SKIP_BACKUP=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --help)
                show_usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
}

# Header
echo -e "${BLUE}CloudToLocalLLM VPS Deployment v3.4.0+${NC}"
echo -e "${BLUE}=======================================${NC}"

# Check if we're on VPS or local development
if [[ "$HOSTNAME" == *"cloudtolocalllm"* ]] || [[ "$USER" == "cloudllm" ]]; then
    VPS_MODE=true
    log "Running in VPS mode"
else
    VPS_MODE=false
    log "Running in local development mode"
fi

# Create backup if not skipped
create_backup() {
    if [[ "$SKIP_BACKUP" == "true" ]]; then
        log "Skipping backup creation (--skip-backup flag)"
        return 0
    fi

    log "Creating deployment backup..."

    local backup_dir="/opt/cloudtolocalllm-backup-$(date +%Y%m%d-%H%M%S)"

    if [[ "$DRY_RUN" == "true" ]]; then
        log "DRY RUN: Would create backup at $backup_dir"
        return 0
    fi

    # Create backup of current deployment
    if [[ -d "build/web" ]]; then
        sudo mkdir -p "$backup_dir"
        sudo cp -r build/web "$backup_dir/"
        log_verbose "Backup created at: $backup_dir"
        log_success "Backup created"
    else
        log_warning "No existing build to backup"
    fi
}

# Pull latest changes from GitHub (primary source of truth)
pull_latest_changes() {
    log "Pulling latest changes from GitHub..."

    if [[ "$DRY_RUN" == "true" ]]; then
        log "DRY RUN: Would execute: git pull origin master"
        return 0
    fi

    if [[ "$VERBOSE" == "true" ]]; then
        git pull origin master
    else
        git pull origin master &> /dev/null
    fi

    log_success "Latest changes pulled"
}

# Build Flutter web application
build_flutter_web() {
    log "Building Flutter web application..."

    if [[ "$DRY_RUN" == "true" ]]; then
        log "DRY RUN: Would execute Flutter build commands"
        return 0
    fi

    # Clean previous builds
    log_verbose "Cleaning previous builds..."
    if [[ "$VERBOSE" == "true" ]]; then
        flutter clean
    else
        flutter clean &> /dev/null
    fi

    # Get dependencies
    log_verbose "Getting dependencies..."
    if [[ "$VERBOSE" == "true" ]]; then
        flutter pub get
    else
        flutter pub get &> /dev/null
    fi

    # Check version for release status (local development mode only)
    if [[ "$VPS_MODE" == "false" ]]; then
        local current_version=$(grep "^version:" pubspec.yaml | cut -d' ' -f2 | cut -d'+' -f1)
        log_verbose "Current version: $current_version"

        if command -v gh &> /dev/null && gh auth status &> /dev/null; then
            if ! gh release view "v$current_version" --repo "imrightguy/CloudToLocalLLM" &> /dev/null; then
                log_warning "No GitHub release found for v$current_version"
                log_warning "Consider running: ./scripts/release/create_github_release.sh"
            else
                log_verbose "GitHub release v$current_version exists"
            fi
        fi
    fi

    # Build web application
    log_verbose "Building web application..."
    if [[ "$VERBOSE" == "true" ]]; then
        flutter build web --no-tree-shake-icons
    else
        flutter build web --no-tree-shake-icons &> /dev/null
    fi

    log_success "Flutter web build completed"
}

# Manage containers
manage_containers() {
    log "Managing Docker containers..."

    if [[ "$DRY_RUN" == "true" ]]; then
        log "DRY RUN: Would stop and restart containers"
        return 0
    fi

    # Stop running containers
    log_verbose "Stopping existing containers..."
    if [[ "$VERBOSE" == "true" ]]; then
        docker-compose -f docker-compose.yml down
    else
        docker-compose -f docker-compose.yml down &> /dev/null
    fi

    # Check SSL certificates
    if [ -d "certbot/live/cloudtolocalllm.online" ]; then
        log_verbose "SSL certificates found, starting services..."
        if [[ "$VERBOSE" == "true" ]]; then
            docker-compose -f docker-compose.yml up -d
        else
            docker-compose -f docker-compose.yml up -d &> /dev/null
        fi
    else
        log_error "SSL certificates not found"
        log_error "Please set up SSL certificates first:"
        log_error "certbot certonly --webroot -w /var/www/html -d cloudtolocalllm.online -d app.cloudtolocalllm.online"
        exit 4
    fi

    log_success "Container management completed"
}

# Health checks
perform_health_checks() {
    log "Performing health checks..."

    if [[ "$DRY_RUN" == "true" ]]; then
        log "DRY RUN: Would perform health checks"
        return 0
    fi

    # Wait for containers to start
    log_verbose "Waiting for containers to start..."
    sleep 10

    # Check container health
    log_verbose "Checking container status..."
    if [[ "$VERBOSE" == "true" ]]; then
        docker-compose -f docker-compose.yml ps
    fi

    # Verify web app accessibility
    log_verbose "Testing web app accessibility..."
    local max_attempts=5
    local attempt=1

    while [[ $attempt -le $max_attempts ]]; do
        if curl -s -o /dev/null -w "%{http_code}" https://app.cloudtolocalllm.online | grep -q "200\|301\|302"; then
            log_success "Web app is accessible at https://app.cloudtolocalllm.online"
            return 0
        fi

        log_verbose "Attempt $attempt/$max_attempts failed, retrying in 5 seconds..."
        sleep 5
        ((attempt++))
    done

    log_error "Web app accessibility check failed after $max_attempts attempts"
    log_error "Check logs with: docker-compose -f docker-compose.yml logs"
    exit 4
}

# Display deployment summary
display_summary() {
    echo ""
    log_success "🎉 VPS deployment completed successfully!"
    echo ""
    echo -e "${GREEN}📋 Deployment Summary${NC}"
    echo -e "${GREEN}=====================${NC}"
    echo "  - Main site: https://cloudtolocalllm.online"
    echo "  - Web app: https://app.cloudtolocalllm.online"

    if [[ "$DRY_RUN" == "true" ]]; then
        echo ""
        echo -e "${YELLOW}📋 DRY RUN completed - no actual deployment performed${NC}"
    fi
}

# Main execution
main() {
    # Parse command line arguments
    parse_arguments "$@"

    # Confirmation prompt (unless force or dry-run)
    if [[ "$FORCE" != "true" && "$DRY_RUN" != "true" ]]; then
        echo -e "${YELLOW}⚠️  About to deploy to production VPS${NC}"
        read -p "Continue? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log "Deployment cancelled by user"
            exit 0
        fi
    fi

    # Execute deployment phases
    create_backup
    pull_latest_changes
    build_flutter_web
    manage_containers
    perform_health_checks
    display_summary
}

# Error handling
trap 'log_error "Deployment failed at line $LINENO. Check logs above for details."' ERR

# Execute main function
main "$@"