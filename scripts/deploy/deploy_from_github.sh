#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

VPS_IP="162.254.34.115"
SSH_KEY="cloudadmin_key"
GITHUB_REPO="https://github.com/thrightguy/CloudToLocalLLM.git"
DEPLOY_DIR="/opt/cloudtolocalllm/portal"

echo -e "${YELLOW}Starting deployment from GitHub...${NC}"

# SSH into VPS and run deployment commands
ssh -i ${SSH_KEY} root@${VPS_IP} << EOF
    # Create deployment directory if it doesn't exist
    mkdir -p ${DEPLOY_DIR}
    cd ${DEPLOY_DIR}

    # Clone or pull the repository
    if [ -d ".git" ]; then
        echo "Pulling latest changes..."
        git pull origin main
    else
        echo "Cloning repository..."
        git clone ${GITHUB_REPO} .
    fi

    # Make deployment script executable
    chmod +x deploy_portal.sh

    # Run deployment script
    ./deploy_portal.sh
EOF

echo -e "${GREEN}Deployment from GitHub completed!${NC}"
echo -e "${YELLOW}The portal should now be accessible at https://cloudtolocalllm.online${NC}" 