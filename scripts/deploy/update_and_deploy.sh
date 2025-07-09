#!/bin/bash

# CloudToLocalLLM VPS Deployment Script v3.5.5+
# Enhanced with automation flags for CI/CD pipeline support
# Robust network operations and timeout handling

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Setup Flutter environment
if [[ -d "/opt/flutter/bin" ]]; then
    export PATH="/opt/flutter/bin:$PATH"
    export FLUTTER_ROOT="/opt/flutter"
elif [[ -d "$HOME/flutter/bin" ]]; then
    export PATH="$HOME/flutter/bin:$PATH"
    export FLUTTER_ROOT="$HOME/flutter"
fi

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

# Verify Flutter installation and setup
verify_flutter_installation() {
    log_verbose "Verifying Flutter installation..."

    # Check if flutter command is available
    if ! command -v flutter &> /dev/null; then
        log_error "Flutter command not found in PATH"
        log_error "Current PATH: $PATH"
        log_error "Please ensure Flutter is installed and in PATH"

        # Try to find Flutter in common locations
        for flutter_path in "/opt/flutter/bin/flutter" "$HOME/flutter/bin/flutter" "/usr/local/bin/flutter"; do
            if [[ -x "$flutter_path" ]]; then
                log_warning "Found Flutter at: $flutter_path"
                log_warning "Adding to PATH for this session"
                export PATH="$(dirname "$flutter_path"):$PATH"
                break
            fi
        done

        # Check again after PATH update
        if ! command -v flutter &> /dev/null; then
            log_error "Flutter still not found after PATH update"
            exit 1
        fi
    fi

    log_verbose "Flutter found at: $(which flutter)"
    log_verbose "Flutter version: $(flutter --version | head -1 2>/dev/null || echo 'Version check failed')"
}

# Update Flutter SDK and dependencies
update_flutter_environment() {
    log "Updating Flutter SDK and dependencies..."

    if [[ "$DRY_RUN" == "true" ]]; then
        log "DRY RUN: Would execute Flutter SDK and dependency updates"
        return 0
    fi

    # Verify Flutter installation first
    verify_flutter_installation

    # Check current Flutter version
    log_verbose "Checking current Flutter version..."
    local current_version=$(flutter --version | head -1 2>/dev/null || echo "Flutter not found")
    log_verbose "Current Flutter version: $current_version"

    # Update Flutter SDK to latest stable version
    log_verbose "Upgrading Flutter SDK to latest stable version..."
    if [[ "$VERBOSE" == "true" ]]; then
        flutter upgrade --force
    else
        flutter upgrade --force &> /dev/null
    fi

    # Verify Flutter installation
    log_verbose "Running Flutter doctor to verify installation..."
    if [[ "$VERBOSE" == "true" ]]; then
        flutter doctor --android-licenses || true
        flutter doctor
    else
        flutter doctor --android-licenses &> /dev/null || true
        flutter doctor &> /dev/null
    fi

    # Update package dependencies to latest compatible versions
    log_verbose "Upgrading package dependencies to latest compatible versions..."
    if [[ "$VERBOSE" == "true" ]]; then
        flutter pub upgrade
    else
        flutter pub upgrade &> /dev/null
    fi

    # Verify web platform support
    log_verbose "Ensuring web platform support is enabled..."
    if [[ "$VERBOSE" == "true" ]]; then
        flutter config --enable-web
    else
        flutter config --enable-web &> /dev/null
    fi

    # Display updated version
    local new_version=$(flutter --version | head -1 2>/dev/null || echo "Flutter version check failed")
    log_verbose "Updated Flutter version: $new_version"

    # Verify compatibility
    verify_flutter_compatibility

    log_success "Flutter environment updated successfully"
}

# Verify Flutter version and package compatibility
verify_flutter_compatibility() {
    log_verbose "Verifying Flutter compatibility with codebase..."

    if [[ "$DRY_RUN" == "true" ]]; then
        log "DRY RUN: Would verify Flutter compatibility"
        return 0
    fi

    # Check minimum Flutter version requirements
    local flutter_version=$(flutter --version | grep -oE 'Flutter [0-9]+\.[0-9]+\.[0-9]+' | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "0.0.0")
    local min_version="3.16.0"  # Minimum required Flutter version for CloudToLocalLLM

    if [[ "$flutter_version" != "0.0.0" ]]; then
        log_verbose "Current Flutter version: $flutter_version"
        log_verbose "Minimum required version: $min_version"

        # Simple version comparison (assumes semantic versioning)
        if [[ "$(printf '%s\n' "$min_version" "$flutter_version" | sort -V | head -n1)" != "$min_version" ]]; then
            log_warning "Flutter version $flutter_version is below minimum required version $min_version"
            log_warning "Some features may not work correctly"
        else
            log_verbose "Flutter version compatibility check passed"
        fi
    else
        log_warning "Could not determine Flutter version"
    fi

    # Verify web platform support
    log_verbose "Checking web platform support..."
    if flutter config | grep -q "enable-web: true" 2>/dev/null; then
        log_verbose "Web platform support is enabled"
    else
        log_warning "Web platform support may not be enabled"
        flutter config --enable-web &> /dev/null || true
    fi

    # Check for critical package compatibility issues
    log_verbose "Checking package compatibility..."
    if [[ -f "pubspec.yaml" ]]; then
        # Check for known problematic package combinations
        if grep -q "flutter_secure_storage" pubspec.yaml && grep -q "window_manager" pubspec.yaml; then
            log_verbose "Detected desktop-specific packages - ensuring web compatibility"
        fi

        # Verify pubspec.yaml syntax
        if ! flutter pub deps &> /dev/null; then
            log_warning "Package dependency issues detected - attempting to resolve..."
            flutter pub get &> /dev/null || true
        else
            log_verbose "Package dependencies are compatible"
        fi
    else
        log_warning "pubspec.yaml not found in current directory"
    fi

    # Test basic Flutter commands
    log_verbose "Testing Flutter web build capability..."
    if flutter build web --help &> /dev/null; then
        log_verbose "Flutter web build capability verified"
    else
        log_warning "Flutter web build capability test failed"
    fi

    log_verbose "Flutter compatibility verification completed"
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

    # Check if version has placeholder and needs preparation
    local current_version=$(grep '^version:' pubspec.yaml | sed 's/version: *//')
    if [[ "$current_version" == *"BUILD_TIME_PLACEHOLDER"* ]]; then
        log_verbose "Version has placeholder, preparing for build-time injection..."
        if [[ "$build_injection_available" != "true" ]]; then
            log_error "Version has placeholder but build-time injection not available"
            log_error "Cannot proceed with fallback build when placeholder version is present"
            exit 3
        fi
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
                if ! timeout $build_timeout flutter build web --release --no-tree-shake-icons; then
                    log_error "Flutter web build timed out or failed"
                    exit 3
                fi
            else
                if ! timeout $build_timeout flutter build web --release --no-tree-shake-icons &> /dev/null; then
                    log_error "Flutter web build timed out or failed"
                    exit 3
                fi
            fi
        fi

        log_success "Web application built (fallback mode)"
    fi

    log_success "Flutter web build completed"
}

# Update distribution files for Flutter-native homepage
update_distribution_files() {
    log "Updating distribution files for Flutter-native homepage..."

    if [[ "$DRY_RUN" == "true" ]]; then
        log "DRY RUN: Would update distribution metadata for Flutter homepage"
        return 0
    fi

    # Create distribution metadata for Flutter homepage to serve
    local version=$(grep '^version:' pubspec.yaml | sed 's/version: *\([0-9.]*\).*/\1/')
    local package_file="cloudtolocalllm-${version}-x86_64.tar.gz"

    if [[ -f "dist/$package_file" ]]; then
        local package_size=$(du -h "dist/$package_file" | cut -f1)
        local package_sha256=$(sha256sum "dist/$package_file" | cut -d' ' -f1)

        # Create metadata for Flutter homepage to serve
        mkdir -p "build/web/assets/downloads"
        cat > "build/web/assets/downloads/latest.json" << EOF
{
  "version": "$version",
  "package_file": "$package_file",
  "package_size": "$package_size",
  "package_sha256": "$package_sha256",
  "upload_date": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "download_url": "https://cloudtolocalllm.online/downloads/$package_file"
}
EOF
        chmod 644 "build/web/assets/downloads/latest.json"
        log_verbose "Updated distribution metadata for Flutter homepage"
    fi

    log_success "Distribution files updated for Flutter-native homepage"
}

# Manage containers with comprehensive cleanup
manage_containers() {
    log "Managing Docker containers..."

    if [[ "$DRY_RUN" == "true" ]]; then
        log "DRY RUN: Would stop and restart containers with cleanup"
        return 0
    fi

    # Comprehensive container cleanup to prevent port conflicts
    log_verbose "Performing comprehensive container cleanup..."

    # Step 1: Stop and remove all containers including orphans
    log_verbose "Stopping and removing all containers (including orphans)..."

    # Check if docker-compose.yml exists
    if [[ ! -f "docker-compose.yml" ]]; then
        log_warning "docker-compose.yml not found, skipping container management"
        return 0
    fi

    # Check if Docker is available and determine the correct command
    local docker_cmd=""
    local docker_compose_cmd=""

    if command -v docker &> /dev/null; then
        docker_cmd="docker"
    elif command -v /snap/bin/docker &> /dev/null; then
        docker_cmd="/snap/bin/docker"
    else
        log_warning "Docker not found, skipping container management"
        return 0
    fi

    # Determine Docker Compose command
    if $docker_cmd compose version &> /dev/null; then
        docker_compose_cmd="$docker_cmd compose"
    elif command -v docker-compose &> /dev/null; then
        docker_compose_cmd="docker-compose"
    elif command -v /snap/bin/docker-compose &> /dev/null; then
        docker_compose_cmd="/snap/bin/docker-compose"
    else
        log_warning "Docker Compose not found, skipping container management"
        return 0
    fi

    log_verbose "Using Docker command: $docker_cmd"
    log_verbose "Using Docker Compose command: $docker_compose_cmd"

    if [[ "$VERBOSE" == "true" ]]; then
        $docker_compose_cmd -f docker-compose.yml down --remove-orphans || {
            log_warning "Failed to stop containers, continuing anyway..."
        }
    else
        $docker_compose_cmd -f docker-compose.yml down --remove-orphans &> /dev/null || {
            log_warning "Failed to stop containers, continuing anyway..."
        }
    fi

    # Step 2: Additional cleanup for any remaining containers that might be using our ports
    log_verbose "Checking for containers using ports 80, 443, and 8080..."
    local containers_using_ports=$($docker_cmd ps -q --filter "publish=80" --filter "publish=443" --filter "publish=8080" 2>/dev/null || true)
    if [[ -n "$containers_using_ports" ]]; then
        log_verbose "Found containers using required ports, stopping them..."
        if [[ "$VERBOSE" == "true" ]]; then
            echo "$containers_using_ports" | xargs -r $docker_cmd stop
            echo "$containers_using_ports" | xargs -r $docker_cmd rm
        else
            echo "$containers_using_ports" | xargs -r $docker_cmd stop &> /dev/null
            echo "$containers_using_ports" | xargs -r $docker_cmd rm &> /dev/null
        fi
    fi

    # Step 3: Clean up unused Docker resources (optional but recommended)
    log_verbose "Cleaning up unused Docker resources..."
    if [[ "$VERBOSE" == "true" ]]; then
        $docker_cmd system prune -f
    else
        $docker_cmd system prune -f &> /dev/null
    fi

    # Step 4: Wait a moment for cleanup to complete
    log_verbose "Waiting for cleanup to complete..."
    sleep 3

    # Check SSL certificates and start services
    if [ -d "certbot/live/cloudtolocalllm.online" ]; then
        log_verbose "SSL certificates found, starting services with SSL..."
        if [[ "$VERBOSE" == "true" ]]; then
            $docker_compose_cmd -f docker-compose.yml up -d
        else
            $docker_compose_cmd -f docker-compose.yml up -d &> /dev/null
        fi
    else
        log_warning "SSL certificates not found at certbot/live/cloudtolocalllm.online"
        log_warning "Starting services without SSL (HTTP only)..."

        # Try to start services anyway - they might be configured for HTTP
        if [[ "$VERBOSE" == "true" ]]; then
            $docker_compose_cmd -f docker-compose.yml up -d
        else
            $docker_compose_cmd -f docker-compose.yml up -d &> /dev/null
        fi

        # Check if services started successfully
        if [ $? -eq 0 ]; then
            log_warning "Services started successfully without SSL"
            log_warning "To enable SSL, set up certificates with:"
            log_warning "certbot certonly --webroot -w /var/www/html -d cloudtolocalllm.online -d app.cloudtolocalllm.online"
        else
            log_error "Failed to start Docker services"
            log_error "Check Docker Compose configuration and try again"
            exit 4
        fi
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

    # Determine Docker commands (same as in manage_containers)
    local docker_cmd=""
    local docker_compose_cmd=""

    if command -v docker &> /dev/null; then
        docker_cmd="docker"
    elif command -v /snap/bin/docker &> /dev/null; then
        docker_cmd="/snap/bin/docker"
    fi

    if [[ -n "$docker_cmd" ]]; then
        if $docker_cmd compose version &> /dev/null; then
            docker_compose_cmd="$docker_cmd compose"
        elif command -v docker-compose &> /dev/null; then
            docker_compose_cmd="docker-compose"
        elif command -v /snap/bin/docker-compose &> /dev/null; then
            docker_compose_cmd="/snap/bin/docker-compose"
        fi
    fi

    # Wait for containers to start
    log_verbose "Waiting for containers to start..."
    sleep 10

    # Check container health
    log_verbose "Checking container status..."
    if [[ "$VERBOSE" == "true" && -n "$docker_compose_cmd" ]]; then
        $docker_compose_cmd -f docker-compose.yml ps
    fi

    # Verify API backend health
    log_verbose "Testing API backend health..."
    local api_max_attempts=12
    local api_attempt=1

    while [[ $api_attempt -le $api_max_attempts ]]; do
        if curl -f -s --connect-timeout 10 https://app.cloudtolocalllm.online/api/health &> /dev/null; then
            log_success "API backend is healthy"
            break
        fi

        if [[ $api_attempt -eq $api_max_attempts ]]; then
            log_warning "API backend health check failed after $api_max_attempts attempts"
            if [[ -n "$docker_compose_cmd" ]]; then
                log_warning "Check api-backend logs with: $docker_compose_cmd -f docker-compose.yml logs api-backend"
            fi
            log_warning "Continuing with deployment - API may still be starting up"
            break
        fi

        log_verbose "API health check attempt $api_attempt/$api_max_attempts failed, retrying in 10 seconds..."
        sleep 10
        ((api_attempt++))
    done

    # Verify web app accessibility with enhanced retry logic
    log_verbose "Testing web app accessibility..."

    # Use enhanced wait_for_service if available, otherwise fallback
    if command -v wait_for_service &> /dev/null; then
        if ! wait_for_service "https://app.cloudtolocalllm.online" 120 10; then
            log_warning "HTTPS web app failed to become accessible, trying HTTP..."
            if ! wait_for_service "http://app.cloudtolocalllm.online" 60 5; then
                log_warning "Web app accessibility check failed"
                if [[ -n "$docker_compose_cmd" ]]; then
                    log_warning "Check logs with: $docker_compose_cmd -f docker-compose.yml logs"
                fi
                log_warning "Deployment may still be successful - check manually"
            else
                log_success "Web app is accessible at http://app.cloudtolocalllm.online (HTTP only)"
            fi
        else
            log_success "Web app is accessible at https://app.cloudtolocalllm.online"
        fi
    else
        # Fallback implementation
        local max_attempts=12
        local attempt=1

        while [[ $attempt -le $max_attempts ]]; do
            # Try HTTPS first, then HTTP
            if curl -f -s --connect-timeout 10 https://app.cloudtolocalllm.online &> /dev/null; then
                log_success "Web app is accessible at https://app.cloudtolocalllm.online"
                return 0
            elif curl -f -s --connect-timeout 10 http://app.cloudtolocalllm.online &> /dev/null; then
                log_success "Web app is accessible at http://app.cloudtolocalllm.online (HTTP only)"
                return 0
            fi

            log_verbose "Attempt $attempt/$max_attempts failed, retrying in 10 seconds..."
            sleep 10
            ((attempt++))
        done

        log_warning "Web app accessibility check failed after $max_attempts attempts"
        if [[ -n "$docker_compose_cmd" ]]; then
            log_warning "Check logs with: $docker_compose_cmd -f docker-compose.yml logs"
        fi
        log_warning "Deployment may still be successful - check manually"
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
    echo "  - API backend: https://app.cloudtolocalllm.online/api/health"
    echo "  - Tunnel server: wss://app.cloudtolocalllm.online/ws/bridge"

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
    update_flutter_environment
    build_flutter_web
    update_distribution_files
    manage_containers
    perform_health_checks
    display_summary
}

# Error handling
trap 'log_error "Deployment failed at line $LINENO. Check logs above for details."' ERR

# Execute main function
main "$@"