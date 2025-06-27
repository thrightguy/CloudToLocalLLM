#!/bin/bash

# CloudToLocalLLM Docker-based AUR Builder
# Builds AUR packages using Docker container on Ubuntu systems
# Version: 1.0.0

set -euo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Docker configuration
DOCKER_IMAGE_NAME="cloudtolocalllm-aur-builder"
DOCKER_CONTAINER_NAME="cloudtolocalllm-aur-build-$$"
DOCKERFILE_PATH="$SCRIPT_DIR/aur-builder/Dockerfile"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Flags
VERBOSE=false
DRY_RUN=false
FORCE_REBUILD=false
CLEANUP=true

# Logging functions
log() {
    echo -e "${BLUE}[$(date '+%H:%M:%S')] [AUR-DOCKER]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[$(date '+%H:%M:%S')] [AUR-DOCKER] ✅${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[$(date '+%H:%M:%S')] [AUR-DOCKER] ⚠️${NC} $1"
}

log_error() {
    echo -e "${RED}[$(date '+%H:%M:%S')] [AUR-DOCKER] ❌${NC} $1"
}

log_verbose() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "${BLUE}[$(date '+%H:%M:%S')] [AUR-DOCKER] [VERBOSE]${NC} $1"
    fi
}

# Usage information
show_usage() {
    cat << EOF
CloudToLocalLLM Docker-based AUR Builder

USAGE:
    $0 [OPTIONS] [COMMAND]

COMMANDS:
    build               Build AUR package using Docker (default)
    test                Test AUR package using Docker
    submit              Submit AUR package using Docker
    shell               Open interactive shell in Docker container
    clean               Clean up Docker images and containers

OPTIONS:
    --force-rebuild     Force rebuild of Docker image
    --no-cleanup        Don't cleanup container after build
    --verbose           Enable detailed logging
    --dry-run           Simulate operations without actual execution
    --help              Show this help message

EXAMPLES:
    $0                  # Build AUR package using Docker
    $0 build            # Same as above
    $0 test             # Test AUR package
    $0 submit           # Submit AUR package
    $0 shell            # Interactive shell for debugging
    $0 clean            # Clean up Docker resources

EXIT CODES:
    0 - Success
    1 - General error
    2 - Docker not available
    3 - Build failure
    4 - Container execution failure

PREREQUISITES:
    - Docker installed and running
    - User has permission to run Docker commands
    - Project directory accessible
EOF
}

# Parse command line arguments
parse_arguments() {
    local command=""

    while [[ $# -gt 0 ]]; do
        case $1 in
            build|test|submit|shell|clean)
                command="$1"
                shift
                ;;
            --force-rebuild)
                FORCE_REBUILD=true
                shift
                ;;
            --no-cleanup)
                CLEANUP=false
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

    # Default command is build
    if [[ -z "$command" ]]; then
        command="build"
    fi

    echo "$command"
}

# Check Docker availability
check_docker() {
    log "Checking Docker availability..."

    if [[ "$DRY_RUN" == "true" ]]; then
        log "DRY RUN: Would check Docker availability"
        return 0
    fi

    # Check if Docker is installed
    if ! command -v docker &> /dev/null; then
        log_error "Docker not found - please install Docker"
        log_error "Ubuntu: sudo apt update && sudo apt install docker.io"
        log_error "Or follow: https://docs.docker.com/engine/install/ubuntu/"
        return 2
    fi

    # Check if Docker daemon is running
    if ! docker info &> /dev/null; then
        log_error "Docker daemon not running - please start Docker"
        log_error "sudo systemctl start docker"
        return 2
    fi

    # Check if user can run Docker commands
    if ! docker ps &> /dev/null; then
        log_error "Permission denied - user cannot run Docker commands"
        log_error "Add user to docker group: sudo usermod -aG docker $USER"
        log_error "Then logout and login again"
        return 2
    fi

    log_verbose "✓ Docker is available and accessible"
    log_success "Docker availability check completed"
    return 0
}

# Build Docker image
build_docker_image() {
    log "Building Docker image for AUR builder..."

    if [[ "$DRY_RUN" == "true" ]]; then
        log "DRY RUN: Would build Docker image"
        return 0
    fi

    # Check if image exists and force rebuild is not set
    if [[ "$FORCE_REBUILD" != "true" ]] && docker image inspect "$DOCKER_IMAGE_NAME" &> /dev/null; then
        log_verbose "Docker image $DOCKER_IMAGE_NAME already exists"
        log "Using existing Docker image (use --force-rebuild to rebuild)"
        return 0
    fi

    # Build Docker image
    log_verbose "Building Docker image from $DOCKERFILE_PATH"

    local build_args=""
    if [[ "$VERBOSE" == "true" ]]; then
        build_args="--progress=plain"
    else
        build_args="--quiet"
    fi

    if ! docker build $build_args -t "$DOCKER_IMAGE_NAME" -f "$DOCKERFILE_PATH" "$SCRIPT_DIR/aur-builder"; then
        log_error "Failed to build Docker image"
        return 3
    fi

    log_success "Docker image built successfully"
    return 0
}

# Get current user ID and group ID for file permissions
get_user_ids() {
    if command -v id &> /dev/null; then
        echo "$(id -u):$(id -g)"
    else
        echo "1000:1000"  # Default fallback
    fi
}

# Run command in Docker container
run_in_container() {
    local command="$1"
    local interactive="${2:-false}"

    log "Running command in Docker container: $command"

    if [[ "$DRY_RUN" == "true" ]]; then
        log "DRY RUN: Would run command in container"
        return 0
    fi

    # Get user IDs for proper file permissions
    local user_ids=$(get_user_ids)

    # Prepare Docker run arguments
    local docker_args=(
        "--rm"
        "--name" "$DOCKER_CONTAINER_NAME"
        "--user" "$user_ids"
        "--volume" "$PROJECT_ROOT:/home/builder/workspace"
        "--workdir" "/home/builder/workspace"
        "--env" "HOME=/home/builder"
    )

    # Add interactive flags if needed
    if [[ "$interactive" == "true" ]]; then
        docker_args+=("-it")
    fi

    # Add cleanup flag
    if [[ "$CLEANUP" != "true" ]]; then
        docker_args=("${docker_args[@]/--rm}")
    fi

    # Run container
    log_verbose "Docker run arguments: ${docker_args[*]}"

    if [[ "$VERBOSE" == "true" ]]; then
        docker run "${docker_args[@]}" "$DOCKER_IMAGE_NAME" bash -c "$command"
    else
        docker run "${docker_args[@]}" "$DOCKER_IMAGE_NAME" bash -c "$command" 2>/dev/null
    fi

    local exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        log_success "Container command completed successfully"
    else
        log_error "Container command failed with exit code $exit_code"
        return 4
    fi

    return $exit_code
}

# Build AUR package
build_aur_package() {
    log "Building AUR package using Docker..."

    local build_command="cd /home/builder/workspace && ./scripts/packaging/build_aur.sh"

    if [[ "$VERBOSE" == "true" ]]; then
        build_command="$build_command --verbose"
    fi

    run_in_container "$build_command" false
    return $?
}

# Test AUR package
test_aur_package() {
    log "Testing AUR package using Docker..."

    local test_command="cd /home/builder/workspace && ./scripts/deploy/test_aur_package.sh"

    if [[ "$VERBOSE" == "true" ]]; then
        test_command="$test_command --verbose"
    fi

    run_in_container "$test_command" false
    return $?
}

# Submit AUR package
submit_aur_package() {
    log "Submitting AUR package using Docker..."

    local submit_command="cd /home/builder/workspace && ./scripts/deploy/submit_aur_package.sh"

    if [[ "$VERBOSE" == "true" ]]; then
        submit_command="$submit_command --verbose"
    fi

    run_in_container "$submit_command" false
    return $?
}

# Open interactive shell
open_shell() {
    log "Opening interactive shell in Docker container..."

    local shell_command="cd /home/builder/workspace && /bin/bash"

    run_in_container "$shell_command" true
    return $?
}

# Clean up Docker resources
clean_docker() {
    log "Cleaning up Docker resources..."

    if [[ "$DRY_RUN" == "true" ]]; then
        log "DRY RUN: Would clean up Docker resources"
        return 0
    fi

    # Remove containers
    local containers=$(docker ps -a --filter "name=$DOCKER_CONTAINER_NAME" --format "{{.ID}}" 2>/dev/null || true)
    if [[ -n "$containers" ]]; then
        log_verbose "Removing containers: $containers"
        docker rm -f $containers &> /dev/null || true
    fi

    # Remove image
    if docker image inspect "$DOCKER_IMAGE_NAME" &> /dev/null; then
        log_verbose "Removing Docker image: $DOCKER_IMAGE_NAME"
        docker rmi "$DOCKER_IMAGE_NAME" &> /dev/null || true
    fi

    # Clean up dangling images
    local dangling=$(docker images -f "dangling=true" -q 2>/dev/null || true)
    if [[ -n "$dangling" ]]; then
        log_verbose "Removing dangling images"
        docker rmi $dangling &> /dev/null || true
    fi

    log_success "Docker cleanup completed"
    return 0
}

# Main execution function
main() {
    # Parse command line arguments
    local command=$(parse_arguments "$@")

    log "CloudToLocalLLM Docker-based AUR Builder"
    log "========================================"
    log "Command: $command"

    # Check Docker availability
    if ! check_docker; then
        exit 2
    fi

    # Handle clean command separately
    if [[ "$command" == "clean" ]]; then
        clean_docker
        exit $?
    fi

    # Build Docker image
    if ! build_docker_image; then
        exit 3
    fi

    # Execute command
    case "$command" in
        build)
            build_aur_package
            exit $?
            ;;
        test)
            test_aur_package
            exit $?
            ;;
        submit)
            submit_aur_package
            exit $?
            ;;
        shell)
            open_shell
            exit $?
            ;;
        *)
            log_error "Unknown command: $command"
            show_usage
            exit 1
            ;;
    esac
}

# Execute main function
main "$@"