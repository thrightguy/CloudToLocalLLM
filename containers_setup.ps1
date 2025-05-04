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

Write-ColorOutput Green "Setting up containerized environment on $VpsHost..."

# Build the Flutter web app locally
Write-ColorOutput Yellow "Building Flutter web app locally..."
Push-Location .\cloud
flutter clean
flutter pub get
flutter build web --release
Pop-Location

# Create deployment script
$deployScript = @'
#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}Starting containerized deployment...${NC}"

# Stop existing containers
echo -e "${YELLOW}Stopping any existing containers...${NC}"
docker-compose down -v 2>/dev/null || true

# Create project directory structure
echo -e "${YELLOW}Creating project structure...${NC}"
mkdir -p /opt/cloudtolocalllm/{nginx,portal,data,certs}
mkdir -p /opt/cloudtolocalllm/nginx/{conf.d,ssl}
mkdir -p /opt/cloudtolocalllm/data/users

# Extract uploaded portal files
echo -e "${YELLOW}Extracting portal files...${NC}"
rm -rf /opt/cloudtolocalllm/portal/* 2>/dev/null || true
tar -xzf /tmp/portal_app.tar.gz -C /opt/cloudtolocalllm/portal

# Get SSL certificates using Certbot
echo -e "${YELLOW}Getting SSL certificates...${NC}"
apt-get update && apt-get install -y certbot
certbot certonly --standalone --force-renewal --non-interactive --agree-tos \
  --email admin@cloudtolocalllm.online \
  -d cloudtolocalllm.online -d www.cloudtolocalllm.online -d api.cloudtolocalllm.online -d users.cloudtolocalllm.online

# Copy certificates to nginx ssl directory
echo -e "${YELLOW}Copying SSL certificates...${NC}"
cp /etc/letsencrypt/live/cloudtolocalllm.online/fullchain.pem /opt/cloudtolocalllm/nginx/ssl/fullchain.pem
cp /etc/letsencrypt/live/cloudtolocalllm.online/privkey.pem /opt/cloudtolocalllm/nginx/ssl/privkey.pem
chmod 644 /opt/cloudtolocalllm/nginx/ssl/fullchain.pem
chmod 600 /opt/cloudtolocalllm/nginx/ssl/privkey.pem

# Create renewal hook for certificates
echo -e "${YELLOW}Setting up certificate renewal...${NC}"
mkdir -p /etc/letsencrypt/renewal-hooks/post
cat > /etc/letsencrypt/renewal-hooks/post/copy-certs.sh << 'EOF'
#!/bin/bash
cp /etc/letsencrypt/live/cloudtolocalllm.online/fullchain.pem /opt/cloudtolocalllm/nginx/ssl/fullchain.pem
cp /etc/letsencrypt/live/cloudtolocalllm.online/privkey.pem /opt/cloudtolocalllm/nginx/ssl/privkey.pem
chmod 644 /opt/cloudtolocalllm/nginx/ssl/fullchain.pem
chmod 600 /opt/cloudtolocalllm/nginx/ssl/privkey.pem
docker exec nginx-proxy nginx -s reload
EOF
chmod +x /etc/letsencrypt/renewal-hooks/post/copy-certs.sh

# Create cron job for certificate renewal
(crontab -l 2>/dev/null || echo "") | grep -v certbot | { cat; echo "0 3 * * * certbot renew --quiet"; } | crontab -

# Create nginx config files
echo -e "${YELLOW}Creating Nginx configuration...${NC}"

# Create default.conf for main domain
cat > /opt/cloudtolocalllm/nginx/conf.d/default.conf << 'EOF'
# HTTP redirect to HTTPS
server {
    listen 80;
    listen [::]:80;
    server_name cloudtolocalllm.online www.cloudtolocalllm.online;
    
    location / {
        return 301 https://$host$request_uri;
    }
}

# Main portal
server {
    listen 443 ssl;
    listen [::]:443 ssl;
    server_name cloudtolocalllm.online www.cloudtolocalllm.online;
    
    ssl_certificate /etc/nginx/ssl/fullchain.pem;
    ssl_certificate_key /etc/nginx/ssl/privkey.pem;
    
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-SHA384;
    ssl_session_timeout 10m;
    ssl_session_cache shared:SSL:10m;
    ssl_session_tickets off;
    
    location / {
        root /usr/share/nginx/html;
        index index.html;
        try_files $uri $uri/ /index.html;
    }
}
EOF

# Create api.conf for API subdomain
cat > /opt/cloudtolocalllm/nginx/conf.d/api.conf << 'EOF'
# API service
server {
    listen 80;
    listen [::]:80;
    server_name api.cloudtolocalllm.online;
    
    location / {
        return 301 https://$host$request_uri;
    }
}

server {
    listen 443 ssl;
    listen [::]:443 ssl;
    server_name api.cloudtolocalllm.online;
    
    ssl_certificate /etc/nginx/ssl/fullchain.pem;
    ssl_certificate_key /etc/nginx/ssl/privkey.pem;
    
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-SHA384;
    ssl_session_timeout 10m;
    ssl_session_cache shared:SSL:10m;
    ssl_session_tickets off;
    
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
}
EOF

# Create users.conf for user subdomains
cat > /opt/cloudtolocalllm/nginx/conf.d/users.conf << 'EOF'
# User containers
server {
    listen 80;
    listen [::]:80;
    server_name users.cloudtolocalllm.online ~^(?<username>[^.]+)\.users\.cloudtolocalllm\.online$;
    
    location / {
        return 301 https://$host$request_uri;
    }
}

server {
    listen 443 ssl;
    listen [::]:443 ssl;
    server_name users.cloudtolocalllm.online;
    
    ssl_certificate /etc/nginx/ssl/fullchain.pem;
    ssl_certificate_key /etc/nginx/ssl/privkey.pem;
    
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-SHA384;
    ssl_session_timeout 10m;
    ssl_session_cache shared:SSL:10m;
    ssl_session_tickets off;
    
    location / {
        root /usr/share/nginx/html/users;
        index index.html;
        try_files $uri $uri/ /index.html;
    }
}

# Dynamic user subdomains
server {
    listen 443 ssl;
    listen [::]:443 ssl;
    server_name ~^(?<username>[^.]+)\.users\.cloudtolocalllm\.online$;
    
    ssl_certificate /etc/nginx/ssl/fullchain.pem;
    ssl_certificate_key /etc/nginx/ssl/privkey.pem;
    
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-SHA384;
    ssl_session_timeout 10m;
    ssl_session_cache shared:SSL:10m;
    ssl_session_tickets off;
    
    location / {
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

# Create docker-compose.yml file
echo -e "${YELLOW}Creating Docker Compose file...${NC}"
cat > /opt/cloudtolocalllm/docker-compose.yml << 'EOF'
version: '3.8'

services:
  # Main nginx reverse proxy
  nginx-proxy:
    container_name: nginx-proxy
    image: nginx:alpine
    restart: always
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx/conf.d:/etc/nginx/conf.d
      - ./nginx/ssl:/etc/nginx/ssl
      - ./portal:/usr/share/nginx/html
      - ./data/users:/usr/share/nginx/html/users
    networks:
      - proxy-network
      - user-network
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"

  # API service container
  api-service:
    container_name: api-service
    image: node:18-alpine
    restart: always
    working_dir: /app
    volumes:
      - ./data/api:/app
    environment:
      - NODE_ENV=production
      - PORT=8080
    command: sh -c "test -f /app/server.js && node /app/server.js || echo 'API service not yet configured'"
    networks:
      - proxy-network
    depends_on:
      - db-service
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"

  # Database service
  db-service:
    container_name: db-service
    image: postgres:14-alpine
    restart: always
    environment:
      - POSTGRES_PASSWORD=securepassword
      - POSTGRES_DB=cloudtolocalllm
    volumes:
      - ./data/db:/var/lib/postgresql/data
    networks:
      - proxy-network
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"

  # User management service
  user-manager:
    container_name: user-manager
    image: node:18-alpine
    restart: always
    working_dir: /app
    volumes:
      - ./data/user-manager:/app
      - /var/run/docker.sock:/var/run/docker.sock
    environment:
      - NODE_ENV=production
      - DATABASE_URL=postgres://postgres:securepassword@db-service:5432/cloudtolocalllm
    command: sh -c "test -f /app/server.js && node /app/server.js || echo 'User manager not yet configured'"
    networks:
      - proxy-network
      - user-network
    depends_on:
      - db-service
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"

networks:
  proxy-network:
    driver: bridge
  user-network:
    driver: bridge
EOF

# Create simple API service placeholder
echo -e "${YELLOW}Creating API service placeholder...${NC}"
mkdir -p /opt/cloudtolocalllm/data/api
cat > /opt/cloudtolocalllm/data/api/server.js << 'EOF'
const http = require('http');

const server = http.createServer((req, res) => {
  res.writeHead(200, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify({
    status: 'online',
    message: 'CloudToLocalLLM API is running',
    timestamp: new Date().toISOString()
  }));
});

const PORT = process.env.PORT || 8080;
server.listen(PORT, () => {
  console.log(`API server running on port ${PORT}`);
});
EOF

# Create user manager placeholder
echo -e "${YELLOW}Creating user manager placeholder...${NC}"
mkdir -p /opt/cloudtolocalllm/data/user-manager
cat > /opt/cloudtolocalllm/data/user-manager/server.js << 'EOF'
const http = require('http');

// This would be replaced with actual Docker API integration
// to dynamically create and manage user containers
const server = http.createServer((req, res) => {
  res.writeHead(200, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify({
    status: 'online',
    message: 'User manager service is running',
    timestamp: new Date().toISOString()
  }));
});

const PORT = process.env.PORT || 8081;
server.listen(PORT, () => {
  console.log(`User manager running on port ${PORT}`);
});
EOF

# Create error pages directory
echo -e "${YELLOW}Creating error pages...${NC}"
mkdir -p /opt/cloudtolocalllm/portal/errors
cat > /opt/cloudtolocalllm/portal/errors/user_not_found.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>User Not Found - CloudToLocalLLM</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            line-height: 1.6;
            max-width: 800px;
            margin: 0 auto;
            padding: 20px;
            text-align: center;
        }
        h1 {
            color: #d9534f;
        }
        .container {
            border: 1px solid #ddd;
            padding: 20px;
            border-radius: 5px;
            margin-top: 20px;
            background-color: #f9f9f9;
        }
        .btn {
            display: inline-block;
            background-color: #0066cc;
            color: white;
            padding: 10px 20px;
            text-decoration: none;
            border-radius: 5px;
            margin-top: 20px;
        }
    </style>
</head>
<body>
    <h1>User Environment Not Found</h1>
    <div class="container">
        <p>The user environment you are trying to access does not exist or is not currently running.</p>
        <p>Please check the username or contact support if you believe this is an error.</p>
        <a href="https://cloudtolocalllm.online" class="btn">Return to Portal</a>
    </div>
</body>
</html>
EOF

# Start the containers
echo -e "${YELLOW}Starting Docker containers...${NC}"
cd /opt/cloudtolocalllm
docker-compose up -d

# Install docker-compose-wait utility for services that need to wait for dependencies
echo -e "${YELLOW}Installing docker-compose-wait utility...${NC}"
apt-get install -y wget
wget -O /usr/local/bin/wait-for-it https://raw.githubusercontent.com/vishnubob/wait-for-it/master/wait-for-it.sh
chmod +x /usr/local/bin/wait-for-it

echo -e "${GREEN}Containerized deployment completed!${NC}"
echo -e "${YELLOW}Main portal:${NC} ${GREEN}https://cloudtolocalllm.online${NC}"
echo -e "${YELLOW}API service:${NC} ${GREEN}https://api.cloudtolocalllm.online${NC}"
echo -e "${YELLOW}Users portal:${NC} ${GREEN}https://users.cloudtolocalllm.online${NC}"
'@

# Convert to Unix line endings (LF)
$deployScript = $deployScript -replace "`r`n", "`n"
$deployScriptPath = [System.IO.Path]::GetTempFileName()
Set-Content -Path $deployScriptPath -Value $deployScript -NoNewline -Encoding utf8

# Create archive of web build
Write-ColorOutput Yellow "Creating archive of web build..."
$archivePath = [System.IO.Path]::GetTempFileName()
Push-Location .\cloud\build\web
tar -czf $archivePath .
Pop-Location

# Upload archive to server
Write-ColorOutput Yellow "Uploading portal files to VPS..."
scp -i $SshKeyPath $archivePath "${VpsHost}:/tmp/portal_app.tar.gz"

# Upload and run deployment script
Write-ColorOutput Yellow "Running deployment script on VPS..."
scp -i $SshKeyPath $deployScriptPath "${VpsHost}:/tmp/containers_setup.sh"
ssh -i $SshKeyPath $VpsHost "chmod +x /tmp/containers_setup.sh && sudo /tmp/containers_setup.sh"

# Clean up
Write-ColorOutput Yellow "Cleaning up temporary files..."
Remove-Item -Force $deployScriptPath
Remove-Item -Force $archivePath

Write-ColorOutput Green "Containerized environment setup completed!"
Write-ColorOutput Yellow "Your services are now accessible at:"
Write-Host "Main portal: https://cloudtolocalllm.online"
Write-Host "API service: https://api.cloudtolocalllm.online"
Write-Host "Users portal: https://users.cloudtolocalllm.online" 