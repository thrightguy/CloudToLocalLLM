#!/bin/bash
# Minimal, colored, and clear Let's Encrypt Certbot script

set -e
trap 'echo -e "\033[1;31m[ERROR] Script interrupted or failed. Please check logs.\033[0m"; exit 1' INT TERM ERR

EMAIL="christopher.maltais@gmail.com"
DOMAINS="-d *.cloudtolocalllm.online -d cloudtolocalllm.online"
COMPOSE_FILE="docker-compose.yml"
CERTBOT_SERVICE="certbot"

echo -e "\033[1;36mLet's Encrypt Certbot (DNS challenge)\033[0m"
echo -e "\033[1;33mEmail:\033[0m $EMAIL"
echo -e "\033[1;33mDomains:\033[0m $DOMAINS"
echo

read -r -p $'\033[1;33mPress Enter to continue, or Ctrl+C to abort...\033[0m'

CMD="docker compose -f $COMPOSE_FILE run --rm $CERTBOT_SERVICE certonly --manual --preferred-challenges dns --email $EMAIL $DOMAINS --agree-tos --no-eff-email --keep-until-expiring --manual-public-ip-logging-ok"

echo -e "\033[1;36mRunning:\033[0m $CMD"
$CMD
CODE=$?

echo -e "\033[1;36mCertbot exit code:\033[0m $CODE"
if [ $CODE -eq 0 ]; then
    echo -e "\033[1;32m[SUCCESS]\033[0m"
else
    echo -e "\033[1;31m[ERROR]\033[0m"
    exit 1
fi 