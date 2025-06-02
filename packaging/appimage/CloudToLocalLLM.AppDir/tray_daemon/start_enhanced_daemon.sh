#!/bin/bash
# CloudToLocalLLM Enhanced Tray Daemon Startup Script

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DAEMON_SCRIPT="$SCRIPT_DIR/enhanced_tray_daemon.py"
VENV_DIR="$SCRIPT_DIR/venv"
REQUIREMENTS_FILE="$SCRIPT_DIR/requirements.txt"
LOG_FILE="$HOME/.cloudtolocalllm/tray_daemon.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1" >&2
}

warning() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1"
}

# Check if Python 3 is available
check_python() {
    if command -v python3 &> /dev/null; then
        PYTHON_CMD="python3"
    elif command -v python &> /dev/null && python --version | grep -q "Python 3"; then
        PYTHON_CMD="python"
    else
        error "Python 3 is required but not found. Please install Python 3."
        exit 1
    fi
    
    log "Using Python: $($PYTHON_CMD --version)"
}

# Create virtual environment if it doesn't exist
setup_venv() {
    if [ ! -d "$VENV_DIR" ]; then
        log "Creating virtual environment..."
        $PYTHON_CMD -m venv "$VENV_DIR"
    fi
    
    # Activate virtual environment
    source "$VENV_DIR/bin/activate"
    
    # Upgrade pip
    pip install --upgrade pip
    
    # Install requirements
    if [ -f "$REQUIREMENTS_FILE" ]; then
        log "Installing dependencies..."
        pip install -r "$REQUIREMENTS_FILE"
    else
        warning "Requirements file not found: $REQUIREMENTS_FILE"
        log "Installing basic dependencies..."
        pip install pystray pillow psutil requests aiohttp
    fi
}

# Check if daemon is already running
check_running() {
    local port_file="$HOME/.cloudtolocalllm/tray_port"
    
    if [ -f "$port_file" ]; then
        local port=$(cat "$port_file")
        if netstat -tuln 2>/dev/null | grep -q ":$port "; then
            log "Enhanced tray daemon is already running on port $port"
            return 0
        else
            warning "Port file exists but daemon not responding, cleaning up..."
            rm -f "$port_file"
        fi
    fi
    
    return 1
}

# Start the daemon
start_daemon() {
    log "Starting CloudToLocalLLM Enhanced Tray Daemon..."
    
    # Ensure log directory exists
    mkdir -p "$(dirname "$LOG_FILE")"
    
    # Activate virtual environment
    source "$VENV_DIR/bin/activate"
    
    # Start daemon
    if [ "$1" = "--debug" ]; then
        log "Starting in debug mode..."
        $PYTHON_CMD "$DAEMON_SCRIPT" --debug
    else
        log "Starting in background mode..."
        nohup $PYTHON_CMD "$DAEMON_SCRIPT" >> "$LOG_FILE" 2>&1 &
        local daemon_pid=$!
        
        # Wait a moment to see if it started successfully
        sleep 2
        
        if kill -0 $daemon_pid 2>/dev/null; then
            log "Enhanced tray daemon started successfully (PID: $daemon_pid)"
            log "Log file: $LOG_FILE"
        else
            error "Failed to start enhanced tray daemon"
            exit 1
        fi
    fi
}

# Stop the daemon
stop_daemon() {
    log "Stopping CloudToLocalLLM Enhanced Tray Daemon..."
    
    # Find and kill daemon processes
    pkill -f "enhanced_tray_daemon.py" || true
    
    # Clean up port file
    rm -f "$HOME/.cloudtolocalllm/tray_port"
    
    log "Enhanced tray daemon stopped"
}

# Show daemon status
show_status() {
    local port_file="$HOME/.cloudtolocalllm/tray_port"
    
    if check_running; then
        local port=$(cat "$port_file")
        log "Enhanced tray daemon is running on port $port"
        
        # Show process info
        pgrep -f "enhanced_tray_daemon.py" | while read pid; do
            log "Process: $pid ($(ps -p $pid -o comm=))"
        done
    else
        log "Enhanced tray daemon is not running"
    fi
}

# Show help
show_help() {
    echo "CloudToLocalLLM Enhanced Tray Daemon Startup Script"
    echo ""
    echo "Usage: $0 [COMMAND] [OPTIONS]"
    echo ""
    echo "Commands:"
    echo "  start     Start the enhanced tray daemon (default)"
    echo "  stop      Stop the enhanced tray daemon"
    echo "  restart   Restart the enhanced tray daemon"
    echo "  status    Show daemon status"
    echo "  setup     Setup virtual environment and dependencies"
    echo "  help      Show this help message"
    echo ""
    echo "Options:"
    echo "  --debug   Start in debug mode (foreground with verbose logging)"
    echo ""
    echo "Examples:"
    echo "  $0 start          # Start daemon in background"
    echo "  $0 start --debug  # Start daemon in debug mode"
    echo "  $0 stop           # Stop daemon"
    echo "  $0 restart        # Restart daemon"
    echo "  $0 status         # Check if daemon is running"
}

# Main script logic
main() {
    local command="${1:-start}"
    local option="$2"
    
    case "$command" in
        "start")
            check_python
            setup_venv
            
            if check_running; then
                exit 0
            fi
            
            start_daemon "$option"
            ;;
        "stop")
            stop_daemon
            ;;
        "restart")
            stop_daemon
            sleep 1
            check_python
            setup_venv
            start_daemon "$option"
            ;;
        "status")
            show_status
            ;;
        "setup")
            check_python
            setup_venv
            log "Setup completed successfully"
            ;;
        "help"|"--help"|"-h")
            show_help
            ;;
        *)
            error "Unknown command: $command"
            show_help
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"
