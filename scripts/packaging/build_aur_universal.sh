#!/bin/bash

# CloudToLocalLLM Universal AUR Builder
# Automatically detects platform and uses appropriate build method
# Version: 1.0.0

set -euo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Flags
VERBOSE=false
DRY_RUN=false
FORCE_DOCKER=false

# Logging functions
log() {
    echo -e "${BLUE}[$(date '+%H:%M:%S')] [AUR-UNIVERSAL]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[$(date '+%H:%M:%S')] [AUR-UNIVERSAL] ✅${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[$(date '+%H:%M:%S')] [AUR-UNIVERSAL] ⚠️${NC} $1"
}

log_error() {
    echo -e "${RED}[$(date '+%H:%M:%S')] [AUR-UNIVERSAL] ❌${NC} $1"
}

log_verbose() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "${BLUE}[$(date '+%H:%M:%S')] [AUR-UNIVERSAL] [VERBOSE]${NC} $1"
    fi
}

# Usage information
show_usage() {
    cat << EOF
CloudToLocalLLM Universal AUR Builder

Automatically detects the platform and uses the appropriate build method:
- Arch Linux: Uses native build_aur.sh script
- Ubuntu/Other: Uses Docker-based build with Arch Linux container

USAGE:
    $0 [OPTIONS]

OPTIONS:
    --force-docker      Force use of Docker even on Arch Linux
    --verbose           Enable detailed logging
    --dry-run           Simulate operations without actual execution
    --help              Show this help message

EXAMPLES:
    $0                  # Auto-detect platform and build
    $0 --force-docker   # Force Docker build
    $0 --verbose        # Detailed logging

EXIT CODES:
    0 - Success
    1 - General error
    2 - Platform detection error
    3 - Build failure

PLATFORM DETECTION:
    - Checks for /etc/arch-release (Arch Linux)
    - Checks for Docker availability (Ubuntu/Other)
    - Falls back to Docker if native build not available
EOF
}

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --force-docker)
                FORCE_DOCKER=true
                shift
                ;;
            --verbose)
                VERBOSE=true
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

# Detect platform and build method
detect_platform() {
    log "Detecting platform and build method..."

    if [[ "$DRY_RUN" == "true" ]]; then
        log "DRY RUN: Would detect platform"
        echo "docker"  # Default for dry run
        return 0
    fi

    # Force Docker if requested
    if [[ "$FORCE_DOCKER" == "true" ]]; then
        log "Force Docker flag set - using Docker build"
        echo "docker"
        return 0
    fi

    # Check for Arch Linux
    if [[ -f "/etc/arch-release" ]]; then
        log_verbose "Arch Linux detected"

        # Check if native build script exists
        if [[ -f "$SCRIPT_DIR/build_aur.sh" ]]; then
            log_verbose "Native AUR build script available"
            echo "native"
            return 0
        else
            log_warning "Native AUR build script not found - falling back to Docker"
        fi
    else
        log_verbose "Non-Arch Linux system detected"
    fi

    # Check for Docker availability
    if command -v docker &> /dev/null && docker info &> /dev/null; then
        log_verbose "Docker available - using Docker build"
        echo "docker"
        return 0
    else
        log_error "Neither Arch Linux nor Docker available"
        log_error "Please install Docker or run on Arch Linux"
        return 2
    fi
}

# Execute native build
execute_native_build() {
    log "Executing native AUR build..."

    if [[ "$DRY_RUN" == "true" ]]; then
        log "DRY RUN: Would execute native build"
        return 0
    fi

    local build_script="$SCRIPT_DIR/build_aur.sh"

    if [[ ! -f "$build_script" ]]; then
        log_error "Native build script not found: $build_script"
        return 3
    fi

    # Prepare arguments
    local args=()
    if [[ "$VERBOSE" == "true" ]]; then
        args+=("--verbose")
    fi

    # Execute native build
    log_verbose "Executing: $build_script ${args[*]}"

    if ! "$build_script" "${args[@]}"; then
        log_error "Native AUR build failed"
        return 3
    fi

    log_success "Native AUR build completed successfully"
    return 0
}

# Execute Docker build
execute_docker_build() {
    log "Executing Docker-based AUR build..."

    if [[ "$DRY_RUN" == "true" ]]; then
        log "DRY RUN: Would execute Docker build"
        return 0
    fi

    local docker_script="$PROJECT_ROOT/scripts/docker/build-aur-docker.sh"

    if [[ ! -f "$docker_script" ]]; then
        log_error "Docker build script not found: $docker_script"
        return 3
    fi

    # Prepare arguments
    local args=("build")
    if [[ "$VERBOSE" == "true" ]]; then
        args+=("--verbose")
    fi

    # Execute Docker build
    log_verbose "Executing: $docker_script ${args[*]}"

    if ! "$docker_script" "${args[@]}"; then
        log_error "Docker AUR build failed"
        return 3
    fi

    log_success "Docker AUR build completed successfully"
    return 0
}

# Main execution function
main() {
    # Parse command line arguments
    parse_arguments "$@"

    log "CloudToLocalLLM Universal AUR Builder"
    log "====================================="

    # Detect platform and build method
    local build_method
    if ! build_method=$(detect_platform); then
        exit 2
    fi

    log "Build method: $build_method"

    # Execute appropriate build method
    case "$build_method" in
        native)
            execute_native_build
            exit $?
            ;;
        docker)
            execute_docker_build
            exit $?
            ;;
        *)
            log_error "Unknown build method: $build_method"
            exit 1
            ;;
    esac
}

# Execute main function
main "$@"