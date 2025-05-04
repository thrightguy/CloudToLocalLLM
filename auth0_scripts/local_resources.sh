#!/bin/bash

# Source common functions
source /tmp/auth0_scripts/common.sh

yellow "Setting up local CSS and Font resources..."

# Create directories for local resources
mkdir -p $WEB_ROOT/css
mkdir -p $WEB_ROOT/webfonts
mkdir -p $WEB_ROOT/js

# Download Bulma CSS locally
yellow "Downloading Bulma CSS..."
curl -s https://cdn.jsdelivr.net/npm/bulma@0.9.4/css/bulma.min.css > $WEB_ROOT/css/bulma.min.css
if [ -f "$WEB_ROOT/css/bulma.min.css" ]; then
    green "Bulma CSS downloaded successfully"
else
    red "Failed to download Bulma CSS"
    exit 1
fi

# Download Font Awesome CSS locally
yellow "Downloading Font Awesome CSS..."
curl -s https://cdnjs.cloudflare.com/ajax/libs/font-awesome/5.15.4/css/all.min.css > $WEB_ROOT/css/fontawesome.min.css
if [ -f "$WEB_ROOT/css/fontawesome.min.css" ]; then
    green "Font Awesome CSS downloaded successfully"
else
    red "Failed to download Font Awesome CSS"
    exit 1
fi

# Download Font Awesome webfonts locally
yellow "Downloading Font Awesome webfonts..."
for FONT in fa-solid-900.woff2 fa-regular-400.woff2 fa-brands-400.woff2; do
    curl -s https://cdnjs.cloudflare.com/ajax/libs/font-awesome/5.15.4/webfonts/$FONT > $WEB_ROOT/webfonts/$FONT
done

# Fix Font Awesome CSS to use local webfonts
sed -i 's|https://cdnjs.cloudflare.com/ajax/libs/font-awesome/5.15.4/webfonts/|/webfonts/|g' $WEB_ROOT/css/fontawesome.min.css
green "Font Awesome webfonts paths updated to use local resources"

# Download Auth0 JS
yellow "Downloading Auth0 JS..."
curl -s https://cdn.auth0.com/js/auth0-spa-js/2.0/auth0-spa-js.production.js > $WEB_ROOT/js/auth0-spa-js.js
if [ -f "$WEB_ROOT/js/auth0-spa-js.js" ]; then
    green "Auth0 JS downloaded successfully"
else
    red "Failed to download Auth0 JS"
    exit 1
fi

green "Local resources set up successfully"