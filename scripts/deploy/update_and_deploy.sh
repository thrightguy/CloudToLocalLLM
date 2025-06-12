#!/bin/bash

# CloudToLocalLLM VPS Deployment Script v3.5.5+
# Enhanced with automation flags for CI/CD pipeline support
# Robust network operations and timeout handling

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load deployment utilities if available
if [[ -f "$SCRIPT_DIR/deployment_utils.sh" ]]; then
    source "$SCRIPT_DIR/deployment_utils.sh"
fi

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
    $0                  # Non-interactive deployment with 3-second delay
    $0 --force          # Automated deployment (CI/CD compatible)
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
echo -e "${BLUE}CloudToLocalLLM VPS Deployment v3.4.1+${NC}"
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

    # Use backups directory within the project (owned by cloudllm user)
    local backup_dir="backups/backup-$(date +%Y%m%d-%H%M%S)"

    if [[ "$DRY_RUN" == "true" ]]; then
        log "DRY RUN: Would create backup at $backup_dir"
        return 0
    fi

    # Create backup of current deployment (no sudo needed)
    if [[ -d "build/web" ]]; then
        mkdir -p "$backup_dir"
        cp -r build/web "$backup_dir/"
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

    # Use enhanced git operations if available, otherwise fallback to basic git
    if command -v git_execute &> /dev/null; then
        if ! git_execute pull origin master; then
            log_error "Failed to pull latest changes from GitHub"
            exit 4
        fi
    else
        # Fallback with timeout
        if [[ "$VERBOSE" == "true" ]]; then
            if ! timeout 120 git pull origin master; then
                log_error "Git pull timed out or failed"
                exit 4
            fi
        else
            if ! timeout 120 git pull origin master &> /dev/null; then
                log_error "Git pull timed out or failed"
                exit 4
            fi
        fi
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

    # Build web application with build-time timestamp injection
    log_verbose "Building web application with build-time timestamp injection..."
    local build_timeout=600  # 10 minutes for Flutter build

    # Check if build-time injection is available
    local build_script="./scripts/flutter_build_with_timestamp.sh"
    local build_injector="./scripts/build_time_version_injector.sh"
    local build_injection_available=false

    if [[ -f "$build_script" && -x "$build_script" && -f "$build_injector" && -x "$build_injector" ]]; then
        build_injection_available=true
        log_verbose "Build-time timestamp injection available"
    else
        log_warning "Build-time injection components not available, using fallback"
    fi

    if [[ "$build_injection_available" == "true" ]]; then
        # Use build-time timestamp injection wrapper
        local build_args="web --no-tree-shake-icons"

        if [[ "$VERBOSE" == "true" ]]; then
            build_args="--verbose $build_args"
        fi

        if [[ "$DRY_RUN" == "true" ]]; then
            build_args="--dry-run $build_args"
        fi

        if ! timeout $build_timeout "$build_script" $build_args; then
            log_error "Flutter web build with timestamp injection timed out or failed"
            exit 3
        fi

        log_success "Web application built with build-time timestamp injection"
    else
        # Fallback to direct Flutter build (legacy mode)
        log_warning "Using fallback Flutter build (no timestamp injection)"

        if [[ "$DRY_RUN" == "true" ]]; then
            log "DRY RUN: Would execute: flutter build web --no-tree-shake-icons"
        else
            if [[ "$VERBOSE" == "true" ]]; then
                if ! timeout $build_timeout flutter build web --no-tree-shake-icons; then
                    log_error "Flutter web build timed out or failed"
                    exit 3
                fi
            else
                if ! timeout $build_timeout flutter build web --no-tree-shake-icons &> /dev/null; then
                    log_error "Flutter web build timed out or failed"
                    exit 3
                fi
            fi
        fi

        log_success "Web application built (fallback mode)"
    fi

    log_success "Flutter web build completed"
}

# Update static distribution files from repository
update_static_distribution() {
    log "Updating static distribution files from repository..."

    if [[ "$DRY_RUN" == "true" ]]; then
        log "DRY RUN: Would copy distribution files from dist/ to static_homepage/"
        return 0
    fi

    # Copy unified package files from repository to static homepage
    local version=$(grep '^version:' pubspec.yaml | sed 's/version: *\([0-9.]*\).*/\1/')
    local dist_files=(
        "cloudtolocalllm-${version}-x86_64.tar.gz"
        "cloudtolocalllm-${version}-x86_64.tar.gz.sha256"
        "cloudtolocalllm-${version}-x86_64-aur-info.txt"
    )

    for file in "${dist_files[@]}"; do
        if [[ -f "dist/$file" ]]; then
            log_verbose "Copying $file to static homepage..."
            cp "dist/$file" "static_homepage/"
            chmod 644 "static_homepage/$file"
        else
            log_warning "Distribution file not found: dist/$file"
        fi
    done

    # Update download metadata
    local version=$(grep '^version:' pubspec.yaml | sed 's/version: *\([0-9.]*\).*/\1/')
    local package_file="cloudtolocalllm-${version}-x86_64.tar.gz"

    if [[ -f "static_homepage/$package_file" ]]; then
        local package_size=$(du -h "static_homepage/$package_file" | cut -f1)

        cat > "static_homepage/latest.json" << EOF
{
  "version": "$version",
  "package_file": "$package_file",
  "package_size": "$package_size",
  "upload_date": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "download_url": "https://cloudtolocalllm.online/$package_file"
}
EOF
        chmod 644 "static_homepage/latest.json"
        log_verbose "Updated download metadata"
    fi

    log_success "Static distribution files updated from repository"
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
        docker compose -f docker-compose.yml down
    else
        docker compose -f docker-compose.yml down &> /dev/null
    fi

    # Check SSL certificates
    if [ -d "certbot/live/cloudtolocalllm.online" ]; then
        log_verbose "SSL certificates found, starting services..."
        if [[ "$VERBOSE" == "true" ]]; then
            docker compose -f docker-compose.yml up -d
        else
            docker compose -f docker-compose.yml up -d &> /dev/null
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
        docker compose -f docker-compose.yml ps
    fi

    # Verify web app accessibility with enhanced retry logic
    log_verbose "Testing web app accessibility..."

    # Use enhanced wait_for_service if available, otherwise fallback
    if command -v wait_for_service &> /dev/null; then
        if ! wait_for_service "https://app.cloudtolocalllm.online" 120 10; then
            log_error "Web app failed to become accessible"
            log_error "Check logs with: docker compose -f docker-compose.yml logs"
            exit 4
        fi
    else
        # Fallback implementation
        local max_attempts=12
        local attempt=1

        while [[ $attempt -le $max_attempts ]]; do
            if curl -f -s --connect-timeout 10 https://app.cloudtolocalllm.online &> /dev/null; then
                log_success "Web app is accessible at https://app.cloudtolocalllm.online"
                return 0
            fi

            log_verbose "Attempt $attempt/$max_attempts failed, retrying in 10 seconds..."
            sleep 10
            ((attempt++))
        done

        log_error "Web app accessibility check failed after $max_attempts attempts"
        log_error "Check logs with: docker compose -f docker-compose.yml logs"
        exit 4
    fi

    log_success "Web app is accessible at https://app.cloudtolocalllm.online"
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

    # Non-interactive execution - no prompts allowed
    # Use --force flag to bypass safety checks in automated environments
    if [[ "$FORCE" != "true" && "$DRY_RUN" != "true" ]]; then
        log_warning "Production VPS deployment starting without --force flag"
        log_warning "Use --force flag for automated/CI environments"
        log "Proceeding with deployment in 3 seconds..."
        sleep 3
    fi

    # Execute deployment phases
    create_backup
    pull_latest_changes
    build_flutter_web
    update_static_distribution
    manage_containers
    perform_health_checks
    display_summary
}

# Error handling
trap 'log_error "Deployment failed at line $LINENO. Check logs above for details."' ERR

# Execute main function
main "$@"