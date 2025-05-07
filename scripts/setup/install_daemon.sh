#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}Installing CloudToLocalLLM daemon...${NC}"

# Copy service file to systemd directory
cp cloudtolocalllm.service /etc/systemd/system/

# Reload systemd to recognize the new service
systemctl daemon-reload

# Enable the service to start at boot
systemctl enable cloudtolocalllm.service

# Start the service
systemctl start cloudtolocalllm.service

# Add monitoring and logging daemon if it exists
if [ -f "docker-compose.monitoring.yml" ]; then
    # Create monitoring service file
    cat > /etc/systemd/system/cloudtolocalllm-monitor.service << EOL
[Unit]
Description=CloudToLocalLLM Monitoring Service
After=cloudtolocalllm.service
Wants=cloudtolocalllm.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt/cloudtolocalllm/portal
User=root
Group=root

# Start monitoring services
ExecStart=/usr/bin/docker-compose -f docker-compose.monitoring.yml up -d

# Stop monitoring services
ExecStop=/usr/bin/docker-compose -f docker-compose.monitoring.yml down

# Restart policy
Restart=on-failure
RestartSec=10s

[Install]
WantedBy=multi-user.target
EOL

    # Reload systemd again
    systemctl daemon-reload
    
    # Enable and start monitoring service
    systemctl enable cloudtolocalllm-monitor.service
    systemctl start cloudtolocalllm-monitor.service
    
    echo -e "${GREEN}Monitoring daemon installed and started${NC}"
fi

# Create a simple management script
cat > /usr/local/bin/cloudctl << EOL
#!/bin/bash
# CloudToLocalLLM control script

case "\$1" in
    start)
        systemctl start cloudtolocalllm.service
        [ -f "/etc/systemd/system/cloudtolocalllm-monitor.service" ] && systemctl start cloudtolocalllm-monitor.service
        ;;
    stop)
        [ -f "/etc/systemd/system/cloudtolocalllm-monitor.service" ] && systemctl stop cloudtolocalllm-monitor.service
        systemctl stop cloudtolocalllm.service
        ;;
    restart)
        [ -f "/etc/systemd/system/cloudtolocalllm-monitor.service" ] && systemctl restart cloudtolocalllm-monitor.service
        systemctl restart cloudtolocalllm.service
        ;;
    status)
        systemctl status cloudtolocalllm.service
        [ -f "/etc/systemd/system/cloudtolocalllm-monitor.service" ] && systemctl status cloudtolocalllm-monitor.service
        ;;
    logs)
        case "\$2" in
            auth)
                docker-compose -f /opt/cloudtolocalllm/portal/docker-compose.auth.yml logs --tail=100 -f auth
                ;;
            web)
                docker-compose -f /opt/cloudtolocalllm/portal/docker-compose.web.yml logs --tail=100 -f nginx
                ;;
            admin)
                docker-compose -f /opt/cloudtolocalllm/portal/docker-compose.auth.yml logs --tail=100 -f admin-ui
                ;;
            db)
                docker-compose -f /opt/cloudtolocalllm/portal/docker-compose.auth.yml logs --tail=100 -f postgres
                ;;
            *)
                echo "Usage: cloudctl logs [auth|web|admin|db]"
                ;;
        esac
        ;;
    update)
        cd /opt/cloudtolocalllm/portal
        git pull
        cloudctl restart
        ;;
    *)
        echo "Usage: cloudctl {start|stop|restart|status|logs|update}"
        exit 1
        ;;
esac
exit 0
EOL

# Make the control script executable
chmod +x /usr/local/bin/cloudctl

echo -e "${GREEN}CloudToLocalLLM daemon installed successfully!${NC}"
echo -e "You can control the service with the ${YELLOW}cloudctl${NC} command:"
echo -e "  ${YELLOW}cloudctl start${NC} - Start all services"
echo -e "  ${YELLOW}cloudctl stop${NC} - Stop all services"
echo -e "  ${YELLOW}cloudctl restart${NC} - Restart all services"
echo -e "  ${YELLOW}cloudctl status${NC} - Check service status"
echo -e "  ${YELLOW}cloudctl logs auth|web|admin|db${NC} - View specific service logs"
echo -e "  ${YELLOW}cloudctl update${NC} - Pull latest changes and restart services" 