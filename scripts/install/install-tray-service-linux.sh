#!/bin/bash
# CloudToLocalLLM Tray Service Installation Script for Linux
# This script installs the CloudToLocalLLM tray daemon as a systemd user service

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SERVICE_NAME="cloudtolocalllm-tray"
SERVICE_FILE="$SERVICE_NAME.service"
USER_SERVICE_DIR="$HOME/.config/systemd/user"
SYSTEM_SERVICE_DIR="/etc/systemd/system"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_dependencies() {
    print_status "Checking dependencies..."
    
    if ! command -v systemctl &> /dev/null; then
        print_error "systemctl not found. This script requires systemd."
        exit 1
    fi
    
    if ! command -v python3 &> /dev/null; then
        print_error "python3 not found. Please install Python 3."
        exit 1
    fi
    
    print_success "Dependencies check passed"
}

install_tray_daemon() {
    print_status "Installing tray daemon..."
    
    # Build the tray daemon if not already built
    if [ ! -f "$PROJECT_ROOT/dist/tray_daemon/linux-x64/cloudtolocalllm-tray" ]; then
        print_status "Building tray daemon..."
        cd "$PROJECT_ROOT"
        ./scripts/build/build_tray_daemon.sh
    fi
    
    # Install to /usr/local/bin (requires sudo)
    if [ "$EUID" -eq 0 ]; then
        # Running as root
        cp "$PROJECT_ROOT/dist/tray_daemon/linux-x64/cloudtolocalllm-tray" /usr/local/bin/
        chmod +x /usr/local/bin/cloudtolocalllm-tray
        print_success "Tray daemon installed to /usr/local/bin/"
    else
        # Running as user - install to ~/.local/bin
        mkdir -p "$HOME/.local/bin"
        cp "$PROJECT_ROOT/dist/tray_daemon/linux-x64/cloudtolocalllm-tray" "$HOME/.local/bin/"
        chmod +x "$HOME/.local/bin/cloudtolocalllm-tray"
        print_success "Tray daemon installed to ~/.local/bin/"
        
        # Add to PATH if not already there
        if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
            print_warning "~/.local/bin is not in your PATH. Adding to ~/.bashrc"
            echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
            print_status "Please run 'source ~/.bashrc' or restart your terminal"
        fi
    fi
}

install_user_service() {
    print_status "Installing systemd user service..."
    
    # Create user service directory
    mkdir -p "$USER_SERVICE_DIR"
    
    # Determine executable path
    if [ -f "/usr/local/bin/cloudtolocalllm-tray" ]; then
        EXEC_PATH="/usr/local/bin/cloudtolocalllm-tray"
    else
        EXEC_PATH="$HOME/.local/bin/cloudtolocalllm-tray"
    fi
    
    # Create service file
    cat > "$USER_SERVICE_DIR/$SERVICE_FILE" << EOF
[Unit]
Description=CloudToLocalLLM System Tray Daemon
Documentation=https://cloudtolocalllm.online
After=graphical-session.target
Wants=graphical-session.target

[Service]
Type=simple
ExecStart=$EXEC_PATH
ExecReload=/bin/kill -HUP \$MAINPID
Restart=on-failure
RestartSec=5
TimeoutStopSec=30

# Security settings
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=false
ReadWritePaths=%h/.cloudtolocalllm

# Environment
Environment=HOME=%h
Environment=XDG_CONFIG_HOME=%h/.config

# Logging
StandardOutput=journal
StandardError=journal
SyslogIdentifier=cloudtolocalllm-tray

[Install]
WantedBy=default.target
EOF
    
    print_success "Service file created at $USER_SERVICE_DIR/$SERVICE_FILE"
}

enable_and_start_service() {
    print_status "Enabling and starting service..."
    
    # Reload systemd user daemon
    systemctl --user daemon-reload
    
    # Enable service to start on login
    systemctl --user enable "$SERVICE_NAME"
    
    # Start service now
    systemctl --user start "$SERVICE_NAME"
    
    # Check status
    if systemctl --user is-active --quiet "$SERVICE_NAME"; then
        print_success "Service started successfully!"
    else
        print_error "Service failed to start. Check logs with: journalctl --user -u $SERVICE_NAME"
        exit 1
    fi
}

show_status() {
    print_status "Service status:"
    systemctl --user status "$SERVICE_NAME" --no-pager
    
    echo ""
    print_status "To manage the service:"
    echo "  Start:   systemctl --user start $SERVICE_NAME"
    echo "  Stop:    systemctl --user stop $SERVICE_NAME"
    echo "  Restart: systemctl --user restart $SERVICE_NAME"
    echo "  Status:  systemctl --user status $SERVICE_NAME"
    echo "  Logs:    journalctl --user -u $SERVICE_NAME -f"
}

uninstall_service() {
    print_status "Uninstalling tray service..."
    
    # Stop and disable service
    systemctl --user stop "$SERVICE_NAME" 2>/dev/null || true
    systemctl --user disable "$SERVICE_NAME" 2>/dev/null || true
    
    # Remove service file
    rm -f "$USER_SERVICE_DIR/$SERVICE_FILE"
    
    # Reload daemon
    systemctl --user daemon-reload
    
    print_success "Service uninstalled"
}

show_help() {
    echo "CloudToLocalLLM Tray Service Installation Script"
    echo ""
    echo "Usage: $0 [OPTION]"
    echo ""
    echo "Options:"
    echo "  install     Install and start the tray service (default)"
    echo "  uninstall   Stop and remove the tray service"
    echo "  status      Show service status"
    echo "  help        Show this help message"
    echo ""
    echo "The service will automatically start on user login."
}

# Main execution
case "${1:-install}" in
    install)
        check_dependencies
        install_tray_daemon
        install_user_service
        enable_and_start_service
        show_status
        ;;
    uninstall)
        uninstall_service
        ;;
    status)
        show_status
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        print_error "Unknown option: $1"
        show_help
        exit 1
        ;;
esac
