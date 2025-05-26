#!/bin/bash

# CloudToLocalLLM Debug SSH Tunnel Setup Script
# Creates SSH tunnels for Flutter remote debugging

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
VPS_HOST="${VPS_HOST:-cloudllm@cloudtolocalllm.online}"
SSH_KEY="${SSH_KEY:-~/.ssh/id_ed25519}"
LOCAL_DEVTOOLS_PORT="${LOCAL_DEVTOOLS_PORT:-8181}"
LOCAL_VM_SERVICE_PORT="${LOCAL_VM_SERVICE_PORT:-8182}"
LOCAL_DEBUG_API_PORT="${LOCAL_DEBUG_API_PORT:-3334}"

# Function to print colored output
echo_color() {
    echo -e "${1}${2}${NC}"
}

# Function to check if port is available
check_port() {
    local port=$1
    if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
        return 1
    else
        return 0
    fi
}

# Function to find available port
find_available_port() {
    local start_port=$1
    local port=$start_port
    
    while ! check_port $port; do
        port=$((port + 1))
        if [ $port -gt $((start_port + 100)) ]; then
            echo_color "$RED" "Could not find available port starting from $start_port"
            exit 1
        fi
    done
    
    echo $port
}

# Function to setup SSH tunnel
setup_tunnel() {
    local local_port=$1
    local remote_port=$2
    local service_name=$3
    
    echo_color "$BLUE" "Setting up $service_name tunnel: localhost:$local_port -> $VPS_HOST:$remote_port"
    
    # Kill existing tunnel if it exists
    pkill -f "ssh.*$local_port:localhost:$remote_port" 2>/dev/null || true
    
    # Create new tunnel
    ssh -i "$SSH_KEY" -N -L "$local_port:localhost:$remote_port" "$VPS_HOST" &
    local tunnel_pid=$!
    
    # Wait a moment and check if tunnel is working
    sleep 2
    if kill -0 $tunnel_pid 2>/dev/null; then
        echo_color "$GREEN" "✓ $service_name tunnel established (PID: $tunnel_pid)"
        echo $tunnel_pid >> /tmp/debug_tunnels.pid
        return 0
    else
        echo_color "$RED" "✗ Failed to establish $service_name tunnel"
        return 1
    fi
}

# Function to test tunnel connectivity
test_tunnel() {
    local port=$1
    local service_name=$2
    
    echo_color "$BLUE" "Testing $service_name connectivity on port $port..."
    
    if curl -s --max-time 5 "http://localhost:$port" >/dev/null 2>&1; then
        echo_color "$GREEN" "✓ $service_name is accessible"
        return 0
    else
        echo_color "$YELLOW" "⚠ $service_name may not be ready yet (this is normal)"
        return 1
    fi
}

# Function to cleanup existing tunnels
cleanup_tunnels() {
    echo_color "$YELLOW" "Cleaning up existing debug tunnels..."
    
    if [ -f /tmp/debug_tunnels.pid ]; then
        while read -r pid; do
            if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
                kill "$pid" 2>/dev/null || true
                echo_color "$YELLOW" "Killed tunnel process $pid"
            fi
        done < /tmp/debug_tunnels.pid
        rm -f /tmp/debug_tunnels.pid
    fi
    
    # Kill any remaining SSH tunnels to the VPS
    pkill -f "ssh.*$VPS_HOST" 2>/dev/null || true
    
    echo_color "$GREEN" "Cleanup complete"
}

# Function to show usage
show_usage() {
    echo_color "$BLUE" "CloudToLocalLLM Debug Tunnel Setup"
    echo_color "$BLUE" "=================================="
    echo ""
    echo_color "$YELLOW" "Usage: $0 [OPTIONS] COMMAND"
    echo ""
    echo_color "$YELLOW" "Commands:"
    echo_color "$YELLOW" "  start    - Start debug tunnels"
    echo_color "$YELLOW" "  stop     - Stop debug tunnels"
    echo_color "$YELLOW" "  status   - Check tunnel status"
    echo_color "$YELLOW" "  restart  - Restart debug tunnels"
    echo ""
    echo_color "$YELLOW" "Options:"
    echo_color "$YELLOW" "  --vps-host HOST     VPS hostname (default: $VPS_HOST)"
    echo_color "$YELLOW" "  --ssh-key PATH      SSH key path (default: $SSH_KEY)"
    echo_color "$YELLOW" "  --devtools-port N   Local DevTools port (default: $LOCAL_DEVTOOLS_PORT)"
    echo_color "$YELLOW" "  --vm-port N         Local VM Service port (default: $LOCAL_VM_SERVICE_PORT)"
    echo_color "$YELLOW" "  --debug-port N      Local Debug API port (default: $LOCAL_DEBUG_API_PORT)"
    echo ""
    echo_color "$BLUE" "Examples:"
    echo_color "$YELLOW" "  $0 start                    # Start with default settings"
    echo_color "$YELLOW" "  $0 --devtools-port 9181 start  # Use custom DevTools port"
    echo_color "$YELLOW" "  $0 stop                     # Stop all tunnels"
}

# Function to start tunnels
start_tunnels() {
    echo_color "$BLUE" "CloudToLocalLLM Debug Tunnel Setup"
    echo_color "$BLUE" "=================================="
    
    # Check SSH connectivity
    echo_color "$BLUE" "Testing SSH connectivity to $VPS_HOST..."
    if ! ssh -i "$SSH_KEY" -o ConnectTimeout=10 "$VPS_HOST" "echo 'SSH connection successful'" >/dev/null 2>&1; then
        echo_color "$RED" "✗ Cannot connect to $VPS_HOST via SSH"
        echo_color "$YELLOW" "Please check:"
        echo_color "$YELLOW" "  - SSH key path: $SSH_KEY"
        echo_color "$YELLOW" "  - VPS hostname: $VPS_HOST"
        echo_color "$YELLOW" "  - Network connectivity"
        exit 1
    fi
    echo_color "$GREEN" "✓ SSH connectivity confirmed"
    
    # Cleanup existing tunnels
    cleanup_tunnels
    
    # Find available ports
    echo_color "$BLUE" "Finding available local ports..."
    LOCAL_DEVTOOLS_PORT=$(find_available_port $LOCAL_DEVTOOLS_PORT)
    LOCAL_VM_SERVICE_PORT=$(find_available_port $LOCAL_VM_SERVICE_PORT)
    LOCAL_DEBUG_API_PORT=$(find_available_port $LOCAL_DEBUG_API_PORT)
    
    echo_color "$GREEN" "Using ports:"
    echo_color "$GREEN" "  DevTools: $LOCAL_DEVTOOLS_PORT"
    echo_color "$GREEN" "  VM Service: $LOCAL_VM_SERVICE_PORT"
    echo_color "$GREEN" "  Debug API: $LOCAL_DEBUG_API_PORT"
    
    # Setup tunnels
    echo_color "$BLUE" "Setting up SSH tunnels..."
    
    # Create PID file
    touch /tmp/debug_tunnels.pid
    
    # Setup each tunnel
    setup_tunnel $LOCAL_DEVTOOLS_PORT 8181 "Flutter DevTools"
    setup_tunnel $LOCAL_VM_SERVICE_PORT 8182 "VM Service"
    setup_tunnel $LOCAL_DEBUG_API_PORT 3334 "Debug API"
    
    # Wait for services to be ready
    echo_color "$BLUE" "Waiting for services to be ready..."
    sleep 5
    
    # Test connectivity
    test_tunnel $LOCAL_DEVTOOLS_PORT "Flutter DevTools"
    test_tunnel $LOCAL_VM_SERVICE_PORT "VM Service"
    test_tunnel $LOCAL_DEBUG_API_PORT "Debug API"
    
    echo_color "$GREEN" "Debug tunnels setup complete!"
    echo_color "$BLUE" "Access URLs:"
    echo_color "$YELLOW" "  Flutter DevTools: http://localhost:$LOCAL_DEVTOOLS_PORT"
    echo_color "$YELLOW" "  VM Service: http://localhost:$LOCAL_VM_SERVICE_PORT"
    echo_color "$YELLOW" "  Debug API: http://localhost:$LOCAL_DEBUG_API_PORT"
    echo_color "$YELLOW" "  Web App: https://app.cloudtolocalllm.online"
    echo ""
    echo_color "$BLUE" "To stop tunnels, run: $0 stop"
}

# Function to stop tunnels
stop_tunnels() {
    echo_color "$BLUE" "Stopping debug tunnels..."
    cleanup_tunnels
    echo_color "$GREEN" "All debug tunnels stopped"
}

# Function to check tunnel status
check_status() {
    echo_color "$BLUE" "Debug Tunnel Status"
    echo_color "$BLUE" "==================="
    
    if [ ! -f /tmp/debug_tunnels.pid ]; then
        echo_color "$YELLOW" "No active tunnels found"
        return 0
    fi
    
    local active_count=0
    while read -r pid; do
        if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
            echo_color "$GREEN" "✓ Tunnel process $pid is running"
            active_count=$((active_count + 1))
        else
            echo_color "$RED" "✗ Tunnel process $pid is not running"
        fi
    done < /tmp/debug_tunnels.pid
    
    echo_color "$BLUE" "Active tunnels: $active_count"
    
    if [ $active_count -gt 0 ]; then
        echo_color "$BLUE" "Testing connectivity..."
        test_tunnel $LOCAL_DEVTOOLS_PORT "Flutter DevTools" || true
        test_tunnel $LOCAL_VM_SERVICE_PORT "VM Service" || true
        test_tunnel $LOCAL_DEBUG_API_PORT "Debug API" || true
    fi
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --vps-host)
            VPS_HOST="$2"
            shift 2
            ;;
        --ssh-key)
            SSH_KEY="$2"
            shift 2
            ;;
        --devtools-port)
            LOCAL_DEVTOOLS_PORT="$2"
            shift 2
            ;;
        --vm-port)
            LOCAL_VM_SERVICE_PORT="$2"
            shift 2
            ;;
        --debug-port)
            LOCAL_DEBUG_API_PORT="$2"
            shift 2
            ;;
        start)
            COMMAND="start"
            shift
            ;;
        stop)
            COMMAND="stop"
            shift
            ;;
        status)
            COMMAND="status"
            shift
            ;;
        restart)
            COMMAND="restart"
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

# Execute command
case "${COMMAND:-start}" in
    start)
        start_tunnels
        ;;
    stop)
        stop_tunnels
        ;;
    status)
        check_status
        ;;
    restart)
        stop_tunnels
        sleep 2
        start_tunnels
        ;;
    *)
        show_usage
        exit 1
        ;;
esac
