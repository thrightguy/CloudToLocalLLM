#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}Setting up VPS for CloudToLocalLLM...${NC}"

# Create SSH directory for root
echo -e "${YELLOW}Configuring root SSH access...${NC}"
mkdir -p /root/.ssh
chmod 700 /root/.ssh
echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPOoh04tdSc9OcMHepXyFJFKv1EtRz76DJLyL+DxAmKr cloudtolocalllm.online" > /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys

# Create cloudadmin user
echo -e "${YELLOW}Creating cloudadmin user...${NC}"
useradd -m -s /bin/bash cloudadmin
echo "cloudadmin:$(openssl rand -base64 32)" | chpasswd
usermod -aG sudo cloudadmin

# Set up SSH for cloudadmin
echo -e "${YELLOW}Configuring cloudadmin SSH access...${NC}"
mkdir -p /home/cloudadmin/.ssh
chmod 700 /home/cloudadmin/.ssh
echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPOoh04tdSc9OcMHepXyFJFKv1EtRz76DJLyL+DxAmKr cloudtolocalllm.online" > /home/cloudadmin/.ssh/authorized_keys
chmod 600 /home/cloudadmin/.ssh/authorized_keys
chown -R cloudadmin:cloudadmin /home/cloudadmin/.ssh

# Secure SSH configuration
echo -e "${YELLOW}Securing SSH configuration...${NC}"
cat > /etc/ssh/sshd_config << 'EOF'
Port 22
Protocol 2
HostKey /etc/ssh/ssh_host_rsa_key
HostKey /etc/ssh/ssh_host_ecdsa_key
HostKey /etc/ssh/ssh_host_ed25519_key

# Authentication
PermitRootLogin prohibit-password
PubkeyAuthentication yes
PasswordAuthentication no
PermitEmptyPasswords no
ChallengeResponseAuthentication no

# Forwarding
X11Forwarding no
AllowTcpForwarding yes
AllowAgentForwarding yes

# Security
UsePAM yes
AddressFamily inet
SyslogFacility AUTH
LogLevel INFO

# Other
AcceptEnv LANG LC_*
Subsystem sftp /usr/lib/openssh/sftp-server
EOF

# Restart SSH service
systemctl restart sshd

# Install essential packages
echo -e "${YELLOW}Installing essential packages...${NC}"
apt-get update
apt-get install -y \
    curl \
    git \
    docker.io \
    docker-compose \
    nginx \
    certbot \
    python3-certbot-nginx \
    ufw

# Start and enable Docker
systemctl start docker
systemctl enable docker
usermod -aG docker cloudadmin

# Configure UFW
echo -e "${YELLOW}Configuring firewall...${NC}"
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow http
ufw allow https
echo "y" | ufw enable

# Configure Nginx
echo -e "${YELLOW}Configuring Nginx...${NC}"
cat > /etc/nginx/sites-available/cloudtolocalllm << 'EOF'
server {
    listen 80;
    server_name cloudtolocalllm.online;

    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }

    location /api {
        proxy_pass http://localhost:8080;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }
}
EOF

ln -sf /etc/nginx/sites-available/cloudtolocalllm /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
nginx -t && systemctl restart nginx

# Set up SSL with Certbot
echo -e "${YELLOW}Setting up SSL certificate...${NC}"
certbot --nginx -d cloudtolocalllm.online --non-interactive --agree-tos --email christopher.maltais@gmail.com

# Create application directory
echo -e "${YELLOW}Setting up application directory...${NC}"
mkdir -p /opt/cloudtolocalllm
chown -R cloudadmin:cloudadmin /opt/cloudtolocalllm

echo -e "${GREEN}VPS setup completed successfully!${NC}"
echo -e "${YELLOW}Next steps:${NC}"
echo -e "1. ${GREEN}SSH access test:${NC}"
echo -e "   ssh -i ~/.ssh/cloudtolocalllm root@cloudtolocalllm.online"
echo -e "   ssh -i ~/.ssh/cloudtolocalllm cloudadmin@cloudtolocalllm.online"
echo -e "2. ${GREEN}Clone the repository:${NC}"
echo -e "   git clone git@github.com:yourusername/CloudToLocalLLM.git /opt/cloudtolocalllm"
echo -e "3. ${GREEN}Deploy the application:${NC}"
echo -e "   cd /opt/cloudtolocalllm && docker-compose up -d" 