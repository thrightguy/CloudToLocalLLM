# Remove obsolete manual copying steps
# echo -e "${GREEN}Copying web app to server...${NC}"
# scp -i $SSH_KEY -r web/* $VPS_USER@$VPS_HOST:$APP_DIR/web/

# echo -e "${GREEN}Copying Docker configuration...${NC}"
# scp -i $SSH_KEY docker-compose.yml Dockerfile.web $VPS_USER@$VPS_HOST:$APP_DIR/

# New workflow uses volume mounts; deploy script should only build and restart the container
echo -e "${GREEN}Building and starting Docker containers...${NC}"
ssh -i $SSH_KEY $VPS_USER@$VPS_HOST "cd $APP_DIR && docker-compose up -d --build" 