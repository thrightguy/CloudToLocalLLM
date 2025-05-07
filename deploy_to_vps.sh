#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

VPS_IP="162.254.34.115"
SSH_KEY="cloudadmin_key"

echo -e "${YELLOW}Starting deployment to VPS...${NC}"

# Create a temporary directory for deployment files
TEMP_DIR=$(mktemp -d)
echo -e "${YELLOW}Created temporary directory: ${TEMP_DIR}${NC}"

# Copy necessary files to temp directory
echo -e "${YELLOW}Copying files to temporary directory...${NC}"
cp nginx.conf ${TEMP_DIR}/
cp docker-compose.web.yml ${TEMP_DIR}/
cp init-ssl.sh ${TEMP_DIR}/
cp Dockerfile.web ${TEMP_DIR}/
cp deploy_portal.sh ${TEMP_DIR}/

# Copy files to VPS
echo -e "${YELLOW}Copying files to VPS...${NC}"
scp -i ${SSH_KEY} -r ${TEMP_DIR}/* root@${VPS_IP}:/opt/cloudtolocalllm/portal/

# Make deploy script executable on VPS
echo -e "${YELLOW}Making deployment script executable...${NC}"
ssh -i ${SSH_KEY} root@${VPS_IP} "chmod +x /opt/cloudtolocalllm/portal/deploy_portal.sh"

# Run deployment script on VPS
echo -e "${YELLOW}Running deployment script on VPS...${NC}"
ssh -i ${SSH_KEY} root@${VPS_IP} "cd /opt/cloudtolocalllm/portal && ./deploy_portal.sh"

# Clean up
echo -e "${YELLOW}Cleaning up temporary files...${NC}"
rm -rf ${TEMP_DIR}

echo -e "${GREEN}Deployment to VPS completed!${NC}"
echo -e "${YELLOW}The portal should now be accessible at https://cloudtolocalllm.online${NC}" 