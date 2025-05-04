#!/bin/bash

# Check if all required files exist
echo "=== Checking required files ==="
FILES=(
    "/opt/cloudtolocalllm/nginx/html/css/bulma.min.css"
    "/opt/cloudtolocalllm/nginx/html/css/fontawesome.min.css"
    "/opt/cloudtolocalllm/nginx/html/webfonts/fa-solid-900.woff2"
    "/opt/cloudtolocalllm/nginx/html/webfonts/fa-regular-400.woff2"
    "/opt/cloudtolocalllm/nginx/html/webfonts/fa-brands-400.woff2"
    "/opt/cloudtolocalllm/nginx/conf.d/security_headers.conf"
)

for file in "${FILES[@]}"; do
    if [ -f "$file" ]; then
        echo "✓ Found $file"
    else
        echo "✗ Missing $file"
    fi
done

# Check index.html for CDN references
echo -e "\n=== Checking index.html for CDN references ==="
CDN_PATTERNS=(
    "cdnjs.cloudflare.com"
    "cdn.jsdelivr.net"
    "unpkg.com"
)

for pattern in "${CDN_PATTERNS[@]}"; do
    if grep -q "$pattern" /opt/cloudtolocalllm/nginx/html/index.html; then
        echo "✗ Found CDN reference to $pattern"
    else
        echo "✓ No reference to $pattern"
    fi
done

# Check Nginx configuration
echo -e "\n=== Checking Nginx configuration ==="
docker exec nginx-proxy nginx -t

# Check if security headers are loaded
echo -e "\n=== Checking security headers ==="
docker exec nginx-proxy cat /etc/nginx/conf.d/security_headers.conf

# Restart Nginx to apply changes
echo -e "\n=== Restarting Nginx ==="
docker exec nginx-proxy nginx -s reload

echo -e "\nVerification complete. Please check the website and clear your browser cache." 