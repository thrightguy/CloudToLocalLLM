#!/bin/bash

# Core-only deployment for CloudToLocalLLM (without docs and API backend)
set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
VPS_HOST="cloudtolocalllm.online"
VPS_USER="cloudllm"
VPS_PATH="/opt/cloudtolocalllm"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

# Deploy core services only (nginx-proxy, flutter-app)
deploy_core() {
    log_info "Deploying core services to VPS..."
    
    ssh "$VPS_USER@$VPS_HOST" << 'EOF'
        cd /opt/cloudtolocalllm
        
        # Stop existing containers
        if [ -f "docker-compose.yml" ]; then
            echo "Stopping legacy containers..."
            docker compose down 2>/dev/null || docker-compose down 2>/dev/null || true
        fi
        
        # Build Flutter web application
        echo "Building Flutter web application..."
        flutter pub get
        flutter build web --release
        
        # Create simplified docker-compose for core services
        cat > docker-compose.core.yml << 'COMPOSE_EOF'
version: '3.8'

services:
  # Nginx Reverse Proxy
  nginx-proxy:
    image: nginx:1.25-alpine
    container_name: cloudtolocalllm-nginx-proxy
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./config/nginx/nginx-core.conf:/etc/nginx/nginx.conf:ro
      - ./certbot/www:/var/www/certbot:ro
      - ./certbot/live:/etc/letsencrypt/live:ro
      - ./certbot/archive:/etc/letsencrypt/archive:ro
      - ./logs/nginx:/var/log/nginx
    networks:
      - cloudllm-network
    restart: unless-stopped
    depends_on:
      - flutter-app

  # Flutter Web Application Container
  flutter-app:
    image: nginx:1.25-alpine
    container_name: cloudtolocalllm-flutter-app
    volumes:
      - ./build/web:/usr/share/nginx/html:ro
      - ./config/nginx/nginx-flutter-simple.conf:/etc/nginx/nginx.conf:ro
      - ./logs/flutter:/var/log/nginx
    networks:
      - cloudllm-network
    restart: unless-stopped

networks:
  cloudllm-network:
    driver: bridge
    name: cloudtolocalllm-network
COMPOSE_EOF

        # Create simplified nginx configs
        mkdir -p config/nginx logs/nginx logs/static logs/flutter
        
        # Core nginx proxy config
        cat > config/nginx/nginx-core.conf << 'NGINX_EOF'
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log notice;
pid /var/run/nginx.pid;

events {
    worker_connections 1024;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    
    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';
    
    access_log /var/log/nginx/access.log main;
    
    sendfile on;
    keepalive_timeout 65;
    gzip on;
    
    # HTTP to HTTPS redirect
    server {
        listen 80;
        server_name cloudtolocalllm.online app.cloudtolocalllm.online;
        
        location /.well-known/acme-challenge/ {
            root /var/www/certbot;
        }
        
        location / {
            return 301 https://$server_name$request_uri;
        }
    }
    
    # Main website
    server {
        listen 443 ssl http2;
        server_name cloudtolocalllm.online;
        
        ssl_certificate /etc/letsencrypt/live/cloudtolocalllm.online/fullchain.pem;
        ssl_certificate_key /etc/letsencrypt/live/cloudtolocalllm.online/privkey.pem;
        
        location / {
            proxy_pass http://static-site;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }
    }
    
    # Flutter app
    server {
        listen 443 ssl http2;
        server_name app.cloudtolocalllm.online;
        
        ssl_certificate /etc/letsencrypt/live/cloudtolocalllm.online/fullchain.pem;
        ssl_certificate_key /etc/letsencrypt/live/cloudtolocalllm.online/privkey.pem;
        
        location / {
            proxy_pass http://flutter-app;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }
    }
}
NGINX_EOF

        # Simple static site config
        cat > config/nginx/nginx-static-simple.conf << 'STATIC_EOF'
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log notice;
pid /var/run/nginx.pid;

events {
    worker_connections 1024;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    
    sendfile on;
    keepalive_timeout 65;
    gzip on;
    
    server {
        listen 80;
        server_name localhost;
        root /usr/share/nginx/html;
        index index.html;
        
        location / {
            try_files $uri $uri/ /index.html;
        }
    }
}
STATIC_EOF

        # Simple Flutter app config
        cat > config/nginx/nginx-flutter-simple.conf << 'FLUTTER_EOF'
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log notice;
pid /var/run/nginx.pid;

events {
    worker_connections 1024;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    
    sendfile on;
    keepalive_timeout 65;
    gzip on;
    
    server {
        listen 80;
        server_name localhost;
        root /usr/share/nginx/html;
        index index.html;
        
        location / {
            try_files $uri $uri/ /index.html;
        }
        
        location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
            expires 1y;
            add_header Cache-Control "public, immutable";
        }
    }
}
FLUTTER_EOF

        # Deploy core services
        echo "Starting core services..."
        docker compose -f docker-compose.core.yml up -d 2>/dev/null || docker-compose -f docker-compose.core.yml up -d
        
        echo "Core deployment completed"
EOF
    
    log_success "Core services deployed"
}

# Main function
main() {
    log_info "CloudToLocalLLM Core Deployment"
    log_info "==============================="
    
    # Push code first
    cd "$PROJECT_ROOT"
    git add .
    git commit -m "Deploy core multi-container architecture" || log_warning "No changes to commit"
    git push origin master
    
    # Pull on VPS and deploy
    ssh "$VPS_USER@$VPS_HOST" << 'EOF'
        cd /opt/cloudtolocalllm
        git stash push -m "Auto-stash before core deployment $(date)" || true
        git pull origin master
        chmod +x scripts/deploy/*.sh
EOF
    
    deploy_core
    
    # Wait and check status
    sleep 15
    
    log_info "Checking deployment status..."
    ssh "$VPS_USER@$VPS_HOST" << 'EOF'
        cd /opt/cloudtolocalllm
        echo "=== Container Status ==="
        docker compose -f docker-compose.core.yml ps 2>/dev/null || docker-compose -f docker-compose.core.yml ps 2>/dev/null
EOF
    
    log_success "🎉 Core deployment completed!"
    log_info "Test URLs:"
    log_info "  • https://cloudtolocalllm.online"
    log_info "  • https://app.cloudtolocalllm.online"
}

main "$@"
