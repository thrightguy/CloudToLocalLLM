#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Initialize git repository
echo -e "${YELLOW}Initializing git repository...${NC}"
git init

# Add all files
echo -e "${YELLOW}Adding files to git...${NC}"
git add .

# Create initial commit
echo -e "${YELLOW}Creating initial commit...${NC}"
git commit -m "Initial commit: Cloud portal setup"

# Add GitHub remote
echo -e "${YELLOW}Adding GitHub remote...${NC}"
git remote add origin https://github.com/imrightguy/CloudToLocalLLM.git

# Push to GitHub
echo -e "${YELLOW}Pushing to GitHub...${NC}"
git push -u origin main

echo -e "${GREEN}GitHub repository initialized and changes pushed!${NC}" 