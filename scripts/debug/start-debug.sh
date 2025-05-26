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

# Function to setup Flutter debugging environment
setup_flutter_debug() {
    echo_color "$BLUE" "Setting up Flutter debugging environment..."

    # Set Flutter path
    export PATH="/flutter/bin:$PATH"

    # Create debug info file
    cat > /usr/share/nginx/html/debug-info.json << EOF
{
  "debug_mode": true,
  "flutter_version": "3.29.1",
  "dart_version": "3.7.0",
  "build_mode": "debug",
  "source_maps": true,
  "debug_endpoints": {
    "devtools_instructions": "/debug-instructions.html",
    "app_url": "https://app.cloudtolocalllm.online",
    "local_devtools": "flutter pub global run devtools --port=8181"
  },
  "theme_debug": {
    "theme_file": "lib/config/theme.dart",
    "expected_colors": {
      "primary": "#a777e3",
      "secondary": "#6e8efb",
      "background": "#181a20"
    }
  }
}
EOF

    # Create debug instructions page
    cat > /usr/share/nginx/html/debug-instructions.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>CloudToLocalLLM Debug Instructions</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; background: #181a20; color: #fff; }
        .container { max-width: 800px; margin: 0 auto; }
        .step { margin: 20px 0; padding: 15px; background: #2a2d35; border-radius: 8px; }
        .code { background: #1a1d23; padding: 10px; border-radius: 4px; font-family: monospace; }
        .highlight { color: #a777e3; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🔧 CloudToLocalLLM Debug Setup</h1>

        <div class="step">
            <h2>1. Setup SSH Tunnel (Local Machine)</h2>
            <div class="code">
                ssh -L 8181:localhost:8181 -L 8182:localhost:8182 cloudllm@cloudtolocalllm.online
            </div>
        </div>

        <div class="step">
            <h2>2. Install Flutter DevTools (Local Machine)</h2>
            <div class="code">
                flutter pub global activate devtools<br>
                flutter pub global run devtools --port=8181
            </div>
        </div>

        <div class="step">
            <h2>3. Debug Theme Issues</h2>
            <p>The app is built in <span class="highlight">debug mode</span> with source maps enabled.</p>
            <p>Expected theme colors:</p>
            <ul>
                <li>Primary: <span style="color: #a777e3;">#a777e3</span></li>
                <li>Secondary: <span style="color: #6e8efb;">#6e8efb</span></li>
                <li>Background: <span style="color: #181a20;">#181a20</span></li>
            </ul>
        </div>

        <div class="step">
            <h2>4. Access Debug App</h2>
            <p>The debug version is running at: <a href="/" style="color: #a777e3;">https://app.cloudtolocalllm.online</a></p>
            <p>Use browser dev tools to inspect theme application.</p>
        </div>

        <div class="step">
            <h2>5. Debug Info</h2>
            <p>Debug configuration: <a href="/debug-info.json" style="color: #a777e3;">/debug-info.json</a></p>
        </div>
    </div>
</body>
</html>
EOF

    echo_color "$GREEN" "Flutter debug environment setup complete"
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

    # Setup Flutter debugging environment
    setup_flutter_debug

    echo_color "$GREEN" "Debug environment ready!"
    echo_color "$BLUE" "Debug instructions: http://localhost:80/debug-instructions.html"
    echo_color "$BLUE" "Debug info: http://localhost:80/debug-info.json"
    echo_color "$BLUE" "Web app: http://localhost:80"

    # Start Nginx (this will run in foreground)
    start_nginx
}

# Run main function
main "$@"
