#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# --- Certbot Symlink Structure Cleanup ---
DOMAIN="cloudtolocalllm.online"
LIVE_DIR="/etc/letsencrypt/live/$DOMAIN"
ARCHIVE_DIR="/etc/letsencrypt/archive/$DOMAIN"
RENEWAL_CONF="/etc/letsencrypt/renewal/$DOMAIN.conf"

if [ -d "$LIVE_DIR" ] && [ ! -L "$LIVE_DIR/cert.pem" ]; then
  echo -e "${RED}Detected broken cert.pem (not a symlink) in $LIVE_DIR. Backing up and removing broken certbot data...${NC}"
  BACKUP_SUFFIX="backup_$(date +%Y%m%d_%H%M%S)"
  mv "$LIVE_DIR" "${LIVE_DIR}_$BACKUP_SUFFIX" || true
  if [ -d "$ARCHIVE_DIR" ]; then
    mv "$ARCHIVE_DIR" "${ARCHIVE_DIR}_$BACKUP_SUFFIX" || true
  fi
  if [ -f "$RENEWAL_CONF" ]; then
    mv "$RENEWAL_CONF" "${RENEWAL_CONF}_$BACKUP_SUFFIX" || true
  fi
  echo -e "${GREEN}Backed up and removed broken certbot data. Will proceed to obtain a fresh certificate.${NC}"
fi

echo -e "${YELLOW}Starting SSL fix...${NC}"

# Install Certbot
echo -e "${YELLOW}Installing Certbot...${NC}"
apt-get update
apt-get install -y certbot

# Stop any services using port 80
echo -e "${YELLOW}Stopping services on port 80...${NC}"
systemctl stop nginx || true
docker stop $(docker ps -q --filter publish=80) || true

# Get SSL certificate using standalone mode
echo -e "${YELLOW}Getting SSL certificate with Certbot standalone...${NC}"
certbot certonly --standalone --force-renewal --non-interactive --agree-tos --email admin@cloudtolocalllm.online \
  -d cloudtolocalllm.online -d www.cloudtolocalllm.online

# Check if certificate was created
if [ ! -d "/etc/letsencrypt/live/cloudtolocalllm.online" ]; then
    echo -e "${RED}Failed to obtain SSL certificate. Check errors above.${NC}"
    exit 1
fi

# Set up Nginx configuration with SSL
echo -e "${YELLOW}Setting up Nginx with SSL...${NC}"

# Create directory structure
mkdir -p /var/www/html/ssl

# Copy certificates to nginx ssl directory
echo -e "${YELLOW}Copying SSL certificates...${NC}"
cp /etc/letsencrypt/live/cloudtolocalllm.online/fullchain.pem /var/www/html/ssl/fullchain.pem
cp /etc/letsencrypt/live/cloudtolocalllm.online/privkey.pem /var/www/html/ssl/privkey.pem

# Set correct permissions
chmod 644 /var/www/html/ssl/fullchain.pem
chmod 600 /var/www/html/ssl/privkey.pem

# Create Docker Compose file with SSL configuration
cat > /var/www/html/docker-compose.yml << 'EOF'
version: '3'

services:
  webserver:
    container_name: webserver
    image: nginx:alpine
    restart: always
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./web:/usr/share/nginx/html
      - ./nginx:/etc/nginx/conf.d
      - ./ssl:/etc/nginx/ssl
EOF

# Create directories if they don't exist
mkdir -p /var/www/html/web /var/www/html/nginx

# Create a simple website
cat > /var/www/html/web/index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>CloudToLocalLLM</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            line-height: 1.6;
            max-width: 800px;
            margin: 0 auto;
            padding: 20px;
        }
        h1 {
            color: #0066cc;
        }
        .container {
            border: 1px solid #ddd;
            padding: 20px;
            border-radius: 5px;
            margin-top: 20px;
        }
    </style>
</head>
<body>
    <h1>CloudToLocalLLM</h1>
    <div class="container">
        <h2>Welcome to CloudToLocalLLM</h2>
        <p>If you can see this page, the SSL setup is working correctly.</p>
        <p>Current time: <script>document.write(new Date().toLocaleString());</script></p>
    </div>
</body>
</html>
EOF

# Create Nginx configuration with SSL
cat > /var/www/html/nginx/default.conf << 'EOF'
server {
    listen 80;
    listen [::]:80;
    server_name cloudtolocalllm.online www.cloudtolocalllm.online;
    
    location / {
        return 301 https://$host$request_uri;
    }
}

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
    }
}
EOF

# Start the web server with SSL
echo -e "${YELLOW}Starting web server with SSL...${NC}"
cd /var/www/html
docker-compose down || true
docker-compose up -d

# Create a certbot renewal hook
echo -e "${YELLOW}Creating Certbot renewal hook...${NC}"
mkdir -p /etc/letsencrypt/renewal-hooks/post
cat > /etc/letsencrypt/renewal-hooks/post/copy-certs.sh << 'EOF'
#!/bin/bash
cp /etc/letsencrypt/live/cloudtolocalllm.online/fullchain.pem /var/www/html/ssl/fullchain.pem
cp /etc/letsencrypt/live/cloudtolocalllm.online/privkey.pem /var/www/html/ssl/privkey.pem
chmod 644 /var/www/html/ssl/fullchain.pem
chmod 600 /var/www/html/ssl/privkey.pem
docker exec webserver nginx -s reload
EOF
chmod +x /etc/letsencrypt/renewal-hooks/post/copy-certs.sh

# Create a cronjob for certbot renewal
echo -e "${YELLOW}Setting up automatic certificate renewal...${NC}"
(crontab -l 2>/dev/null || echo "") | grep -v certbot | { cat; echo "0 3 * * * certbot renew --quiet"; } | crontab -

echo -e "${GREEN}SSL setup completed successfully!${NC}"
echo -e "${YELLOW}Your website should now be accessible via HTTPS:${NC}"
echo -e "${GREEN}https://cloudtolocalllm.online${NC}"
echo -e "${GREEN}https://www.cloudtolocalllm.online${NC}" 