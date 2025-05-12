#!/bin/bash
# Let's Encrypt Certbot DNS-01 (manual) script, following official documentation
set -e
trap 'echo -e "\033[1;31m[ERROR] Script interrupted or failed. Please check logs.\033[0m"; exit 1' INT TERM ERR

EMAIL="christopher.maltais@gmail.com"
DOMAINS="-d *.cloudtolocalllm.online -d cloudtolocalllm.online"

# Use the official Certbot Docker invocation for DNS-01
# See: https://eff-certbot.readthedocs.io/en/stable/using.html#manual

echo -e "\033[1;36mLet's Encrypt Certbot (DNS-01 manual challenge)\033[0m"
echo -e "\033[1;33mEmail:\033[0m $EMAIL"
echo -e "\033[1;33mDomains:\033[0m $DOMAINS"
echo

docker run -it --rm \
  -v "$(pwd)/config/docker/certbot/conf:/etc/letsencrypt" \
  -v "$(pwd)/config/docker/certbot/www:/var/www/certbot" \
  certbot/certbot certonly --manual --preferred-challenges dns \
  --email "$EMAIL" $DOMAINS \
  --agree-tos --no-eff-email --keep-until-expiring --manual-public-ip-logging-ok

CODE=$?

echo -e "\033[1;36mCertbot exit code:\033[0m $CODE"
if [ $CODE -eq 0 ]; then
    echo -e "\033[1;32m[SUCCESS]\033[0m"
else
    echo -e "\033[1;31m[ERROR]\033[0m"
    exit 1
fi 