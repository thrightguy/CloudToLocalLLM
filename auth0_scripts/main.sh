#!/bin/bash
set -e

echo "===== Auth0 Implementation with Local Resources ====="

# Source common functions
source /tmp/auth0_scripts/common.sh

# Create backup
create_backup

# Execute each step 
echo "===== Step 1: Setting up local resources ====="
bash /tmp/auth0_scripts/local_resources.sh
if [ $? -ne 0 ]; then
    red "Step 1 failed. Exiting."
    exit 1
fi

echo "===== Step 2: Creating Auth0 login page ====="
bash /tmp/auth0_scripts/login_page.sh
if [ $? -ne 0 ]; then
    red "Step 2 failed. Exiting."
    exit 1
fi

echo "===== Step 3: Modifying index.html ====="
bash /tmp/auth0_scripts/modify_index.sh
if [ $? -ne 0 ]; then
    red "Step 3 failed. Exiting."
    exit 1
fi

echo "===== Step 4: Restarting services ====="
bash /tmp/auth0_scripts/restart_services.sh
if [ $? -ne 0 ]; then
    red "Step 4 failed. Exiting."
    exit 1
fi

green "===== Auth0 implementation completed successfully! ====="
green "Login page available at: /login.html"