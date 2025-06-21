#!/bin/bash
# CloudToLocalLLM Deployment Pipeline Test Script
# Tests the updated deployment pipeline with Flutter SDK and package updates

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TEST_MODE="local"  # local, docker, or vps
VERBOSE=false
DRY_RUN=false

# Logging functions
log() {
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

log_verbose() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "${BLUE}[VERBOSE]${NC} $1"
    fi
}

# Help function
show_help() {
    cat << EOF
CloudToLocalLLM Deployment Pipeline Test Script

Usage: $0 [OPTIONS]

Options:
    -m, --mode MODE         Test mode: local, docker, or vps (default: local)
    -v, --verbose           Enable verbose output
    -d, --dry-run           Perform dry run without making changes
    -h, --help              Show this help message

Test Modes:
    local                   Test Flutter updates and build locally
    docker                  Test using Docker Flutter builder
    vps                     Test VPS deployment pipeline (requires SSH access)

Examples:
    $0 --mode local --verbose
    $0 --mode docker
    $0 --mode vps --dry-run
EOF
}

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -m|--mode)
                TEST_MODE="$2"
                shift 2
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -d|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# Test local Flutter environment
test_local_flutter() {
    log "Testing local Flutter environment..."
    
    cd "$PROJECT_ROOT"
    
    # Check Flutter installation
    if ! command -v flutter &> /dev/null; then
        log_error "Flutter is not installed or not in PATH"
        return 1
    fi
    
    local current_version=$(flutter --version | head -1)
    log_verbose "Current Flutter version: $current_version"
    
    # Test Flutter upgrade (dry run mode)
    if [[ "$DRY_RUN" == "true" ]]; then
        log "DRY RUN: Would execute 'flutter upgrade --force'"
    else
        log "Upgrading Flutter SDK..."
        flutter upgrade --force
    fi
    
    # Test package upgrade
    if [[ "$DRY_RUN" == "true" ]]; then
        log "DRY RUN: Would execute 'flutter pub upgrade'"
    else
        log "Upgrading package dependencies..."
        flutter pub upgrade
    fi
    
    # Test web build
    if [[ "$DRY_RUN" == "true" ]]; then
        log "DRY RUN: Would execute 'flutter build web'"
    else
        log "Testing Flutter web build..."
        flutter clean
        flutter pub get
        flutter build web --release --no-tree-shake-icons --web-renderer html
        
        # Verify build output
        if [[ -f "build/web/index.html" ]]; then
            log_success "Flutter web build completed successfully"
            log_verbose "Build output size: $(du -sh build/web | cut -f1)"
        else
            log_error "Flutter web build failed - index.html not found"
            return 1
        fi
    fi
    
    log_success "Local Flutter environment test completed"
}

# Test Docker Flutter builder
test_docker_flutter() {
    log "Testing Docker Flutter builder..."
    
    cd "$PROJECT_ROOT"
    
    # Check if Docker is available
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed or not in PATH"
        return 1
    fi
    
    # Build Flutter builder image
    if [[ "$DRY_RUN" == "true" ]]; then
        log "DRY RUN: Would build Docker Flutter builder image"
    else
        log "Building Flutter builder Docker image..."
        docker-compose -f docker-compose.flutter-builder.yml build flutter-builder
    fi
    
    # Test Flutter SDK update in container
    if [[ "$DRY_RUN" == "true" ]]; then
        log "DRY RUN: Would test Flutter SDK update in container"
    else
        log "Testing Flutter SDK update in container..."
        docker-compose -f docker-compose.flutter-builder.yml run --rm flutter-builder /home/flutter/update-flutter.sh
    fi
    
    # Test web build in container
    if [[ "$DRY_RUN" == "true" ]]; then
        log "DRY RUN: Would test Flutter web build in container"
    else
        log "Testing Flutter web build in container..."
        docker-compose -f docker-compose.flutter-builder.yml run --rm flutter-builder /home/flutter/build-web.sh
        
        # Verify build output
        if [[ -f "build/web/index.html" ]]; then
            log_success "Docker Flutter web build completed successfully"
        else
            log_error "Docker Flutter web build failed - index.html not found"
            return 1
        fi
    fi
    
    log_success "Docker Flutter builder test completed"
}

# Test VPS deployment pipeline
test_vps_deployment() {
    log "Testing VPS deployment pipeline..."
    
    cd "$PROJECT_ROOT"
    
    # Check if deployment script exists
    local deploy_script="scripts/deploy/update_and_deploy.sh"
    if [[ ! -f "$deploy_script" ]]; then
        log_error "VPS deployment script not found: $deploy_script"
        return 1
    fi
    
    # Test deployment script with dry run
    if [[ "$DRY_RUN" == "true" ]]; then
        log "Testing VPS deployment script in dry-run mode..."
        bash "$deploy_script" --dry-run --verbose
    else
        log_warning "VPS deployment test requires actual VPS access"
        log "To test VPS deployment, run: bash $deploy_script --dry-run --verbose"
    fi
    
    log_success "VPS deployment pipeline test completed"
}

# Main test function
main() {
    log "CloudToLocalLLM Deployment Pipeline Test"
    log "========================================"
    log "Test Mode: $TEST_MODE"
    log "Verbose: $VERBOSE"
    log "Dry Run: $DRY_RUN"
    log ""
    
    case "$TEST_MODE" in
        local)
            test_local_flutter
            ;;
        docker)
            test_docker_flutter
            ;;
        vps)
            test_vps_deployment
            ;;
        *)
            log_error "Invalid test mode: $TEST_MODE"
            log_error "Valid modes: local, docker, vps"
            exit 1
            ;;
    esac
    
    log_success "All tests completed successfully!"
}

# Parse arguments and run main function
parse_arguments "$@"
main
