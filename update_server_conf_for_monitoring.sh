#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}Updating server.conf to include Netdata monitoring...${NC}"

# Check if server.conf exists
if [ ! -f "server.conf" ]; then
  echo -e "${RED}server.conf not found! Run update_ssl_fixed.sh first to create it.${NC}"
  exit 1
fi

# Make a backup of the current config
cp server.conf server.conf.bak
echo -e "${GREEN}Created backup of server.conf as server.conf.bak${NC}"

# Check if monitoring location is already configured
if grep -q "location /monitor/" server.conf; then
  echo -e "${YELLOW}Monitoring configuration already exists in server.conf${NC}"
else
  # Add the monitoring location to the main domain server block
  echo -e "${YELLOW}Adding monitoring location to main domain configuration...${NC}"
  
  # Use awk to add the monitoring location block
  awk '/server_name cloudtolocalllm.online www.cloudtolocalllm.online;/{found=1} 
       /Static files caching/{if(found==1){print "    # Netdata monitoring dashboard\n    location /monitor/ {\n        proxy_pass http://netdata:19999/;\n        proxy_set_header Host $host;\n        proxy_set_header X-Real-IP $remote_addr;\n        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;\n        proxy_set_header X-Forwarded-Proto $scheme;\n\n        # Optional: Basic authentication\n        auth_basic \"Monitoring Area\";\n        auth_basic_user_file /etc/nginx/.htpasswd;\n    }\n"; found=0}} 1' server.conf > server.conf.new
  
  mv server.conf.new server.conf
  echo -e "${GREEN}Added monitoring location to server.conf${NC}"
  
  # Create a simple .htpasswd file with a default password
  # in actual deployment, this would be done with htpasswd
  echo -e "${YELLOW}Creating basic auth credentials for monitoring...${NC}"
  echo 'admin:$apr1$zrXoWCvp$AuERJYPWY9SAkmS22S6.I1' > .htpasswd
  
  echo -e "${GREEN}Created .htpasswd file with default credentials:${NC}"
  echo -e "${GREEN}Username: admin${NC}"
  echo -e "${GREEN}Password: cloudtolocalllm${NC}"
  echo -e "${YELLOW}Please change these credentials in production!${NC}"
fi

echo -e "${GREEN}Server configuration updated.${NC}"
echo -e "${YELLOW}Rebuild and restart your containers to apply changes:${NC}"
echo -e "${YELLOW}docker-compose -f docker-compose.web.yml down${NC}"
echo -e "${YELLOW}docker-compose -f docker-compose.web.yml up -d${NC}"

echo -e "${GREEN}Your monitoring dashboard will be available at:${NC}"
echo -e "${GREEN}https://cloudtolocalllm.online/monitor/${NC}"
echo -e "${GREEN}=============================================================${NC}" 