#!/bin/sh

# Exit on any error
set -e

# Path to nginx config
NGINX_CONF="./config/nginx/nginx-webapp-internal.conf"

# Uncomment SSL server block and update server names
sed -i 's/# server {/server {/g' "$NGINX_CONF"
sed -i 's/#     listen 443 ssl;/    listen 443 ssl;/g' "$NGINX_CONF"
sed -i 's/#     server_name cloudtolocalllm.online www.cloudtolocalllm.online app.cloudtolocalllm.online;/    server_name cloudtolocalllm.online app.cloudtolocalllm.online mail.cloudtolocalllm.online;/g' "$NGINX_CONF"

# Uncomment SSL certificate paths
sed -i 's/#     ssl_certificate/    ssl_certificate/g' "$NGINX_CONF"
sed -i 's/#     ssl_certificate_key/    ssl_certificate_key/g' "$NGINX_CONF"

# Uncomment SSL configuration
sed -i 's/#     # SSL configuration/    # SSL configuration/g' "$NGINX_CONF"
sed -i 's/#     ssl_protocols/    ssl_protocols/g' "$NGINX_CONF"
sed -i 's/#     ssl_ciphers/    ssl_ciphers/g' "$NGINX_CONF"
sed -i 's/#     ssl_prefer_server_ciphers/    ssl_prefer_server_ciphers/g' "$NGINX_CONF"
sed -i 's/#     ssl_session_timeout/    ssl_session_timeout/g' "$NGINX_CONF"
sed -i 's/#     ssl_session_cache/    ssl_session_cache/g' "$NGINX_CONF"
sed -i 's/#     ssl_session_tickets/    ssl_session_tickets/g' "$NGINX_CONF"
sed -i 's/#     ssl_stapling/    ssl_stapling/g' "$NGINX_CONF"
sed -i 's/#     ssl_stapling_verify/    ssl_stapling_verify/g' "$NGINX_CONF"
sed -i 's/#     resolver/    resolver/g' "$NGINX_CONF"
sed -i 's/#     resolver_timeout/    resolver_timeout/g' "$NGINX_CONF"

# Uncomment HSTS
sed -i 's/#     # HSTS/    # HSTS/g' "$NGINX_CONF"
sed -i 's/#     # add_header/    # add_header/g' "$NGINX_CONF"

# Uncomment location block
sed -i 's/#     # Rest of the configuration/    # Rest of the configuration/g' "$NGINX_CONF"
sed -i 's/#     location/    location/g' "$NGINX_CONF"
sed -i 's/#         root/        root/g' "$NGINX_CONF"
sed -i 's/#         index/        index/g' "$NGINX_CONF"
sed -i 's/#         try_files/        try_files/g' "$NGINX_CONF"
sed -i 's/#         # Add security headers/        # Add security headers/g' "$NGINX_CONF"
sed -i 's/#         add_header/        add_header/g' "$NGINX_CONF"

# Uncomment gzip settings
sed -i 's/#     gzip/    gzip/g' "$NGINX_CONF"
sed -i 's/#     gzip_vary/    gzip_vary/g' "$NGINX_CONF"
sed -i 's/#     gzip_min_length/    gzip_min_length/g' "$NGINX_CONF"
sed -i 's/#     gzip_proxied/    gzip_proxied/g' "$NGINX_CONF"
sed -i 's/#     gzip_types/    gzip_types/g' "$NGINX_CONF"
sed -i 's/#     gzip_disable/    gzip_disable/g' "$NGINX_CONF"

# Close the server block
sed -i 's/# }/}/g' "$NGINX_CONF"

# Reload nginx
docker exec cloudtolocalllm-webapp nginx -s reload

echo "SSL configuration enabled and nginx reloaded" 