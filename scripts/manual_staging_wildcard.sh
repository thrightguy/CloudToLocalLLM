#!/bin/bash

# Script to request a Let's Encrypt wildcard certificate from the PRODUCTION environment
# using manual DNS-01 challenge.
# PRODUCTION certificates ARE trusted by browsers.

# --- Configuration ---
DOMAIN="cloudtolocalllm.online" # !!! IMPORTANT: Replace with your actual domain if different !!!
EMAIL="christopher.maltais@gmail.com"  # !!! IMPORTANT: Replace with your actual email address !!!
# --- End Configuration ---

# Colors for output
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Starting Let's Encrypt Wildcard Certificate Request (PRODUCTION SERVER)${NC}"
echo -e "${YELLOW}Domain:${NC} $DOMAIN"
echo -e "${YELLOW}Email:${NC} $EMAIL"
echo -e "${RED}IMPORTANT: This script uses the Let's Encrypt PRODUCTION server.${NC}"
echo -e "${RED}Certificates obtained will be publicly trusted. Ensure your DNS records are set up correctly.${NC}"
echo ""

# Check if Certbot is installed
if ! command -v certbot &> /dev/null
then
    echo -e "${RED}Certbot could not be found. Please install Certbot first.${NC}"
    echo -e "${YELLOW}Common installation commands (choose one appropriate for your VPS OS):${NC}"
    echo "  sudo apt update && sudo apt install certbot python3-certbot-nginx (Debian/Ubuntu with Nginx)"
    echo "  sudo apt update && sudo apt install certbot python3-certbot-apache (Debian/Ubuntu with Apache)"
    echo "  sudo yum install certbot python3-certbot-nginx (CentOS/RHEL with Nginx)"
    echo "  sudo yum install certbot python3-certbot-apache (CentOS/RHEL with Apache)"
    echo "If you are using a different web server or OS, please consult the Certbot documentation: https://certbot.eff.org/instructions"
    exit 1
fi

echo -e "${YELLOW}Certbot found. Proceeding with certificate request...${NC}"
echo ""
echo -e "${YELLOW}You will be prompted by Certbot to create DNS TXT records.${NC}"
echo -e "1. Certbot will provide one or two TXT record names and values."
echo -e "   The names will look like: ${GREEN}_acme-challenge.$DOMAIN${NC}"
echo -e "2. Log in to your Namecheap account."
echo -e "3. Go to 'Domain List', click 'Manage' next to '$DOMAIN', then 'Advanced DNS'."
echo -e "4. Under 'Host Records', click 'ADD NEW RECORD'."
echo -e "   - Type: ${GREEN}TXT Record${NC}"
echo -e "   - Host: Enter the part Certbot gives you (e.g., ${GREEN}_acme-challenge${NC} - Namecheap automatically appends .$DOMAIN for this field if you only enter the subdomain part)."
echo -e "   - Value: Enter the long string value Certbot provides."
echo -e "   - TTL: Set to a low value like ${GREEN}1 minute${NC} or ${GREEN}600 seconds${NC} (if possible) or leave as Automatic."
echo -e "5. ${RED}VERY IMPORTANT: Wait for DNS propagation (can take several minutes, sometimes longer) after adding the records before pressing Enter in Certbot.${NC}"
echo -e "   You can check DNS propagation using a tool like: https://www.whatsmydns.net/#TXT/_acme-challenge.$DOMAIN"
echo -e "   Incorrect or non-propagated DNS records will lead to FAILED validation attempts and may temporarily block you from requesting certificates."
echo ""
echo -e "${YELLOW}Press [Enter] to confirm you've read the instructions above and are ready to start Certbot.${NC}"
read -r

# Request the certificate
# Using --keep-until-expiring to avoid repeated requests if script is re-run before expiry.
certbot certonly \
    --config-dir "$(pwd)/certbot/conf" \
    --work-dir "$(pwd)/certbot/work" \
    --logs-dir "$(pwd)/certbot/logs" \
    --manual \
    --preferred-challenges dns \
    -d "$DOMAIN" \
    -d "*.$DOMAIN" \
    --agree-tos \
    -m "$EMAIL" \
    --no-eff-email \
    --keep-until-expiring

EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ]; then
    echo -e "${GREEN}Certbot process completed successfully!${NC}"
    echo -e "${GREEN}Your PRODUCTION certificates should be in $(pwd)/certbot/conf/live/$DOMAIN/${NC}"
    echo -e "${YELLOW}You should now restart your web server for the new certificates to take effect.${NC}"
    echo -e "${YELLOW}For renewals, you will need to run this script again before the certificates expire (typically 90 days).${NC}"
    echo -e "${YELLOW}Consider automating this process if possible (e.g., with acme-dns or a Certbot DNS plugin if API access becomes available for your DNS provider).${NC}"
else
    echo -e "${RED}Certbot process failed with exit code $EXIT_CODE.${NC}"
    echo -e "${RED}Please review the output from Certbot for error details.${NC}"
fi

echo ""
echo -e "${YELLOW}Script finished.${NC}" 