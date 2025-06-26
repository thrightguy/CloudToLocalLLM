#!/bin/bash

# CloudToLocalLLM Flutter Build with Timestamp Injection
# Builds Flutter applications with automatic timestamp injection and version management
# Supports web, Linux, Windows, and mobile platforms with build-time version injection

set -euo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

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

log_step() {
    echo -e "${CYAN}[STEP]${NC} $1"
}

# Default configuration
BUILD_TARGET="web"
BUILD_MODE="release"
INJECT_TIMESTAMP=true
UPDATE_VERSION=true
CLEAN_BUILD=false
VERBOSE=false
FLUTTER_BUILD_ARGS=""

# Show usage information
show_usage() {
    echo "CloudToLocalLLM Flutter Build with Timestamp Injection"
    echo
    echo "Usage: $0 [options] [target]"
    echo
    echo "Targets:"
    echo "  web                Build for web (default)"
    echo "  linux              Build for Linux desktop"
    echo "  windows            Build for Windows desktop"
    echo "  android            Build for Android"
    echo "  ios                Build for iOS"
    echo "  all                Build for all available platforms"
    echo
    echo "Options:"
    echo "  --debug            Build in debug mode (default: release)"
    echo "  --no-timestamp     Skip timestamp injection"
    echo "  --no-version       Skip version update"
    echo "  --clean            Clean build (flutter clean first)"
    echo "  --verbose          Enable verbose output"
    echo "  --help, -h         Show this help message"
    echo
    echo "Flutter Build Options (passed through):"
    echo "  --no-tree-shake-icons    Disable tree shaking of icons"
    echo "  --web-renderer <value>   Web renderer (html, canvaskit, auto)"
    echo "  --dart-define <key=val>  Define Dart constants"
    echo "  --obfuscate             Obfuscate Dart code"
    echo "  --split-debug-info      Split debug info"
    echo
    echo "Examples:"
    echo "  $0                 # Build web in release mode with timestamp"
    echo "  $0 linux --debug  # Build Linux in debug mode"
    echo "  $0 --clean web    # Clean build for web"
    echo "  $0 web --no-tree-shake-icons  # Web build without icon tree shaking"
    echo "  $0 all             # Build for all platforms"
    echo
}

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --debug)
                BUILD_MODE="debug"
                shift
                ;;
            --no-timestamp)
                INJECT_TIMESTAMP=false
                shift
                ;;
            --no-version)
                UPDATE_VERSION=false
                shift
                ;;
            --clean)
                CLEAN_BUILD=true
                shift
                ;;
            --verbose)
                VERBOSE=true
                shift
                ;;
            --help|-h)
                show_usage
                exit 0
                ;;
            web|linux|windows|android|ios|all)
                BUILD_TARGET="$1"
                shift
                ;;
            --no-tree-shake-icons|--tree-shake-icons|--web-renderer|--dart-define|--dart-define-from-file|--obfuscate|--split-debug-info|--source-maps|--pwa-strategy)
                # Pass through Flutter-specific build options
                FLUTTER_BUILD_ARGS="$FLUTTER_BUILD_ARGS $1"
                shift
                # Handle options that take values
                if [[ $# -gt 0 && "$1" != --* && "$1" != "" && "$1" != "web" && "$1" != "linux" && "$1" != "windows" && "$1" != "android" && "$1" != "ios" && "$1" != "all" ]]; then
                    FLUTTER_BUILD_ARGS="$FLUTTER_BUILD_ARGS $1"
                    shift
                fi
                ;;
            *)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
}

# Check prerequisites
check_prerequisites() {
    log_step "Checking prerequisites..."
    
    # Check if Flutter is available
    if ! command -v flutter &> /dev/null; then
        log_error "Flutter is not installed or not in PATH"
        exit 1
    fi
    
    # Check if we're in the correct directory
    if [[ ! -f "$PROJECT_ROOT/pubspec.yaml" ]]; then
        log_error "Not in CloudToLocalLLM project directory"
        exit 1
    fi
    
    # Check Flutter doctor for target platform
    case $BUILD_TARGET in
        web)
            if ! flutter doctor | grep -q "Chrome"; then
                log_warning "Chrome not detected for web development"
            fi
            ;;
        linux)
            if ! flutter doctor | grep -q "Linux toolchain"; then
                log_warning "Linux toolchain not properly configured"
            fi
            ;;
        windows)
            if ! flutter doctor | grep -q "Visual Studio"; then
                log_warning "Visual Studio not detected for Windows development"
            fi
            ;;
        android)
            if ! flutter doctor | grep -q "Android toolchain"; then
                log_error "Android toolchain not configured"
                exit 1
            fi
            ;;
        ios)
            if ! flutter doctor | grep -q "Xcode"; then
                log_error "Xcode not configured for iOS development"
                exit 1
            fi
            ;;
    esac
    
    log_success "Prerequisites check passed"
}

# Update version and inject timestamp
update_version_info() {
    if [[ "$UPDATE_VERSION" == "true" ]]; then
        log_step "Updating version information..."
        
        if [[ -f "$PROJECT_ROOT/scripts/version_manager.sh" ]]; then
            "$PROJECT_ROOT/scripts/version_manager.sh" increment build
            log_success "Version updated with new build number"
        else
            log_warning "Version manager script not found, skipping version update"
        fi
    fi
    
    if [[ "$INJECT_TIMESTAMP" == "true" ]]; then
        log_step "Injecting build timestamp..."
        
        if [[ -f "$PROJECT_ROOT/scripts/build_time_version_injector.sh" ]]; then
            "$PROJECT_ROOT/scripts/build_time_version_injector.sh"
            log_success "Build timestamp injected"
        else
            log_warning "Build time injector script not found, skipping timestamp injection"
        fi
    fi
}

# Clean build if requested
clean_build_if_requested() {
    if [[ "$CLEAN_BUILD" == "true" ]]; then
        log_step "Cleaning previous build..."
        cd "$PROJECT_ROOT"
        flutter clean
        flutter pub get
        log_success "Build cleaned and dependencies refreshed"
    fi
}

# Get Flutter dependencies
get_dependencies() {
    log_step "Getting Flutter dependencies..."
    cd "$PROJECT_ROOT"
    flutter pub get
    log_success "Dependencies updated"
}

# Build for specific platform
build_platform() {
    local platform="$1"
    local mode="$2"
    
    log_step "Building for $platform in $mode mode..."
    cd "$PROJECT_ROOT"
    
    local build_args=""
    if [[ "$VERBOSE" == "true" ]]; then
        build_args="--verbose"
    fi

    # Add Flutter-specific build arguments
    if [[ -n "$FLUTTER_BUILD_ARGS" ]]; then
        build_args="$build_args $FLUTTER_BUILD_ARGS"
    fi

    case $platform in
        web)
            flutter build web --$mode --web-renderer html $build_args
            if [[ -d "$PROJECT_ROOT/build/web" ]]; then
                log_success "Web build completed: build/web/"
            else
                log_error "Web build failed"
                return 1
            fi
            ;;
        linux)
            flutter build linux --$mode $build_args
            if [[ -d "$PROJECT_ROOT/build/linux" ]]; then
                log_success "Linux build completed: build/linux/"
            else
                log_error "Linux build failed"
                return 1
            fi
            ;;
        windows)
            flutter build windows --$mode $build_args
            if [[ -d "$PROJECT_ROOT/build/windows" ]]; then
                log_success "Windows build completed: build/windows/"
            else
                log_error "Windows build failed"
                return 1
            fi
            ;;
        android)
            flutter build apk --$mode $build_args
            if [[ -f "$PROJECT_ROOT/build/app/outputs/flutter-apk/app-$mode.apk" ]]; then
                log_success "Android APK build completed: build/app/outputs/flutter-apk/"
            else
                log_error "Android build failed"
                return 1
            fi
            ;;
        ios)
            flutter build ios --$mode $build_args
            if [[ -d "$PROJECT_ROOT/build/ios" ]]; then
                log_success "iOS build completed: build/ios/"
            else
                log_error "iOS build failed"
                return 1
            fi
            ;;
        *)
            log_error "Unknown platform: $platform"
            return 1
            ;;
    esac
}

# Build all platforms
build_all_platforms() {
    local platforms=("web" "linux")
    local failed_builds=()
    
    # Add other platforms if available
    if flutter doctor | grep -q "Android toolchain"; then
        platforms+=("android")
    fi
    
    if flutter doctor | grep -q "Visual Studio"; then
        platforms+=("windows")
    fi
    
    if flutter doctor | grep -q "Xcode"; then
        platforms+=("ios")
    fi
    
    log_info "Building for platforms: ${platforms[*]}"
    
    for platform in "${platforms[@]}"; do
        echo
        if build_platform "$platform" "$BUILD_MODE"; then
            log_success "✅ $platform build successful"
        else
            log_error "❌ $platform build failed"
            failed_builds+=("$platform")
        fi
    done
    
    if [[ ${#failed_builds[@]} -gt 0 ]]; then
        log_warning "Some builds failed: ${failed_builds[*]}"
        return 1
    else
        log_success "All platform builds completed successfully"
        return 0
    fi
}

# Generate build report
generate_build_report() {
    local version=""
    if [[ -f "$PROJECT_ROOT/scripts/version_manager.sh" ]]; then
        version=$("$PROJECT_ROOT/scripts/version_manager.sh" get)
    else
        version="unknown"
    fi
    
    echo
    echo "=== CloudToLocalLLM Build Report ==="
    echo "Timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "Version: $version"
    echo "Target: $BUILD_TARGET"
    echo "Mode: $BUILD_MODE"
    echo "Timestamp Injection: $INJECT_TIMESTAMP"
    echo "Version Update: $UPDATE_VERSION"
    echo "Clean Build: $CLEAN_BUILD"
    echo
    
    # Show build outputs
    echo "Build Outputs:"
    if [[ "$BUILD_TARGET" == "web" || "$BUILD_TARGET" == "all" ]] && [[ -d "$PROJECT_ROOT/build/web" ]]; then
        local web_size=$(du -sh "$PROJECT_ROOT/build/web" 2>/dev/null | cut -f1 || echo "unknown")
        echo "  📱 Web: build/web/ ($web_size)"
    fi
    
    if [[ "$BUILD_TARGET" == "linux" || "$BUILD_TARGET" == "all" ]] && [[ -d "$PROJECT_ROOT/build/linux" ]]; then
        local linux_size=$(du -sh "$PROJECT_ROOT/build/linux" 2>/dev/null | cut -f1 || echo "unknown")
        echo "  🐧 Linux: build/linux/ ($linux_size)"
    fi
    
    if [[ "$BUILD_TARGET" == "windows" || "$BUILD_TARGET" == "all" ]] && [[ -d "$PROJECT_ROOT/build/windows" ]]; then
        local windows_size=$(du -sh "$PROJECT_ROOT/build/windows" 2>/dev/null | cut -f1 || echo "unknown")
        echo "  🪟 Windows: build/windows/ ($windows_size)"
    fi
    
    if [[ "$BUILD_TARGET" == "android" || "$BUILD_TARGET" == "all" ]] && [[ -f "$PROJECT_ROOT/build/app/outputs/flutter-apk/app-$BUILD_MODE.apk" ]]; then
        local apk_size=$(du -sh "$PROJECT_ROOT/build/app/outputs/flutter-apk/app-$BUILD_MODE.apk" 2>/dev/null | cut -f1 || echo "unknown")
        echo "  🤖 Android: build/app/outputs/flutter-apk/app-$BUILD_MODE.apk ($apk_size)"
    fi
    
    echo
    echo "Next steps:"
    echo "  - Test the built application"
    echo "  - Deploy to target environment"
    echo "  - Update documentation if needed"
    echo
}

# Main execution function
main() {
    log_info "CloudToLocalLLM Flutter Build with Timestamp Injection"
    echo
    
    # Parse command line arguments
    parse_arguments "$@"
    
    # Show build configuration
    log_info "Build Configuration:"
    log_info "  Target: $BUILD_TARGET"
    log_info "  Mode: $BUILD_MODE"
    log_info "  Timestamp Injection: $INJECT_TIMESTAMP"
    log_info "  Version Update: $UPDATE_VERSION"
    log_info "  Clean Build: $CLEAN_BUILD"
    echo
    
    # Execute build steps
    check_prerequisites
    echo
    
    clean_build_if_requested
    echo
    
    update_version_info
    echo
    
    get_dependencies
    echo
    
    # Build for target platform(s)
    if [[ "$BUILD_TARGET" == "all" ]]; then
        build_all_platforms
    else
        build_platform "$BUILD_TARGET" "$BUILD_MODE"
    fi
    
    echo
    generate_build_report
    
    log_success "Flutter build with timestamp injection completed!"
}

# Run main function
main "$@"
