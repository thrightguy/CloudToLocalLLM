#!/bin/bash
# Complete integration test for CloudToLocalLLM with Python tray daemon
# Tests the full system: Flutter app + Python daemon + IPC communication

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
FLUTTER_APP="$PROJECT_ROOT/build/linux/x64/release/bundle/cloudtolocalllm"
DAEMON_EXECUTABLE="$PROJECT_ROOT/dist/tray_daemon/linux-x64/cloudtolocalllm-tray"
CONFIG_DIR="$HOME/.cloudtolocalllm"
PORT_FILE="$CONFIG_DIR/tray_port"
LOG_FILE="$CONFIG_DIR/tray.log"

echo -e "${BLUE}CloudToLocalLLM Complete Integration Test${NC}"
echo -e "${BLUE}=========================================${NC}"
echo ""

# Function to print status messages
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Cleanup function
cleanup() {
    print_status "Cleaning up test environment..."
    
    # Kill any running processes
    if [ ! -z "$FLUTTER_PID" ]; then
        kill $FLUTTER_PID 2>/dev/null || true
        wait $FLUTTER_PID 2>/dev/null || true
    fi
    
    if [ ! -z "$DAEMON_PID" ]; then
        kill $DAEMON_PID 2>/dev/null || true
        wait $DAEMON_PID 2>/dev/null || true
    fi
    
    # Remove test files
    rm -f "$PORT_FILE" "$LOG_FILE" 2>/dev/null || true
    
    print_status "Cleanup completed"
}

# Set up cleanup trap
trap cleanup EXIT

# Check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check if Flutter app is built
    if [ ! -f "$FLUTTER_APP" ]; then
        print_error "Flutter app not found: $FLUTTER_APP"
        print_error "Please run: flutter build linux --release"
        exit 1
    fi
    
    # Check if daemon is built
    if [ ! -f "$DAEMON_EXECUTABLE" ]; then
        print_error "Tray daemon not found: $DAEMON_EXECUTABLE"
        print_error "Please run: ./scripts/build/build_tray_daemon.sh"
        exit 1
    fi
    
    # Check if executables are executable
    if [ ! -x "$FLUTTER_APP" ]; then
        print_error "Flutter app is not executable: $FLUTTER_APP"
        exit 1
    fi
    
    if [ ! -x "$DAEMON_EXECUTABLE" ]; then
        print_error "Tray daemon is not executable: $DAEMON_EXECUTABLE"
        exit 1
    fi
    
    print_status "Prerequisites check passed"
}

# Test daemon standalone
test_daemon_standalone() {
    print_status "Testing daemon standalone..."
    
    # Create config directory
    mkdir -p "$CONFIG_DIR"
    
    # Start daemon in background
    "$DAEMON_EXECUTABLE" --debug &
    DAEMON_PID=$!
    
    print_status "Daemon started with PID: $DAEMON_PID"
    
    # Wait for daemon to start
    local timeout=10
    local count=0
    
    while [ $count -lt $timeout ]; do
        if [ -f "$PORT_FILE" ]; then
            DAEMON_PORT=$(cat "$PORT_FILE")
            if [ ! -z "$DAEMON_PORT" ] && [ "$DAEMON_PORT" -gt 0 ]; then
                print_status "Daemon started on port: $DAEMON_PORT"
                
                # Test basic communication
                if command -v nc >/dev/null 2>&1; then
                    echo '{"command": "PING"}' | nc -w 2 127.0.0.1 $DAEMON_PORT >/dev/null 2>&1
                    if [ $? -eq 0 ]; then
                        print_status "Daemon communication test passed"
                    else
                        print_warning "Daemon communication test failed"
                    fi
                fi
                
                # Stop daemon
                kill $DAEMON_PID 2>/dev/null || true
                wait $DAEMON_PID 2>/dev/null || true
                DAEMON_PID=""
                
                return 0
            fi
        fi
        
        sleep 1
        count=$((count + 1))
    done
    
    print_error "Daemon failed to start within $timeout seconds"
    return 1
}

# Test Flutter app with system tray disabled
test_flutter_no_tray() {
    print_status "Testing Flutter app with system tray disabled..."
    
    # Set environment to disable system tray
    export DISABLE_SYSTEM_TRAY=true
    
    # Start Flutter app in background
    cd "$(dirname "$FLUTTER_APP")"
    timeout 10 "$FLUTTER_APP" &
    FLUTTER_PID=$!
    
    # Give it time to start
    sleep 3
    
    # Check if process is still running
    if kill -0 $FLUTTER_PID 2>/dev/null; then
        print_status "Flutter app started successfully (no tray mode)"
        
        # Stop the app
        kill $FLUTTER_PID 2>/dev/null || true
        wait $FLUTTER_PID 2>/dev/null || true
        FLUTTER_PID=""
        
        return 0
    else
        print_error "Flutter app failed to start"
        return 1
    fi
}

# Test Flutter app with system tray enabled
test_flutter_with_tray() {
    print_status "Testing Flutter app with system tray enabled..."
    
    # Unset the disable flag
    unset DISABLE_SYSTEM_TRAY
    
    # Start Flutter app in background
    cd "$(dirname "$FLUTTER_APP")"
    timeout 15 "$FLUTTER_APP" &
    FLUTTER_PID=$!
    
    # Give it time to start and initialize tray
    sleep 5
    
    # Check if process is still running
    if kill -0 $FLUTTER_PID 2>/dev/null; then
        print_status "Flutter app started successfully (with tray)"
        
        # Check if daemon was started by Flutter
        if [ -f "$PORT_FILE" ]; then
            local port=$(cat "$PORT_FILE" 2>/dev/null)
            if [ ! -z "$port" ] && [ "$port" -gt 0 ]; then
                print_status "Tray daemon was started by Flutter on port: $port"
                
                # Test communication
                if command -v nc >/dev/null 2>&1; then
                    echo '{"command": "PING"}' | nc -w 2 127.0.0.1 $port >/dev/null 2>&1
                    if [ $? -eq 0 ]; then
                        print_status "Flutter-daemon communication test passed"
                    else
                        print_warning "Flutter-daemon communication test failed"
                    fi
                fi
            else
                print_warning "Daemon port file exists but is invalid"
            fi
        else
            print_warning "Daemon port file not found - tray may not have started"
        fi
        
        # Stop the app
        kill $FLUTTER_PID 2>/dev/null || true
        wait $FLUTTER_PID 2>/dev/null || true
        FLUTTER_PID=""
        
        return 0
    else
        print_error "Flutter app failed to start with tray enabled"
        return 1
    fi
}

# Test log file creation and content
test_log_files() {
    print_status "Testing log file creation..."
    
    if [ -f "$LOG_FILE" ]; then
        local log_size=$(stat -c%s "$LOG_FILE" 2>/dev/null || echo "0")
        if [ "$log_size" -gt 0 ]; then
            print_status "Log file created with $log_size bytes"
            
            # Check for key log entries
            if grep -q "Starting CloudToLocalLLM Tray Daemon" "$LOG_FILE"; then
                print_status "Found daemon startup log entry"
            fi
            
            if grep -q "TCP server started" "$LOG_FILE"; then
                print_status "Found TCP server startup log entry"
            fi
            
            if grep -q "Starting system tray" "$LOG_FILE"; then
                print_status "Found system tray startup log entry"
            fi
            
            return 0
        else
            print_warning "Log file exists but is empty"
            return 0
        fi
    else
        print_warning "Log file not found"
        return 0
    fi
}

# Test build artifacts
test_build_artifacts() {
    print_status "Testing build artifacts..."
    
    local artifacts_found=0
    
    # Check Flutter build
    if [ -f "$FLUTTER_APP" ]; then
        print_status "✓ Flutter app binary found"
        artifacts_found=$((artifacts_found + 1))
    else
        print_error "✗ Flutter app binary missing"
    fi
    
    # Check tray daemon
    if [ -f "$DAEMON_EXECUTABLE" ]; then
        print_status "✓ Tray daemon binary found"
        artifacts_found=$((artifacts_found + 1))
    else
        print_error "✗ Tray daemon binary missing"
    fi
    
    # Check daemon size (should be reasonable)
    if [ -f "$DAEMON_EXECUTABLE" ]; then
        local size=$(stat -c%s "$DAEMON_EXECUTABLE" 2>/dev/null || echo "0")
        local size_mb=$((size / 1024 / 1024))
        if [ $size_mb -gt 5 ] && [ $size_mb -lt 50 ]; then
            print_status "✓ Daemon binary size is reasonable: ${size_mb}MB"
        else
            print_warning "⚠ Daemon binary size seems unusual: ${size_mb}MB"
        fi
    fi
    
    return $artifacts_found
}

# Main test execution
main() {
    local test_count=0
    local test_passed=0
    
    # Run tests
    tests=(
        "check_prerequisites"
        "test_build_artifacts"
        "test_daemon_standalone"
        "test_flutter_no_tray"
        "test_flutter_with_tray"
        "test_log_files"
    )
    
    for test in "${tests[@]}"; do
        test_count=$((test_count + 1))
        echo ""
        echo -e "${BLUE}Running test: $test${NC}"
        
        if $test; then
            test_passed=$((test_passed + 1))
            echo -e "${GREEN}✓ Test passed: $test${NC}"
        else
            echo -e "${RED}✗ Test failed: $test${NC}"
        fi
    done
    
    # Summary
    echo ""
    echo -e "${BLUE}Integration Test Summary${NC}"
    echo -e "${BLUE}=======================${NC}"
    echo "Total tests: $test_count"
    echo "Passed: $test_passed"
    echo "Failed: $((test_count - test_passed))"
    
    if [ $test_passed -eq $test_count ]; then
        echo -e "${GREEN}✓ All integration tests passed!${NC}"
        echo ""
        echo -e "${GREEN}🎉 CloudToLocalLLM system tray integration is working correctly!${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠ Some tests failed or were skipped${NC}"
        return 1
    fi
}

# Run main function
main
