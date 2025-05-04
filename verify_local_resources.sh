#!/bin/bash

# Create necessary directories
mkdir -p /opt/cloudtolocalllm/nginx/html/css
mkdir -p /opt/cloudtolocalllm/nginx/html/webfonts

# Download Bulma CSS if it doesn't exist
if [ ! -f "/opt/cloudtolocalllm/nginx/html/css/bulma.min.css" ]; then
    echo "Downloading Bulma CSS..."
    curl -L "https://cdn.jsdelivr.net/npm/bulma@0.9.4/css/bulma.min.css" -o "/opt/cloudtolocalllm/nginx/html/css/bulma.min.css"
fi

# Download FontAwesome CSS if it doesn't exist
if [ ! -f "/opt/cloudtolocalllm/nginx/html/css/fontawesome.min.css" ]; then
    echo "Downloading FontAwesome CSS..."
    curl -L "https://cdnjs.cloudflare.com/ajax/libs/font-awesome/5.15.4/css/all.min.css" -o "/opt/cloudtolocalllm/nginx/html/css/fontawesome.min.css"
fi

# Download FontAwesome webfonts if they don't exist
if [ ! -f "/opt/cloudtolocalllm/nginx/html/webfonts/fa-solid-900.woff2" ]; then
    echo "Downloading FontAwesome webfonts..."
    curl -L "https://cdnjs.cloudflare.com/ajax/libs/font-awesome/5.15.4/webfonts/fa-solid-900.woff2" -o "/opt/cloudtolocalllm/nginx/html/webfonts/fa-solid-900.woff2"
    curl -L "https://cdnjs.cloudflare.com/ajax/libs/font-awesome/5.15.4/webfonts/fa-regular-400.woff2" -o "/opt/cloudtolocalllm/nginx/html/webfonts/fa-regular-400.woff2"
    curl -L "https://cdnjs.cloudflare.com/ajax/libs/font-awesome/5.15.4/webfonts/fa-brands-400.woff2" -o "/opt/cloudtolocalllm/nginx/html/webfonts/fa-brands-400.woff2"
fi

# Set proper permissions
chown -R www-data:www-data /opt/cloudtolocalllm/nginx/html/css
chown -R www-data:www-data /opt/cloudtolocalllm/nginx/html/webfonts
chmod -R 755 /opt/cloudtolocalllm/nginx/html/css
chmod -R 755 /opt/cloudtolocalllm/nginx/html/webfonts

echo "Local resources verified and downloaded if needed." 