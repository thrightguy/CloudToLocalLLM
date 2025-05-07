#!/bin/bash

echo "=== Checking index.html content ==="
cat /opt/cloudtolocalllm/nginx/html/index.html

echo -e "\n=== Checking local resources ==="
ls -l /opt/cloudtolocalllm/nginx/html/css/
ls -l /opt/cloudtolocalllm/nginx/html/webfonts/

echo -e "\n=== Checking Nginx configuration ==="
docker exec nginx-proxy nginx -t

echo -e "\n=== Checking Nginx logs ==="
docker exec nginx-proxy tail -n 50 /var/log/nginx/error.log 