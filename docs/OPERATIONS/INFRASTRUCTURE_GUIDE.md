# CloudToLocalLLM Infrastructure Guide

## 📋 Overview

This comprehensive guide covers all infrastructure, operations, and maintenance aspects of CloudToLocalLLM deployment. It consolidates environment strategy, maintenance procedures, and server setup into a single authoritative reference.

---

## 🌍 **Environment Strategy**

### **Development Environment**
- **Local Development**: Flutter desktop application with hot reload
- **Testing Environment**: Isolated testing with mock services
- **Staging Environment**: Production-like environment for validation
- **Production Environment**: Live deployment with full monitoring

### **Environment Configuration**
```bash
# Development
export CLOUDTOLOCALLLM_ENV=development
export DEBUG_MODE=true
export LOG_LEVEL=debug

# Staging
export CLOUDTOLOCALLLM_ENV=staging
export DEBUG_MODE=false
export LOG_LEVEL=info

# Production
export CLOUDTOLOCALLLM_ENV=production
export DEBUG_MODE=false
export LOG_LEVEL=warn
```

### **Configuration Management**
```yaml
# config/environments.yml
development:
  api_url: http://localhost:3000
  auth_domain: dev-auth.cloudtolocalllm.online
  ssl_enabled: false
  
staging:
  api_url: https://staging-api.cloudtolocalllm.online
  auth_domain: staging-auth.cloudtolocalllm.online
  ssl_enabled: true
  
production:
  api_url: https://api.cloudtolocalllm.online
  auth_domain: auth.cloudtolocalllm.online
  ssl_enabled: true
```

---

## 🔧 **Maintenance Scripts**

### **System Maintenance**

#### **Daily Maintenance Script**
```bash
#!/bin/bash
# scripts/maintenance/daily_maintenance.sh

# Log rotation
sudo logrotate /etc/logrotate.d/cloudtolocalllm

# Database cleanup
docker compose exec api-backend npm run db:cleanup

# Cache cleanup
docker compose exec webapp nginx -s reload

# Health checks
./scripts/health_check.sh

# Backup verification
./scripts/verify_backups.sh
```

#### **Weekly Maintenance Script**
```bash
#!/bin/bash
# scripts/maintenance/weekly_maintenance.sh

# System updates
sudo apt update && sudo apt upgrade -y

# Docker image cleanup
docker system prune -f

# SSL certificate check
./scripts/check_ssl_expiry.sh

# Performance analysis
./scripts/performance_report.sh

# Security scan
./scripts/security_scan.sh
```

#### **Monthly Maintenance Script**
```bash
#!/bin/bash
# scripts/maintenance/monthly_maintenance.sh

# Full system backup
./scripts/backup/full_backup.sh

# Security updates
sudo unattended-upgrades

# Disk space analysis
df -h > /var/log/cloudtolocalllm/disk_usage_$(date +%Y%m%d).log

# Performance optimization
./scripts/optimize_performance.sh

# Documentation updates
./scripts/update_documentation.sh
```

### **Database Maintenance**
```bash
#!/bin/bash
# scripts/maintenance/database_maintenance.sh

# Database optimization
docker compose exec postgres psql -U cloudtolocalllm -c "VACUUM ANALYZE;"

# Index rebuilding
docker compose exec postgres psql -U cloudtolocalllm -c "REINDEX DATABASE cloudtolocalllm;"

# Statistics update
docker compose exec postgres psql -U cloudtolocalllm -c "ANALYZE;"

# Backup database
pg_dump -h localhost -U cloudtolocalllm cloudtolocalllm > backup_$(date +%Y%m%d).sql
```

### **Container Maintenance**
```bash
#!/bin/bash
# scripts/maintenance/container_maintenance.sh

# Update containers
docker compose pull
docker compose up -d --force-recreate

# Clean unused images
docker image prune -f

# Clean unused volumes
docker volume prune -f

# Clean unused networks
docker network prune -f

# Container health check
docker compose ps
```

---

## 📧 **Email Server Setup**

### **Postfix Configuration**
```bash
# Install Postfix
sudo apt install postfix mailutils

# Configure main.cf
sudo tee /etc/postfix/main.cf << 'EOF'
myhostname = mail.cloudtolocalllm.online
mydomain = cloudtolocalllm.online
myorigin = $mydomain
inet_interfaces = all
mydestination = $myhostname, localhost.$mydomain, localhost, $mydomain
relayhost = 
mynetworks = 127.0.0.0/8 [::ffff:127.0.0.0]/104 [::1]/128
mailbox_size_limit = 0
recipient_delimiter = +
inet_protocols = ipv4
EOF

# Restart Postfix
sudo systemctl restart postfix
sudo systemctl enable postfix
```

### **DKIM Setup**
```bash
# Install OpenDKIM
sudo apt install opendkim opendkim-tools

# Generate DKIM keys
sudo mkdir -p /etc/opendkim/keys/cloudtolocalllm.online
sudo opendkim-genkey -t -s mail -d cloudtolocalllm.online -D /etc/opendkim/keys/cloudtolocalllm.online

# Configure OpenDKIM
sudo tee /etc/opendkim.conf << 'EOF'
Domain                  cloudtolocalllm.online
KeyFile                 /etc/opendkim/keys/cloudtolocalllm.online/mail.private
Selector                mail
Socket                  inet:8891@localhost
EOF

# Start OpenDKIM
sudo systemctl restart opendkim
sudo systemctl enable opendkim
```

### **DMARC Configuration**
```bash
# Create DMARC DNS record
# _dmarc.cloudtolocalllm.online TXT "v=DMARC1; p=quarantine; rua=mailto:dmarc@cloudtolocalllm.online"

# SPF DNS record
# cloudtolocalllm.online TXT "v=spf1 mx a ip4:YOUR_SERVER_IP ~all"

# DKIM DNS record (from generated key)
cat /etc/opendkim/keys/cloudtolocalllm.online/mail.txt
```

---

## 🔒 **SSL Setup**

### **Let's Encrypt Wildcard Certificate**
```bash
#!/bin/bash
# scripts/ssl/setup_wildcard_ssl.sh

DOMAIN="cloudtolocalllm.online"
EMAIL="admin@cloudtolocalllm.online"

# Install Certbot
sudo apt install certbot

# Request wildcard certificate
sudo certbot certonly \
  --manual \
  --preferred-challenges dns \
  --email $EMAIL \
  --server https://acme-v02.api.letsencrypt.org/directory \
  --agree-tos \
  -d $DOMAIN \
  -d "*.$DOMAIN"

# Setup auto-renewal
sudo crontab -e
# Add: 0 12 * * * /usr/bin/certbot renew --quiet
```

### **SSL Certificate Management**
```bash
#!/bin/bash
# scripts/ssl/manage_certificates.sh

# Check certificate expiry
check_expiry() {
    openssl x509 -in /etc/letsencrypt/live/cloudtolocalllm.online/fullchain.pem -noout -dates
}

# Renew certificates
renew_certificates() {
    sudo certbot renew --quiet
    docker compose restart nginx-proxy
}

# Verify SSL configuration
verify_ssl() {
    curl -I https://cloudtolocalllm.online
    curl -I https://app.cloudtolocalllm.online
}

# Main execution
check_expiry
renew_certificates
verify_ssl
```

### **Nginx SSL Configuration**
```nginx
# /etc/nginx/sites-available/cloudtolocalllm.conf
server {
    listen 443 ssl http2;
    server_name cloudtolocalllm.online *.cloudtolocalllm.online;

    ssl_certificate /etc/letsencrypt/live/cloudtolocalllm.online/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/cloudtolocalllm.online/privkey.pem;
    
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512;
    ssl_prefer_server_ciphers off;
    
    add_header Strict-Transport-Security "max-age=63072000" always;
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;
    
    location / {
        proxy_pass http://localhost:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

---

## 🖥️ **VPS Setup**

### **Initial Server Configuration**
```bash
#!/bin/bash
# scripts/vps/initial_setup.sh

# Update system
sudo apt update && sudo apt upgrade -y

# Install essential packages
sudo apt install -y curl wget git vim htop ufw fail2ban

# Configure firewall
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw allow http
sudo ufw allow https
sudo ufw --force enable

# Configure fail2ban
sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
sudo systemctl enable fail2ban
sudo systemctl start fail2ban
```

### **Docker Installation**
```bash
#!/bin/bash
# scripts/vps/install_docker.sh

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Add user to docker group
sudo usermod -aG docker $USER

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Start Docker service
sudo systemctl enable docker
sudo systemctl start docker
```

### **Application Deployment**
```bash
#!/bin/bash
# scripts/vps/deploy_application.sh

# Clone repository
git clone https://github.com/imrightguy/CloudToLocalLLM.git /opt/cloudtolocalllm
cd /opt/cloudtolocalllm

# Set permissions
sudo chown -R cloudllm:cloudllm /opt/cloudtolocalllm

# Build and start services
docker compose build
docker compose up -d

# Verify deployment
docker compose ps
curl -I https://cloudtolocalllm.online
```

---

## 📊 **Monitoring and Logging**

### **System Monitoring**
```bash
#!/bin/bash
# scripts/monitoring/system_monitor.sh

# CPU and Memory usage
top -bn1 | grep "Cpu(s)" | awk '{print $2}' | awk -F'%' '{print $1}'
free -m | awk 'NR==2{printf "Memory Usage: %s/%sMB (%.2f%%)\n", $3,$2,$3*100/$2 }'

# Disk usage
df -h | awk '$NF=="/"{printf "Disk Usage: %d/%dGB (%s)\n", $3,$2,$5}'

# Network connections
netstat -tuln | grep LISTEN

# Docker container status
docker compose ps
```

### **Application Monitoring**
```bash
#!/bin/bash
# scripts/monitoring/app_monitor.sh

# Check application health
curl -f https://api.cloudtolocalllm.online/health || echo "API health check failed"

# Check database connectivity
docker compose exec postgres pg_isready -U cloudtolocalllm

# Check Redis connectivity
docker compose exec redis redis-cli ping

# Check log errors
tail -n 100 /var/log/cloudtolocalllm/app.log | grep ERROR
```

### **Log Management**
```bash
#!/bin/bash
# scripts/logging/log_management.sh

# Rotate logs
sudo logrotate -f /etc/logrotate.d/cloudtolocalllm

# Compress old logs
find /var/log/cloudtolocalllm -name "*.log" -mtime +7 -exec gzip {} \;

# Clean old compressed logs
find /var/log/cloudtolocalllm -name "*.gz" -mtime +30 -delete

# Archive logs
tar -czf /backup/logs/logs_$(date +%Y%m%d).tar.gz /var/log/cloudtolocalllm/*.log
```

---

## 🔄 **Backup and Recovery**

### **Automated Backup Script**
```bash
#!/bin/bash
# scripts/backup/automated_backup.sh

BACKUP_DIR="/backup/cloudtolocalllm"
DATE=$(date +%Y%m%d_%H%M%S)

# Create backup directory
mkdir -p $BACKUP_DIR/$DATE

# Backup database
docker compose exec postgres pg_dump -U cloudtolocalllm cloudtolocalllm > $BACKUP_DIR/$DATE/database.sql

# Backup application data
tar -czf $BACKUP_DIR/$DATE/app_data.tar.gz /opt/cloudtolocalllm

# Backup SSL certificates
tar -czf $BACKUP_DIR/$DATE/ssl_certs.tar.gz /etc/letsencrypt

# Clean old backups (keep 30 days)
find $BACKUP_DIR -type d -mtime +30 -exec rm -rf {} \;
```

### **Recovery Procedures**
```bash
#!/bin/bash
# scripts/recovery/restore_backup.sh

BACKUP_DATE=$1
BACKUP_DIR="/backup/cloudtolocalllm/$BACKUP_DATE"

# Stop services
docker compose down

# Restore database
docker compose exec postgres psql -U cloudtolocalllm -c "DROP DATABASE IF EXISTS cloudtolocalllm;"
docker compose exec postgres psql -U cloudtolocalllm -c "CREATE DATABASE cloudtolocalllm;"
docker compose exec postgres psql -U cloudtolocalllm cloudtolocalllm < $BACKUP_DIR/database.sql

# Restore application data
tar -xzf $BACKUP_DIR/app_data.tar.gz -C /

# Restore SSL certificates
tar -xzf $BACKUP_DIR/ssl_certs.tar.gz -C /

# Start services
docker compose up -d
```

---

This comprehensive infrastructure guide consolidates all operational aspects of CloudToLocalLLM into a single authoritative reference, replacing scattered infrastructure documentation with organized, actionable information.
