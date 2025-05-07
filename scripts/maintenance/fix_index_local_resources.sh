#!/bin/bash

INDEX_FILE="/opt/cloudtolocalllm/nginx/html/index.html"
BACKUP_DIR="/opt/cloudtolocalllm/backup_$(date +%Y%m%d%H%M%S)"

if [ -f "$INDEX_FILE" ]; then
    mkdir -p "$BACKUP_DIR"
    cp "$INDEX_FILE" "$BACKUP_DIR/index.html.original"
    echo "Backup created at $BACKUP_DIR/index.html.original"

    # Remove all <link> and <script> tags referencing external resources
    sed -i '/<link.*https:\/\//d' "$INDEX_FILE"
    sed -i '/<script.*https:\/\//d' "$INDEX_FILE"
    sed -i '/cdn.jsdelivr.net/d' "$INDEX_FILE"
    sed -i '/cdnjs.cloudflare.com/d' "$INDEX_FILE"
    sed -i '/cloudflare.com/d' "$INDEX_FILE"
    sed -i '/bulma/d' "$INDEX_FILE"
    sed -i '/font-awesome/d' "$INDEX_FILE"
    sed -i '/all.min.css/d' "$INDEX_FILE"

    # Insert new dark theme style after <head>
    sed -i '/<head>/a \
<style>\
body { background: #181a20; color: #f1f1f1; font-family: Arial, sans-serif; margin: 0; padding: 0; }\
.header { background: linear-gradient(90deg, #232526 0%, #414345 100%); color: #fff; padding: 2rem 1rem; text-align: center; }\
.banner { background: #f7c948; color: #232526; padding: 1rem; text-align: center; font-weight: bold; font-size: 1.2rem; }\
h1, h2, h3, h4, h5, h6 { color: #f7c948; }\
a { color: #6ec1e4; text-decoration: underline; }\
a:hover { color: #f7c948; }\
.section { background: #232526; margin: 2rem auto; padding: 2rem; border-radius: 8px; max-width: 900px; box-shadow: 0 2px 8px #0003; }\
</style>' "$INDEX_FILE"

    echo "Dark theme applied to $INDEX_FILE"
else
    echo "index.html not found at $INDEX_FILE"
fi 