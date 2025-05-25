#!/bin/bash

# =============================================================================
# CloudToLocalLLM Flutter Base Image Builder
# This script creates a reusable base image with Flutter pre-installed
# =============================================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
FLUTTER_VERSION=${FLUTTER_VERSION:-3.24.5}
BASE_IMAGE_NAME="cloudtolocalllm-flutter-base"
BASE_IMAGE_TAG="${FLUTTER_VERSION}"
REGISTRY=${REGISTRY:-""}

# Function to print colored output
echo_color() {
    echo -e "${1}${2}${NC}"
}

# Function to check if Docker is available
check_docker() {
    if ! command -v docker &> /dev/null; then
        echo_color "$RED" "Docker is not installed or not in PATH"
        exit 1
    fi
}

# Function to build base image
build_base_image() {
    echo_color "$BLUE" "Building Flutter base image..."
    echo_color "$YELLOW" "Flutter Version: $FLUTTER_VERSION"
    echo_color "$YELLOW" "Image Name: $BASE_IMAGE_NAME:$BASE_IMAGE_TAG"
    
    # Build only the flutter-base stage
    docker build \
        --target flutter-base \
        --build-arg FLUTTER_VERSION="$FLUTTER_VERSION" \
        --tag "$BASE_IMAGE_NAME:$BASE_IMAGE_TAG" \
        --tag "$BASE_IMAGE_NAME:latest" \
        -f Dockerfile.web \
        .
    
    if [ $? -eq 0 ]; then
        echo_color "$GREEN" "✓ Base image built successfully!"
        
        # Show image size
        local image_size=$(docker images "$BASE_IMAGE_NAME:$BASE_IMAGE_TAG" --format "table {{.Size}}" | tail -n 1)
        echo_color "$GREEN" "Image size: $image_size"
        
        return 0
    else
        echo_color "$RED" "✗ Failed to build base image"
        return 1
    fi
}

# Function to push to registry
push_to_registry() {
    if [ -n "$REGISTRY" ]; then
        echo_color "$BLUE" "Pushing to registry: $REGISTRY"
        
        # Tag for registry
        docker tag "$BASE_IMAGE_NAME:$BASE_IMAGE_TAG" "$REGISTRY/$BASE_IMAGE_NAME:$BASE_IMAGE_TAG"
        docker tag "$BASE_IMAGE_NAME:latest" "$REGISTRY/$BASE_IMAGE_NAME:latest"
        
        # Push to registry
        docker push "$REGISTRY/$BASE_IMAGE_NAME:$BASE_IMAGE_TAG"
        docker push "$REGISTRY/$BASE_IMAGE_NAME:latest"
        
        echo_color "$GREEN" "✓ Images pushed to registry"
    else
        echo_color "$YELLOW" "No registry specified, skipping push"
    fi
}

# Function to test base image
test_base_image() {
    echo_color "$BLUE" "Testing base image..."
    
    # Test Flutter installation
    docker run --rm "$BASE_IMAGE_NAME:$BASE_IMAGE_TAG" \
        /flutter/bin/flutter --version
    
    if [ $? -eq 0 ]; then
        echo_color "$GREEN" "✓ Base image test passed"
        return 0
    else
        echo_color "$RED" "✗ Base image test failed"
        return 1
    fi
}

# Function to show usage
show_usage() {
    echo_color "$BLUE" "Usage: $0 [OPTIONS]"
    echo_color "$YELLOW" "Options:"
    echo_color "$YELLOW" "  --flutter-version VERSION  Flutter version to use (default: $FLUTTER_VERSION)"
    echo_color "$YELLOW" "  --registry REGISTRY        Registry to push to (optional)"
    echo_color "$YELLOW" "  --test                     Test the built image"
    echo_color "$YELLOW" "  --push                     Push to registry after build"
    echo_color "$YELLOW" "  --help                     Show this help message"
    echo ""
    echo_color "$BLUE" "Examples:"
    echo_color "$YELLOW" "  $0                                    # Build with default Flutter version"
    echo_color "$YELLOW" "  $0 --flutter-version 3.24.5          # Build with specific Flutter version"
    echo_color "$YELLOW" "  $0 --registry ghcr.io/user --push    # Build and push to registry"
    echo_color "$YELLOW" "  $0 --test                             # Build and test"
}

# Parse command line arguments
PUSH=false
TEST=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --flutter-version)
            FLUTTER_VERSION="$2"
            BASE_IMAGE_TAG="$FLUTTER_VERSION"
            shift 2
            ;;
        --registry)
            REGISTRY="$2"
            shift 2
            ;;
        --push)
            PUSH=true
            shift
            ;;
        --test)
            TEST=true
            shift
            ;;
        --help|-h)
            show_usage
            exit 0
            ;;
        *)
            echo_color "$RED" "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Main execution
main() {
    echo_color "$BLUE" "CloudToLocalLLM Flutter Base Image Builder"
    echo_color "$BLUE" "=========================================="
    
    check_docker
    
    # Build base image
    if build_base_image; then
        echo_color "$GREEN" "Base image build completed successfully!"
    else
        echo_color "$RED" "Base image build failed!"
        exit 1
    fi
    
    # Test if requested
    if [ "$TEST" = true ]; then
        test_base_image
    fi
    
    # Push if requested
    if [ "$PUSH" = true ]; then
        push_to_registry
    fi
    
    echo_color "$GREEN" "All operations completed successfully!"
    echo_color "$BLUE" "You can now use this base image in your Dockerfile:"
    echo_color "$YELLOW" "FROM $BASE_IMAGE_NAME:$BASE_IMAGE_TAG AS flutter-base"
}

# Run main function
main "$@"
