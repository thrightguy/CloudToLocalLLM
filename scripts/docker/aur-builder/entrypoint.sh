#!/bin/bash

# CloudToLocalLLM AUR Builder Container Entrypoint
# Handles container initialization and command execution
# Version: 1.0.0

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log() {
    echo -e "${BLUE}[$(date '+%H:%M:%S')] [ENTRYPOINT]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[$(date '+%H:%M:%S')] [ENTRYPOINT] ✅${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[$(date '+%H:%M:%S')] [ENTRYPOINT] ⚠️${NC} $1"
}

log_error() {
    echo -e "${RED}[$(date '+%H:%M:%S')] [ENTRYPOINT] ❌${NC} $1"
}

# Show help information
show_help() {
    cat << EOF
CloudToLocalLLM AUR Builder Container

This container provides an Arch Linux environment for building AUR packages
on Ubuntu systems. It includes Flutter SDK and all necessary build tools.

USAGE:
    docker run [OPTIONS] cloudtolocalllm-aur-builder [COMMAND]

COMMANDS:
    bash                    Interactive bash shell (default)
    build-aur              Build AUR package
    test-aur               Test AUR package
    submit-aur             Submit AUR package
    flutter-doctor         Check Flutter installation
    --help                 Show this help

EXAMPLES:
    # Interactive shell
    docker run -it cloudtolocalllm-aur-builder

    # Build AUR package
    docker run -v /path/to/project:/home/builder/workspace cloudtolocalllm-aur-builder build-aur

    # Check Flutter
    docker run cloudtolocalllm-aur-builder flutter-doctor

ENVIRONMENT:
    - Flutter SDK installed at /opt/flutter
    - Non-root user 'builder' for package building
    - Working directory: /home/builder/workspace
    - Project should be mounted to /home/builder/workspace

NOTES:
    - makepkg requires non-root user (builder user is used)
    - Mount your project directory to /home/builder/workspace
    - Use appropriate user ID mapping for file permissions
EOF
}

# Initialize container environment
initialize_environment() {
    log "Initializing container environment..."

    # Ensure workspace directory exists
    if [[ ! -d "/home/builder/workspace" ]]; then
        mkdir -p /home/builder/workspace
        log_warning "Workspace directory created - mount your project here"
    fi

    # Check if project is mounted
    if [[ ! -f "/home/builder/workspace/pubspec.yaml" ]]; then
        log_warning "CloudToLocalLLM project not detected in workspace"
        log_warning "Please mount your project directory to /home/builder/workspace"
    else
        log_success "CloudToLocalLLM project detected"
    fi

    # Set up git configuration if not present
    if ! git config user.name &> /dev/null; then
        git config --global user.name "AUR Builder"
        git config --global user.email "builder@cloudtolocalllm.local"
        log "Default git configuration set"
    fi

    log_success "Container environment initialized"
}

# Execute build command
execute_build() {
    log "Executing AUR package build..."

    if [[ ! -f "/home/builder/workspace/scripts/packaging/build_aur.sh" ]]; then
        log_error "AUR build script not found"
        log_error "Please ensure CloudToLocalLLM project is mounted to /home/builder/workspace"
        exit 1
    fi

    cd /home/builder/workspace
    exec ./scripts/packaging/build_aur.sh "$@"
}

# Execute test command
execute_test() {
    log "Executing AUR package test..."

    if [[ ! -f "/home/builder/workspace/scripts/deploy/test_aur_package.sh" ]]; then
        log_error "AUR test script not found"
        log_error "Please ensure CloudToLocalLLM project is mounted to /home/builder/workspace"
        exit 1
    fi

    cd /home/builder/workspace
    exec ./scripts/deploy/test_aur_package.sh "$@"
}

# Execute submit command
execute_submit() {
    log "Executing AUR package submission..."

    if [[ ! -f "/home/builder/workspace/scripts/deploy/submit_aur_package.sh" ]]; then
        log_error "AUR submit script not found"
        log_error "Please ensure CloudToLocalLLM project is mounted to /home/builder/workspace"
        exit 1
    fi

    cd /home/builder/workspace
    exec ./scripts/deploy/submit_aur_package.sh "$@"
}

# Execute Flutter doctor
execute_flutter_doctor() {
    log "Running Flutter doctor..."
    exec flutter doctor -v
}

# Main entrypoint logic
main() {
    # Initialize environment
    initialize_environment

    # Handle commands
    case "${1:-bash}" in
        --help|-h|help)
            show_help
            exit 0
            ;;
        build-aur)
            shift
            execute_build "$@"
            ;;
        test-aur)
            shift
            execute_test "$@"
            ;;
        submit-aur)
            shift
            execute_submit "$@"
            ;;
        flutter-doctor)
            execute_flutter_doctor
            ;;
        bash|shell)
            log "Starting interactive bash shell..."
            cd /home/builder/workspace
            exec /bin/bash
            ;;
        *)
            # Execute any other command directly
            exec "$@"
            ;;
    esac
}

# Execute main function
main "$@"