#!/bin/bash

# CloudToLocalLLM Three-Application Build Script
# Builds all three applications in the correct dependency order

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION=$(cat "$PROJECT_ROOT/version.txt")
BUILD_TYPE="${1:-release}"  # Default to release build
VERBOSE="${2:-false}"

echo -e "${BLUE}🚀 CloudToLocalLLM Three-Application Build Script v$VERSION${NC}"
echo -e "${BLUE}📁 Project Root: $PROJECT_ROOT${NC}"
echo -e "${BLUE}🔧 Build Type: $BUILD_TYPE${NC}"
echo ""

# Function to print status messages
print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Function to run flutter commands with proper error handling
run_flutter_command() {
    local app_name="$1"
    local command="$2"
    local app_dir="$PROJECT_ROOT/apps/$app_name"
    
    print_info "Running: $command in $app_name"
    
    cd "$app_dir"
    
    if [ "$VERBOSE" = "true" ]; then
        eval "$command"
    else
        eval "$command" > /dev/null 2>&1
    fi
    
    if [ $? -eq 0 ]; then
        print_status "$app_name: $command completed successfully"
    else
        print_error "$app_name: $command failed"
        exit 1
    fi
}

# Function to check if Flutter is installed
check_flutter() {
    print_info "Checking Flutter installation..."
    
    if ! command -v flutter &> /dev/null; then
        print_error "Flutter is not installed or not in PATH"
        exit 1
    fi
    
    local flutter_version=$(flutter --version | head -n 1)
    print_status "Flutter found: $flutter_version"
}

# Function to clean previous builds
clean_builds() {
    print_info "Cleaning previous builds..."
    
    # Clean build directories
    rm -rf "$PROJECT_ROOT/build"
    mkdir -p "$PROJECT_ROOT/build"/{main,chat,tray,settings}

    # Clean individual app builds
    for app in shared main chat tray settings; do
        if [ -d "$PROJECT_ROOT/apps/$app" ]; then
            cd "$PROJECT_ROOT/apps/$app"
            flutter clean > /dev/null 2>&1 || true
        fi
    done
    
    print_status "Build directories cleaned"
}

# Function to get dependencies for all apps
get_dependencies() {
    print_info "Getting dependencies for all applications..."
    
    # Get dependencies in dependency order
    for app in shared main chat tray settings; do
        if [ -d "$PROJECT_ROOT/apps/$app" ]; then
            run_flutter_command "$app" "flutter pub get"
        fi
    done
    
    print_status "All dependencies resolved"
}

# Function to generate code (for shared package)
generate_code() {
    print_info "Generating code for shared package..."
    
    if [ -d "$PROJECT_ROOT/apps/shared" ]; then
        run_flutter_command "shared" "flutter packages pub run build_runner build --delete-conflicting-outputs"
    fi
    
    print_status "Code generation completed"
}

# Function to build individual application
build_app() {
    local app_name="$1"
    local app_dir="$PROJECT_ROOT/apps/$app_name"
    local output_dir="$PROJECT_ROOT/build/$app_name"

    if [ ! -d "$app_dir" ]; then
        print_warning "Application $app_name not found, skipping..."
        return
    fi

    print_info "Building $app_name application..."

    # Build the application
    run_flutter_command "$app_name" "flutter build linux --$BUILD_TYPE"

    # Copy build artifacts to central build directory
    local source_dir="$app_dir/build/linux/x64/$BUILD_TYPE/bundle"
    if [ -d "$source_dir" ]; then
        cp -r "$source_dir"/* "$output_dir/"

        # Handle executable naming - different apps have different naming patterns
        local target_exe="$output_dir/cloudtolocalllm_$app_name"
        local found_exe=""

        # Find the actual executable in the build output
        if [ -f "$output_dir/cloudtolocalllm_$app_name" ]; then
            found_exe="$output_dir/cloudtolocalllm_$app_name"
        elif [ -f "$output_dir/cloudtolocalllm" ]; then
            found_exe="$output_dir/cloudtolocalllm"
        elif [ -f "$output_dir/$app_name" ]; then
            found_exe="$output_dir/$app_name"
        fi

        # Rename to standardized format if needed
        if [ -n "$found_exe" ] && [ "$found_exe" != "$target_exe" ]; then
            mv "$found_exe" "$target_exe"
        fi

        if [ -f "$target_exe" ]; then
            print_status "$app_name built successfully"
        else
            print_error "$app_name executable not found after build"
            exit 1
        fi
    else
        print_error "$app_name build artifacts not found"
        exit 1
    fi
}

# Function to create deployment package
create_package() {
    print_info "Creating deployment package..."
    
    local package_dir="$PROJECT_ROOT/build/cloudtolocalllm-v$VERSION-linux"
    mkdir -p "$package_dir"/{bin,lib,data,scripts,config}
    
    # Copy executables
    for app in main chat tray settings; do
        if [ -f "$PROJECT_ROOT/build/$app/cloudtolocalllm_$app" ]; then
            cp "$PROJECT_ROOT/build/$app/cloudtolocalllm_$app" "$package_dir/bin/"
        else
            print_warning "Executable for $app not found at $PROJECT_ROOT/build/$app/cloudtolocalllm_$app"
        fi
    done

    # Copy shared libraries (from any app, they should be the same)
    if [ -d "$PROJECT_ROOT/build/chat/lib" ]; then
        cp -r "$PROJECT_ROOT/build/chat/lib"/* "$package_dir/lib/"
    fi

    # Copy assets and data
    for app in chat tray settings; do
        if [ -d "$PROJECT_ROOT/build/$app/data" ]; then
            cp -r "$PROJECT_ROOT/build/$app/data"/* "$package_dir/data/" 2>/dev/null || true
        fi
    done
    
    # Copy scripts
    cp "$PROJECT_ROOT/scripts"/*.sh "$package_dir/scripts/" 2>/dev/null || true
    
    # Create README
    cat > "$package_dir/README.md" << EOF
# CloudToLocalLLM v$VERSION

## Installation

1. Extract this package to your desired location
2. Run \`./scripts/start.sh\` to start all services
3. Use \`./scripts/stop.sh\` to stop all services

## Applications

- \`bin/cloudtolocalllm_main\` - Main ChatGPT-like interface with system tray integration
- \`bin/cloudtolocalllm_chat\` - Standalone chat interface
- \`bin/cloudtolocalllm_tray\` - Flutter-only system tray service
- \`bin/cloudtolocalllm_settings\` - Connection management and Ollama testing

## Requirements

- Linux x64 system
- GTK3 development libraries
- libayatana-appindicator3-dev (for system tray)

For more information, visit: https://cloudtolocalllm.online
EOF
    
    print_status "Deployment package created: $package_dir"
}

# Function to run tests
run_tests() {
    print_info "Running tests for all applications..."
    
    for app in shared main chat tray settings; do
        if [ -d "$PROJECT_ROOT/apps/$app" ]; then
            print_info "Testing $app..."
            run_flutter_command "$app" "flutter test"
        fi
    done
    
    print_status "All tests completed"
}

# Function to display build summary
display_summary() {
    print_info "Build Summary:"
    echo ""
    
    for app in main chat tray settings; do
        local exe_path="$PROJECT_ROOT/build/$app/cloudtolocalllm_$app"
        if [ -f "$exe_path" ]; then
            local size=$(du -h "$exe_path" | cut -f1)
            print_status "$app: Built successfully ($size)"
        else
            print_error "$app: Build failed"
        fi
    done
    
    echo ""
    local total_size=$(du -sh "$PROJECT_ROOT/build" | cut -f1)
    print_info "Total build size: $total_size"
    
    if [ -d "$PROJECT_ROOT/build/cloudtolocalllm-v$VERSION-linux" ]; then
        local package_size=$(du -sh "$PROJECT_ROOT/build/cloudtolocalllm-v$VERSION-linux" | cut -f1)
        print_info "Package size: $package_size"
    fi
}

# Main build process
main() {
    echo -e "${BLUE}🔧 Starting CloudToLocalLLM build process...${NC}"
    echo ""
    
    # Pre-build checks
    check_flutter
    
    # Clean previous builds
    clean_builds
    
    # Get dependencies
    get_dependencies
    
    # Generate code
    generate_code
    
    # Run tests (optional, can be skipped with --skip-tests)
    if [ "$3" != "--skip-tests" ]; then
        run_tests
    fi
    
    # Build applications in order
    print_info "Building applications..."
    build_app "main"
    build_app "chat"
    build_app "tray"
    build_app "settings"
    
    # Create deployment package
    create_package
    
    # Display summary
    display_summary
    
    echo ""
    print_status "CloudToLocalLLM build completed successfully! 🎉"
    echo -e "${GREEN}📦 Package ready: build/cloudtolocalllm-v$VERSION-linux${NC}"
}

# Handle command line arguments
case "$1" in
    "clean")
        clean_builds
        ;;
    "deps")
        get_dependencies
        ;;
    "test")
        run_tests
        ;;
    "package")
        create_package
        ;;
    "help"|"-h"|"--help")
        echo "Usage: $0 [BUILD_TYPE] [VERBOSE] [OPTIONS]"
        echo ""
        echo "BUILD_TYPE: debug|release (default: release)"
        echo "VERBOSE: true|false (default: false)"
        echo "OPTIONS: --skip-tests"
        echo ""
        echo "Commands:"
        echo "  clean   - Clean build directories"
        echo "  deps    - Get dependencies only"
        echo "  test    - Run tests only"
        echo "  package - Create package only"
        echo "  help    - Show this help"
        ;;
    *)
        main "$@"
        ;;
esac
