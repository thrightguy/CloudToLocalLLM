# VPS Deployment Guide for CloudToLocalLLM

This guide explains how to deploy CloudToLocalLLM to a VPS (Virtual Private Server).

## Quick Setup

The easiest way to deploy CloudToLocalLLM to a VPS is to use the provided deployment script:

```bash
# From your local machine
cd cloud
./deploy_to_vps.sh user@your-vps-ip
```

This script will:
1. Create a CPU-friendly version of docker-compose.yml
2. Configure nginx as a reverse proxy
3. Set up firewall rules
4. Install all required dependencies
5. Start the application

## Manual Deployment

If you prefer to deploy manually, follow these steps:

### 1. Prerequisites

- A VPS with at least 2GB RAM running Ubuntu/Debian
- Domain name pointing to your VPS IP (optional)
- SSH access to your VPS

### 2. Server Setup

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install required packages
sudo apt install -y docker.io docker-compose nginx curl git

# Start and enable Docker
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker $USER
```

### 3. Application Setup

```bash
# Clone the repository
cd /var/www/html
git clone https://github.com/yourusername/CloudToLocalLLM.git .

# Create CPU-only docker-compose.yml
# (Remove GPU requirements and change port to 8080)
```

### 4. Nginx Configuration

Create a configuration at `/etc/nginx/sites-available/cloudtolocalllm.conf`:

```nginx
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name your-domain.com www.your-domain.com;
    
    root /var/www/html;
    index index.html;

    location / {
        try_files $uri $uri/ =404;
        autoindex off;
    }

    location /cloud/ {
        proxy_pass http://localhost:8080/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

Apply the configuration:
```bash
sudo rm -f /etc/nginx/sites-enabled/default
sudo ln -s /etc/nginx/sites-available/cloudtolocalllm.conf /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx
```

### 5. Firewall Configuration

```bash
# For Ubuntu/Debian with UFW
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp  # If using SSL

# For RHEL/CentOS with FirewallD
sudo firewall-cmd --permanent --add-port=80/tcp
sudo firewall-cmd --permanent --add-port=443/tcp  # If using SSL
sudo firewall-cmd --reload
```

### 6. Start the Application

```bash
cd /var/www/html
sudo docker-compose up -d
```

## Troubleshooting

If you experience connectivity issues:

1. Check if nginx is running: `systemctl status nginx`
2. Check if Docker containers are running: `docker ps`
3. Verify port availability: `netstat -tulpn | grep ':80\|:8080'`
4. Check nginx error logs: `sudo tail -f /var/log/nginx/error.log`
5. Check Docker logs: `docker-compose logs`

## SSL Configuration (Optional)

To secure your site with HTTPS:

```bash
# Install Certbot
sudo apt install -y certbot python3-certbot-nginx

# Obtain and install certificate
sudo certbot --nginx -d your-domain.com -d www.your-domain.com
```

## Updating the Application

To update your application:

```bash
cd /var/www/html
git pull
sudo docker-compose down
sudo docker-compose up -d
``` 