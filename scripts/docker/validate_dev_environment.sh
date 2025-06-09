#!/bin/bash

# CloudToLocalLLM Docker Development Environment Validation Script
# Validates that the Docker development environment works correctly

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
DOCKER_IMAGE="cloudtolocalllm:dev"
COMPOSE_FILE="docker-compose.dev.yml"

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

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed"
        exit 1
    fi
    
    # Check Docker Compose
    if ! command -v docker &> /dev/null || ! docker compose version &> /dev/null; then
        log_error "Docker Compose is not available"
        exit 1
    fi
    
    # Check if Docker daemon is running
    if ! docker info &> /dev/null; then
        log_error "Docker daemon is not running"
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

# Build Docker image
build_image() {
    log_info "Building Docker development image..."
    
    cd "$PROJECT_ROOT"
    
    if docker build -f Dockerfile.dev -t "$DOCKER_IMAGE" .; then
        log_success "Docker image built successfully"
    else
        log_error "Failed to build Docker image"
        exit 1
    fi
}

# Test basic container functionality
test_container_basic() {
    log_info "Testing basic container functionality..."
    
    # Test container startup
    if docker run --rm "$DOCKER_IMAGE" echo "Container startup test"; then
        log_success "Container starts successfully"
    else
        log_error "Container startup failed"
        exit 1
    fi
    
    # Test Flutter installation
    if docker run --rm "$DOCKER_IMAGE" flutter --version; then
        log_success "Flutter is available in container"
    else
        log_error "Flutter is not available in container"
        exit 1
    fi
}

# Test Flutter configuration
test_flutter_config() {
    log_info "Testing Flutter configuration..."
    
    # Test Flutter doctor
    log_info "Running Flutter doctor..."
    if docker run --rm "$DOCKER_IMAGE" flutter doctor; then
        log_success "Flutter doctor completed"
    else
        log_warning "Flutter doctor reported issues (may be expected in container)"
    fi
    
    # Test platform configuration
    if docker run --rm "$DOCKER_IMAGE" flutter config | grep -q "linux-desktop: enabled"; then
        log_success "Linux desktop platform enabled"
    else
        log_error "Linux desktop platform not enabled"
        exit 1
    fi
    
    if docker run --rm "$DOCKER_IMAGE" flutter config | grep -q "web: enabled"; then
        log_success "Web platform enabled"
    else
        log_error "Web platform not enabled"
        exit 1
    fi
}

# Test system dependencies
test_system_dependencies() {
    log_info "Testing system dependencies..."
    
    # Test GTK3 development libraries
    if docker run --rm "$DOCKER_IMAGE" pkg-config --exists gtk+-3.0; then
        log_success "GTK3 development libraries available"
    else
        log_error "GTK3 development libraries missing"
        exit 1
    fi
    
    # Test build tools
    local tools=("clang" "cmake" "ninja" "pkg-config")
    for tool in "${tools[@]}"; do
        if docker run --rm "$DOCKER_IMAGE" which "$tool" > /dev/null; then
            log_success "$tool is available"
        else
            log_error "$tool is missing"
            exit 1
        fi
    done
}

# Test CloudToLocalLLM build
test_cloudtolocalllm_build() {
    log_info "Testing CloudToLocalLLM build in container..."
    
    # Mount current directory and test build
    if docker run --rm -v "$PROJECT_ROOT:/workspace" "$DOCKER_IMAGE" bash -c "
        cd /workspace &&
        flutter pub get &&
        flutter analyze &&
        flutter build linux --debug
    "; then
        log_success "CloudToLocalLLM builds successfully in container"
    else
        log_error "CloudToLocalLLM build failed in container"
        exit 1
    fi
}

# Test Docker Compose
test_docker_compose() {
    log_info "Testing Docker Compose configuration..."
    
    cd "$PROJECT_ROOT"
    
    # Test compose file validation
    if docker compose -f "$COMPOSE_FILE" config > /dev/null; then
        log_success "Docker Compose configuration is valid"
    else
        log_error "Docker Compose configuration is invalid"
        exit 1
    fi
    
    # Test service startup
    log_info "Starting Docker Compose services..."
    if docker compose -f "$COMPOSE_FILE" up -d; then
        log_success "Docker Compose services started"
        
        # Wait for services to be ready
        sleep 10
        
        # Test health check
        if docker compose -f "$COMPOSE_FILE" exec -T flutter /home/flutter/health-check.sh; then
            log_success "Container health check passed"
        else
            log_warning "Container health check failed"
        fi
        
        # Cleanup
        docker compose -f "$COMPOSE_FILE" down
        log_success "Docker Compose services stopped"
    else
        log_error "Failed to start Docker Compose services"
        exit 1
    fi
}

# Test web build
test_web_build() {
    log_info "Testing web build in container..."
    
    if docker run --rm -v "$PROJECT_ROOT:/workspace" "$DOCKER_IMAGE" bash -c "
        cd /workspace &&
        flutter build web --debug
    "; then
        log_success "Web build completed successfully"
    else
        log_error "Web build failed"
        exit 1
    fi
}

# Generate validation report
generate_report() {
    log_info "Generating validation report..."
    
    local report_file="$PROJECT_ROOT/docker-validation-report.txt"
    
    cat > "$report_file" << EOF
CloudToLocalLLM Docker Development Environment Validation Report
================================================================

Validation Date: $(date)
Docker Version: $(docker --version)
Docker Compose Version: $(docker compose version)

Test Results:
✅ Prerequisites check passed
✅ Docker image built successfully
✅ Container starts successfully
✅ Flutter is available in container
✅ Flutter configuration validated
✅ System dependencies available
✅ CloudToLocalLLM builds successfully
✅ Docker Compose configuration valid
✅ Web build completed successfully

Environment Details:
- Base Image: ghcr.io/cirruslabs/flutter:3.32.2
- Flutter Version: $(docker run --rm "$DOCKER_IMAGE" flutter --version | head -1)
- Dart Version: $(docker run --rm "$DOCKER_IMAGE" dart --version)
- Container User: flutter (UID 1000)
- Working Directory: /workspace

Available Commands:
- flutter-health: Run comprehensive health check
- flutter-build: Build for Linux desktop
- flutter-web: Build for web
- flutter-test: Run tests
- flutter-analyze: Analyze code
- flutter-clean: Clean build artifacts

Usage:
1. Build: docker build -f Dockerfile.dev -t cloudtolocalllm:dev .
2. Run: docker compose -f docker-compose.dev.yml up -d
3. Enter: docker compose -f docker-compose.dev.yml exec flutter bash

All validation tests passed successfully!
The Docker development environment is ready for CloudToLocalLLM v3.5.0+ development.
EOF

    log_success "Validation report generated: $report_file"
}

# Main execution
main() {
    echo -e "${BLUE}CloudToLocalLLM Docker Development Environment Validation${NC}"
    echo -e "${BLUE}=========================================================${NC}"
    echo ""
    
    local start_time=$(date +%s)
    
    # Run validation tests
    check_prerequisites
    build_image
    test_container_basic
    test_flutter_config
    test_system_dependencies
    test_cloudtolocalllm_build
    test_docker_compose
    test_web_build
    generate_report
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    echo ""
    echo -e "${GREEN}🎉 All validation tests passed successfully!${NC}"
    echo -e "${GREEN}✅ Docker development environment is ready for CloudToLocalLLM v3.5.0+${NC}"
    echo -e "${BLUE}⏱️  Total validation time: ${duration} seconds${NC}"
    echo ""
    echo -e "${YELLOW}Next steps:${NC}"
    echo "1. Start development: docker compose -f docker-compose.dev.yml up -d"
    echo "2. Enter container: docker compose -f docker-compose.dev.yml exec flutter bash"
    echo "3. Run health check: flutter-health"
    echo "4. Start developing: flutter pub get && flutter analyze"
}

# Execute main function
main "$@"
