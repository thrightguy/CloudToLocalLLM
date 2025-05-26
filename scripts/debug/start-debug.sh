#!/bin/bash

# CloudToLocalLLM Debug Startup Script
# Starts Nginx and Flutter DevTools for remote debugging

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
echo_color() {
    echo -e "${1}${2}${NC}"
}

# Function to start Flutter DevTools
start_devtools() {
    echo_color "$BLUE" "Starting Flutter DevTools..."

    # Set Flutter path
    export PATH="/flutter/bin:$PATH"

    # Install DevTools globally first
    echo_color "$BLUE" "Installing DevTools..."
    flutter pub global activate devtools

    # Start DevTools daemon in background
    echo_color "$BLUE" "Starting DevTools server..."
    nohup flutter pub global run devtools --port=8181 --host=0.0.0.0 > /var/log/devtools.log 2>&1 &
    DEVTOOLS_PID=$!

    echo_color "$GREEN" "Flutter DevTools started on port 8181 (PID: $DEVTOOLS_PID)"
    echo $DEVTOOLS_PID > /var/run/devtools.pid
}

# Function to start VM Service proxy
start_vm_service() {
    echo_color "$BLUE" "Starting VM Service proxy..."

    # Create a simple proxy for VM service
    cat > /tmp/vm-service-proxy.js << 'EOF'
const http = require('http');
const httpProxy = require('http-proxy');

const proxy = httpProxy.createProxyServer({});

const server = http.createServer((req, res) => {
    // Enable CORS
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS, PUT, DELETE');
    res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');

    if (req.method === 'OPTIONS') {
        res.writeHead(200);
        res.end();
        return;
    }

    // Proxy to Flutter VM service
    proxy.web(req, res, {
        target: 'http://localhost:8182',
        changeOrigin: true
    });
});

server.listen(3334, '0.0.0.0', () => {
    console.log('VM Service proxy listening on port 3334');
});
EOF

    # Start VM service proxy (if Node.js is available)
    if command -v node >/dev/null 2>&1; then
        nohup node /tmp/vm-service-proxy.js > /var/log/vm-service.log 2>&1 &
        VM_SERVICE_PID=$!
        echo_color "$GREEN" "VM Service proxy started on port 3334 (PID: $VM_SERVICE_PID)"
        echo $VM_SERVICE_PID > /var/run/vm-service.pid
    else
        echo_color "$YELLOW" "Node.js not available, skipping VM Service proxy"
    fi
}

# Function to setup debugging environment
setup_debug_env() {
    echo_color "$BLUE" "Setting up debug environment..."

    # Create log directory
    mkdir -p /var/log

    # Set permissions
    chown -R nginx:nginx /var/log

    # Create Flutter config directory
    mkdir -p /home/nginx/.config/flutter
    chown -R nginx:nginx /home/nginx/.config

    echo_color "$GREEN" "Debug environment setup complete"
}

# Function to start Nginx
start_nginx() {
    echo_color "$BLUE" "Starting Nginx..."

    # Test Nginx configuration
    nginx -t

    if [ $? -eq 0 ]; then
        # Start Nginx in foreground
        exec nginx -g "daemon off;"
    else
        echo_color "$RED" "Nginx configuration test failed"
        exit 1
    fi
}

# Function to cleanup on exit
cleanup() {
    echo_color "$YELLOW" "Cleaning up debug processes..."

    if [ -f /var/run/devtools.pid ]; then
        DEVTOOLS_PID=$(cat /var/run/devtools.pid)
        kill $DEVTOOLS_PID 2>/dev/null || true
        rm -f /var/run/devtools.pid
    fi

    if [ -f /var/run/vm-service.pid ]; then
        VM_SERVICE_PID=$(cat /var/run/vm-service.pid)
        kill $VM_SERVICE_PID 2>/dev/null || true
        rm -f /var/run/vm-service.pid
    fi

    echo_color "$GREEN" "Cleanup complete"
}

# Set trap for cleanup
trap cleanup EXIT INT TERM

# Main execution
main() {
    echo_color "$BLUE" "CloudToLocalLLM Debug Mode Starting..."
    echo_color "$BLUE" "======================================="

    # Setup environment
    setup_debug_env

    # Start debugging services
    start_devtools
    start_vm_service

    # Wait a moment for services to start
    sleep 3

    echo_color "$GREEN" "Debug services started successfully!"
    echo_color "$BLUE" "DevTools available at: http://localhost:8181"
    echo_color "$BLUE" "VM Service proxy at: http://localhost:3334"
    echo_color "$BLUE" "Web app at: http://localhost:80"

    # Start Nginx (this will run in foreground)
    start_nginx
}

# Run main function
main "$@"
