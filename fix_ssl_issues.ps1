param (
    [Parameter(Mandatory=$true)]
    [string]$VpsHost,
    
    [Parameter(Mandatory=$false)]
    [string]$SshKeyPath = "$env:USERPROFILE\.ssh\id_rsa"
)

# Colors for better readability
function Write-ColorOutput($ForegroundColor) {
    $fc = $host.UI.RawUI.ForegroundColor
    $host.UI.RawUI.ForegroundColor = $ForegroundColor
    if ($args) { Write-Output $args }
    $host.UI.RawUI.ForegroundColor = $fc
}

Write-ColorOutput Green "Fixing SSL issues for CloudToLocalLLM on $VpsHost..."

# Create the script to fix SSL issues
$sslFixScript = @'
#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}Diagnosing and fixing SSL issues...${NC}"

# Check if port 443 is open
echo -e "${YELLOW}Checking if port 443 is open...${NC}"
if ! nc -zv localhost 443 2>/dev/null; then
    echo -e "${RED}Port 443 is not open! Checking container and services...${NC}"
else
    echo -e "${GREEN}Port 443 is open.${NC}"
fi

# Check if Nginx container is running
echo -e "${YELLOW}Checking Nginx container status...${NC}"
if [ "$(docker ps -q -f name=nginx-proxy)" ]; then
    echo -e "${GREEN}Nginx container is running.${NC}"
else
    echo -e "${RED}Nginx container is not running! Starting it...${NC}"
    cd /opt/cloudtolocalllm
    docker-compose up -d nginx-proxy
fi

# Check SSL certificates existence
echo -e "${YELLOW}Checking SSL certificates...${NC}"
CERT_FILES_FOUND=true
CERT_DIR="/etc/letsencrypt/live/cloudtolocalllm.online"
CERT_DIR_ALT="/etc/letsencrypt/live/cloudtolocalllm.online-0001"

if [ -d "$CERT_DIR" ]; then
    echo -e "${GREEN}SSL certificate directory found at $CERT_DIR${NC}"
    ACTIVE_CERT_DIR="$CERT_DIR"
elif [ -d "$CERT_DIR_ALT" ]; then
    echo -e "${GREEN}SSL certificate directory found at $CERT_DIR_ALT${NC}"
    ACTIVE_CERT_DIR="$CERT_DIR_ALT"
else
    echo -e "${RED}SSL certificate directory not found!${NC}"
    CERT_FILES_FOUND=false
fi

if [ "$CERT_FILES_FOUND" = true ]; then
    # Check individual certificate files
    if [ ! -f "$ACTIVE_CERT_DIR/fullchain.pem" ]; then
        echo -e "${RED}fullchain.pem not found!${NC}"
        CERT_FILES_FOUND=false
    fi
    
    if [ ! -f "$ACTIVE_CERT_DIR/privkey.pem" ]; then
        echo -e "${RED}privkey.pem not found!${NC}"
        CERT_FILES_FOUND=false
    fi
fi

# Renew certificates if needed
if [ "$CERT_FILES_FOUND" = false ]; then
    echo -e "${YELLOW}SSL certificates missing or incomplete. Renewing certificates...${NC}"
    # Stop Nginx to free port 80
    docker stop nginx-proxy || true
    
    # Run certbot to get new certificates
    certbot certonly --standalone --force-renewal --non-interactive --agree-tos \
      --email admin@cloudtolocalllm.online \
      -d cloudtolocalllm.online -d www.cloudtolocalllm.online -d api.cloudtolocalllm.online -d users.cloudtolocalllm.online
    
    # Find the certificate directory after renewal
    if [ -d "$CERT_DIR" ]; then
        ACTIVE_CERT_DIR="$CERT_DIR"
    elif [ -d "$CERT_DIR_ALT" ]; then
        ACTIVE_CERT_DIR="$CERT_DIR_ALT"
    else
        echo -e "${RED}Failed to find certificate directory after renewal!${NC}"
        exit 1
    fi
else
    echo -e "${GREEN}All certificate files found.${NC}"
fi

# Create directory for Nginx SSL
mkdir -p /opt/cloudtolocalllm/nginx/ssl

# Copy certificates to Nginx
echo -e "${YELLOW}Copying SSL certificates to Nginx directory...${NC}"
cp "$ACTIVE_CERT_DIR/fullchain.pem" /opt/cloudtolocalllm/nginx/ssl/fullchain.pem
cp "$ACTIVE_CERT_DIR/privkey.pem" /opt/cloudtolocalllm/nginx/ssl/privkey.pem
chmod 644 /opt/cloudtolocalllm/nginx/ssl/fullchain.pem
chmod 600 /opt/cloudtolocalllm/nginx/ssl/privkey.pem

# Create updated Nginx configuration with better SSL
echo -e "${YELLOW}Creating improved Nginx configuration...${NC}"
cat > /opt/cloudtolocalllm/nginx/conf.d/default.conf << 'EOF'
# HTTP redirect to HTTPS
server {
    listen 80;
    listen [::]:80;
    server_name cloudtolocalllm.online www.cloudtolocalllm.online;
    
    location / {
        return 301 https://$host$request_uri;
    }

    # For Let's Encrypt verification
    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }
}

# Main portal
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name cloudtolocalllm.online www.cloudtolocalllm.online;
    
    ssl_certificate /etc/nginx/ssl/fullchain.pem;
    ssl_certificate_key /etc/nginx/ssl/privkey.pem;
    
    # Improved SSL settings
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers off;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384;
    ssl_session_timeout 1d;
    ssl_session_cache shared:SSL:10m;
    ssl_session_tickets off;
    
    # Remove ssl_stapling as it can cause issues if the OCSP server is unreachable
    # ssl_stapling on;
    # ssl_stapling_verify on;
    
    # Security headers
    add_header Strict-Transport-Security "max-age=31536000" always;
    add_header X-Content-Type-Options nosniff;
    add_header X-Frame-Options SAMEORIGIN;
    add_header X-XSS-Protection "1; mode=block";
    add_header Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline' https://cdn.auth0.com https://cdnjs.cloudflare.com; style-src 'self' 'unsafe-inline' https://cdn.jsdelivr.net https://cdnjs.cloudflare.com; img-src 'self' data:; font-src 'self' data: https://cdnjs.cloudflare.com; connect-src 'self' https://api.cloudtolocalllm.online https://*.auth0.com; frame-ancestors 'none';" always;
    
    location / {
        root /usr/share/nginx/html;
        index index.html;
        try_files $uri $uri/ /index.html;
    }
    
    # Auth API endpoint for login
    location /auth/ {
        proxy_pass http://api-service:8080/auth/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }
}
EOF

# Update API subdomain config
cat > /opt/cloudtolocalllm/nginx/conf.d/api.conf << 'EOF'
# API service
server {
    listen 80;
    listen [::]:80;
    server_name api.cloudtolocalllm.online;
    
    location / {
        return 301 https://$host$request_uri;
    }
    
    # For Let's Encrypt verification
    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name api.cloudtolocalllm.online;
    
    ssl_certificate /etc/nginx/ssl/fullchain.pem;
    ssl_certificate_key /etc/nginx/ssl/privkey.pem;
    
    # Improved SSL settings
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers off;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384;
    ssl_session_timeout 1d;
    ssl_session_cache shared:SSL:10m;
    ssl_session_tickets off;
    
    # Security headers
    add_header Strict-Transport-Security "max-age=31536000" always;
    add_header X-Content-Type-Options nosniff;
    add_header X-Frame-Options SAMEORIGIN;
    add_header X-XSS-Protection "1; mode=block";
    
    # CORS headers for API
    add_header 'Access-Control-Allow-Origin' 'https://cloudtolocalllm.online' always;
    add_header 'Access-Control-Allow-Methods' 'GET, POST, OPTIONS' always;
    add_header 'Access-Control-Allow-Headers' 'DNT,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Range,Authorization' always;
    add_header 'Access-Control-Expose-Headers' 'Content-Length,Content-Range' always;
    
    location / {
        proxy_pass http://api-service:8080;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }
    
    # Handle OPTIONS requests for CORS
    location ~ ^/(.*)$ {
        if ($request_method = 'OPTIONS') {
            add_header 'Access-Control-Allow-Origin' 'https://cloudtolocalllm.online' always;
            add_header 'Access-Control-Allow-Methods' 'GET, POST, OPTIONS' always;
            add_header 'Access-Control-Allow-Headers' 'DNT,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Range,Authorization' always;
            add_header 'Access-Control-Max-Age' 1728000;
            add_header 'Content-Type' 'text/plain charset=UTF-8';
            add_header 'Content-Length' 0;
            return 204;
        }
        try_files $uri @proxy;
    }
    
    location @proxy {
        proxy_pass http://api-service:8080;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOF

# Update Users subdomain config
cat > /opt/cloudtolocalllm/nginx/conf.d/users.conf << 'EOF'
# User containers
server {
    listen 80;
    listen [::]:80;
    server_name users.cloudtolocalllm.online ~^(?<username>[^.]+)\.users\.cloudtolocalllm\.online$;
    
    location / {
        return 301 https://$host$request_uri;
    }
    
    # For Let's Encrypt verification
    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name users.cloudtolocalllm.online;
    
    ssl_certificate /etc/nginx/ssl/fullchain.pem;
    ssl_certificate_key /etc/nginx/ssl/privkey.pem;
    
    # Improved SSL settings
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers off;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384;
    ssl_session_timeout 1d;
    ssl_session_cache shared:SSL:10m;
    ssl_session_tickets off;
    
    # Security headers
    add_header Strict-Transport-Security "max-age=31536000" always;
    add_header X-Content-Type-Options nosniff;
    add_header X-Frame-Options SAMEORIGIN;
    add_header X-XSS-Protection "1; mode=block";
    
    location / {
        root /usr/share/nginx/html/users;
        index index.html;
        try_files $uri $uri/ /index.html;
    }
}

# Dynamic user subdomains
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name ~^(?<username>[^.]+)\.users\.cloudtolocalllm\.online$;
    
    ssl_certificate /etc/nginx/ssl/fullchain.pem;
    ssl_certificate_key /etc/nginx/ssl/privkey.pem;
    
    # Improved SSL settings
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers off;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384;
    ssl_session_timeout 1d;
    ssl_session_cache shared:SSL:10m;
    ssl_session_tickets off;
    
    # Security headers
    add_header Strict-Transport-Security "max-age=31536000" always;
    add_header X-Content-Type-Options nosniff;
    add_header X-Frame-Options SAMEORIGIN;
    add_header X-XSS-Protection "1; mode=block";
    
    location / {
        # JWT token verification could be added here with auth_request
        proxy_pass http://user-$username:8080;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
        
        # If user container doesn't exist, show error page
        proxy_intercept_errors on;
        error_page 502 503 504 = @user_not_found;
    }
    
    location @user_not_found {
        root /usr/share/nginx/html/errors;
        try_files /user_not_found.html =404;
    }
}
EOF

# Create ACME challenge directory
mkdir -p /var/www/html/.well-known/acme-challenge

# Restart Nginx container
echo -e "${YELLOW}Restarting Nginx container...${NC}"
cd /opt/cloudtolocalllm
docker-compose restart nginx-proxy

# Check if port 443 is accessible from outside (this won't work fully within the container)
echo -e "${YELLOW}Checking port 443 accessibility...${NC}"
echo -e "${GREEN}To test SSL externally, run: curl -Ivs https://cloudtolocalllm.online${NC}"

# Double-check Nginx config by exec into container
echo -e "${YELLOW}Checking Nginx configuration inside container...${NC}"
docker exec -it nginx-proxy nginx -t || echo -e "${RED}Nginx configuration has errors!${NC}"

# List open ports to verify 443 is listening
echo -e "${YELLOW}Listing open ports...${NC}"
netstat -tuln | grep LISTEN | grep -E '(:80|:443)'

echo -e "${GREEN}SSL configuration has been updated!${NC}"
echo -e "${YELLOW}Main portal:${NC} ${GREEN}https://cloudtolocalllm.online${NC}"
echo -e "${YELLOW}API service:${NC} ${GREEN}https://api.cloudtolocalllm.online${NC}"
echo -e "${YELLOW}Users portal:${NC} ${GREEN}https://users.cloudtolocalllm.online${NC}"

# Check if we can reach the website through HTTPS
if command -v curl &>/dev/null; then
    echo -e "${YELLOW}Testing HTTPS connection...${NC}"
    if curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 --max-time 10 https://cloudtolocalllm.online; then
        echo -e "${GREEN}HTTPS connection successful!${NC}"
    else
        echo -e "${RED}HTTPS connection failed! Please check your firewall settings.${NC}"
        echo -e "${YELLOW}Make sure ports 80 and 443 are open in your VPS firewall/security group.${NC}"
    fi
fi
'@

# Convert to Unix line endings (LF)
$sslFixScript = $sslFixScript -replace "`r`n", "`n"
$sslFixScriptPath = [System.IO.Path]::GetTempFileName()
Set-Content -Path $sslFixScriptPath -Value $sslFixScript -NoNewline -Encoding utf8

# Upload and run the script
Write-ColorOutput Yellow "Uploading and running SSL fix script on VPS..."
scp -i $SshKeyPath $sslFixScriptPath "${VpsHost}:/tmp/fix_ssl_issues.sh"
ssh -i $SshKeyPath $VpsHost "chmod +x /tmp/fix_ssl_issues.sh && sudo /tmp/fix_ssl_issues.sh"

# Clean up
Write-ColorOutput Yellow "Cleaning up temporary files..."
Remove-Item -Force $sslFixScriptPath

Write-ColorOutput Green "SSL configuration has been fixed!"
Write-ColorOutput Yellow "Your site should now be accessible securely at:"
Write-Host "Main portal: https://cloudtolocalllm.online"
Write-Host "API service: https://api.cloudtolocalllm.online" 
Write-Host "Users portal: https://users.cloudtolocalllm.online"

Write-ColorOutput Yellow "If you still have SSL issues, please check:"
Write-Host "1. VPS firewall settings - ensure ports 80 and 443 are open"
Write-Host "2. DNS settings - ensure all domains point to your VPS IP"
Write-Host "3. Certificate validity - visit https://www.ssllabs.com/ssltest/ to test your SSL setup" 