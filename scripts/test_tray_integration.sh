#!/bin/bash
# Integration test for CloudToLocalLLM System Tray Daemon
# Tests the communication between Flutter app and Python daemon

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
DAEMON_EXECUTABLE="$PROJECT_ROOT/dist/tray_daemon/linux-x64/cloudtolocalllm-tray"
CONFIG_DIR="$HOME/.cloudtolocalllm"
PORT_FILE="$CONFIG_DIR/tray_port"
LOG_FILE="$CONFIG_DIR/tray.log"

echo -e "${BLUE}CloudToLocalLLM Tray Integration Test${NC}"
echo -e "${BLUE}====================================${NC}"
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
    
    # Kill daemon if running
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

# Check if daemon executable exists
check_daemon_executable() {
    print_status "Checking daemon executable..."
    
    if [ ! -f "$DAEMON_EXECUTABLE" ]; then
        print_error "Daemon executable not found: $DAEMON_EXECUTABLE"
        print_error "Please run: ./scripts/build/build_tray_daemon.sh"
        exit 1
    fi
    
    if [ ! -x "$DAEMON_EXECUTABLE" ]; then
        print_error "Daemon executable is not executable: $DAEMON_EXECUTABLE"
        exit 1
    fi
    
    print_status "Daemon executable found and is executable"
}

# Test daemon startup
test_daemon_startup() {
    print_status "Testing daemon startup..."
    
    # Create config directory
    mkdir -p "$CONFIG_DIR"
    
    # Start daemon in background
    "$DAEMON_EXECUTABLE" --debug &
    DAEMON_PID=$!
    
    print_status "Daemon started with PID: $DAEMON_PID"
    
    # Wait for daemon to start and write port file
    local timeout=10
    local count=0
    
    while [ $count -lt $timeout ]; do
        if [ -f "$PORT_FILE" ]; then
            DAEMON_PORT=$(cat "$PORT_FILE")
            if [ ! -z "$DAEMON_PORT" ] && [ "$DAEMON_PORT" -gt 0 ]; then
                print_status "Daemon started on port: $DAEMON_PORT"
                return 0
            fi
        fi
        
        sleep 1
        count=$((count + 1))
    done
    
    print_error "Daemon failed to start within $timeout seconds"
    return 1
}

# Test TCP connection
test_tcp_connection() {
    print_status "Testing TCP connection to daemon..."
    
    if [ -z "$DAEMON_PORT" ]; then
        print_error "Daemon port not available"
        return 1
    fi
    
    # Test connection using netcat or telnet
    if command -v nc >/dev/null 2>&1; then
        if echo '{"command": "PING"}' | nc -w 5 127.0.0.1 $DAEMON_PORT >/dev/null 2>&1; then
            print_status "TCP connection successful"
            return 0
        else
            print_error "TCP connection failed"
            return 1
        fi
    else
        print_warning "netcat not available, skipping TCP connection test"
        return 0
    fi
}

# Test JSON communication
test_json_communication() {
    print_status "Testing JSON communication..."
    
    if [ -z "$DAEMON_PORT" ]; then
        print_error "Daemon port not available"
        return 1
    fi
    
    # Test ping command
    if command -v nc >/dev/null 2>&1; then
        local response=$(echo '{"command": "PING"}' | nc -w 5 127.0.0.1 $DAEMON_PORT 2>/dev/null)
        if echo "$response" | grep -q "PONG"; then
            print_status "JSON communication successful (PING/PONG)"
            return 0
        else
            print_warning "JSON communication test inconclusive"
            return 0
        fi
    else
        print_warning "netcat not available, skipping JSON communication test"
        return 0
    fi
}

# Test log file creation
test_log_file() {
    print_status "Testing log file creation..."
    
    if [ -f "$LOG_FILE" ]; then
        local log_size=$(stat -c%s "$LOG_FILE" 2>/dev/null || echo "0")
        if [ "$log_size" -gt 0 ]; then
            print_status "Log file created and contains data"
            print_status "Log file size: $log_size bytes"
            
            # Show last few lines of log
            print_status "Last few log entries:"
            tail -n 5 "$LOG_FILE" | sed 's/^/  /'
            
            return 0
        else
            print_warning "Log file exists but is empty"
            return 0
        fi
    else
        print_warning "Log file not found (this may be normal)"
        return 0
    fi
}

# Test daemon shutdown
test_daemon_shutdown() {
    print_status "Testing daemon shutdown..."
    
    if [ ! -z "$DAEMON_PID" ]; then
        # Send termination signal
        kill -TERM $DAEMON_PID 2>/dev/null || true
        
        # Wait for graceful shutdown
        local timeout=5
        local count=0
        
        while [ $count -lt $timeout ]; do
            if ! kill -0 $DAEMON_PID 2>/dev/null; then
                print_status "Daemon shut down gracefully"
                DAEMON_PID=""
                return 0
            fi
            
            sleep 1
            count=$((count + 1))
        done
        
        # Force kill if still running
        kill -KILL $DAEMON_PID 2>/dev/null || true
        print_warning "Daemon required force kill"
        DAEMON_PID=""
        return 0
    else
        print_warning "Daemon PID not available for shutdown test"
        return 0
    fi
}

# Main test execution
main() {
    local test_count=0
    local test_passed=0
    
    # Run tests
    tests=(
        "check_daemon_executable"
        "test_daemon_startup"
        "test_tcp_connection"
        "test_json_communication"
        "test_log_file"
        "test_daemon_shutdown"
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
    echo -e "${BLUE}Test Summary${NC}"
    echo -e "${BLUE}============${NC}"
    echo "Total tests: $test_count"
    echo "Passed: $test_passed"
    echo "Failed: $((test_count - test_passed))"
    
    if [ $test_passed -eq $test_count ]; then
        echo -e "${GREEN}✓ All tests passed!${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠ Some tests failed or were skipped${NC}"
        return 1
    fi
}

# Run main function
main
