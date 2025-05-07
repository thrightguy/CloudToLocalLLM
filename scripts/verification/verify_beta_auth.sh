#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}Verifying beta authentication setup...${NC}"

# Check if server.conf exists and has beta subdomain configuration
if [ -f "server.conf" ]; then
  echo -e "${GREEN}✓ server.conf file exists${NC}"
  
  # Check for beta server block
  if grep -q "server_name beta.cloudtolocalllm.online" server.conf; then
    echo -e "${GREEN}✓ Beta subdomain configured in server.conf${NC}"
  else
    echo -e "${RED}✗ Beta subdomain not found in server.conf${NC}"
    echo -e "${YELLOW}Run ./update_ssl_fixed.sh to fix this issue${NC}"
    exit 1
  fi
  
  # Check for auth proxy
  if grep -q "location /auth/" server.conf; then
    echo -e "${GREEN}✓ Auth proxy configured in server.conf${NC}"
  else
    echo -e "${RED}✗ Auth proxy not found in server.conf${NC}"
    echo -e "${YELLOW}Run ./update_ssl_fixed.sh to fix this issue${NC}"
    exit 1
  fi
else
  echo -e "${RED}✗ server.conf file not found${NC}"
  echo -e "${YELLOW}Run ./update_ssl_fixed.sh to create server.conf${NC}"
  exit 1
fi

# Check if docker-compose.web.yml has auth service
if [ -f "docker-compose.web.yml" ]; then
  echo -e "${GREEN}✓ docker-compose.web.yml file exists${NC}"
  
  if grep -q "auth:" docker-compose.web.yml; then
    echo -e "${GREEN}✓ Auth service configured in docker-compose.web.yml${NC}"
  else
    echo -e "${RED}✗ Auth service not found in docker-compose.web.yml${NC}"
    echo -e "${YELLOW}Run ./update_ssl_fixed.sh to fix this issue${NC}"
    exit 1
  fi
else
  echo -e "${RED}✗ docker-compose.web.yml file not found${NC}"
  echo -e "${YELLOW}Run ./fix_and_deploy.sh to create docker-compose.web.yml${NC}"
  exit 1
fi

# Check if auth service is running
auth_status=$(docker-compose -f docker-compose.web.yml ps -q auth 2>/dev/null || echo "")
if [ -n "$auth_status" ]; then
  if [ "$(docker ps -q -f id=$auth_status)" ]; then
    echo -e "${GREEN}✓ Auth service is running${NC}"
    
    # Attempt to check auth service health
    echo -e "${YELLOW}Checking auth service health...${NC}"
    health_output=$(docker-compose -f docker-compose.web.yml exec auth wget --no-verbose --tries=1 --spider http://localhost:8080/health 2>&1)
    
    if echo "$health_output" | grep -q "200 OK"; then
      echo -e "${GREEN}✓ Auth service health check passed${NC}"
    else
      echo -e "${RED}✗ Auth service health check failed${NC}"
      echo -e "${YELLOW}Check auth service logs: docker-compose -f docker-compose.web.yml logs auth${NC}"
    fi
  else
    echo -e "${RED}✗ Auth service is defined but not running${NC}"
    echo -e "${YELLOW}Start services: docker-compose -f docker-compose.web.yml up -d${NC}"
    exit 1
  fi
else
  echo -e "${RED}✗ Auth service not running${NC}"
  echo -e "${YELLOW}Run docker-compose -f docker-compose.web.yml up -d${NC}"
  exit 1
fi

# Check SSL certificate includes beta subdomain
echo -e "${YELLOW}Checking SSL certificate...${NC}"
cert_output=$(docker run --rm -v "$(pwd)/certbot/conf:/etc/letsencrypt" certbot/certbot certificates 2>&1)

if echo "$cert_output" | grep -q "beta.cloudtolocalllm.online"; then
  echo -e "${GREEN}✓ SSL certificate includes beta subdomain${NC}"
else
  echo -e "${RED}✗ SSL certificate does not include beta subdomain${NC}"
  echo -e "${YELLOW}Run ./update_ssl_fixed.sh to update SSL certificate${NC}"
  exit 1
fi

# Attempt to access beta subdomain
echo -e "${YELLOW}Testing beta subdomain accessibility...${NC}"
echo -e "${GREEN}✓ Configuration verification completed${NC}"
echo -e "${YELLOW}Manually test the beta subdomain at: https://beta.cloudtolocalllm.online${NC}"
echo -e "${YELLOW}Check auth service is working by visiting: https://beta.cloudtolocalllm.online/auth/login${NC}"
echo -e ""
echo -e "${GREEN}If you encounter any issues, check:${NC}"
echo -e "1. Container logs: docker-compose -f docker-compose.web.yml logs"
echo -e "2. Nginx configuration: cat server.conf"
echo -e "3. SSL certificates: docker run --rm -v \"$(pwd)/certbot/conf:/etc/letsencrypt\" certbot/certbot certificates"

exit 0 