param (
    [Parameter(Mandatory=$true)]
    [string]$VpsHost,
    
    [Parameter(Mandatory=$false)]
    [string]$SshKeyPath = "$env:USERPROFILE\.ssh\id_rsa",
    
    [Parameter(Mandatory=$false)]
    [string]$Auth0ClientId = "your_auth0_client_id",
    
    [Parameter(Mandatory=$false)]
    [switch]$CreateBackupOnly
)

# Colors for better readability
function Write-ColorOutput($ForegroundColor) {
    $fc = $host.UI.RawUI.ForegroundColor
    $host.UI.RawUI.ForegroundColor = $ForegroundColor
    if ($args) { Write-Output $args }
    $host.UI.RawUI.ForegroundColor = $fc
}

Write-ColorOutput Green "Implementing Auth0 direct login on $VpsHost..."

# Create the VPS script
$vpsScript = @'
#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}Starting Auth0 login implementation...${NC}"

# Set Auth0 client ID
AUTH0_CLIENT_ID="__AUTH0_CLIENT_ID__"
AUTH0_DOMAIN="dev-cloudtolocalllm.us.auth0.com"
AUTH0_REDIRECT_URI="https://cloudtolocalllm.online/"
AUTH0_AUDIENCE="https://api.cloudtolocalllm.online"

# Create backup
TIMESTAMP=$(date +%Y%m%d%H%M%S)
BACKUP_DIR="/opt/cloudtolocalllm/nginx/html/backup_${TIMESTAMP}"
echo -e "${YELLOW}Creating backup in ${BACKUP_DIR}...${NC}"
mkdir -p $BACKUP_DIR
cp -r /opt/cloudtolocalllm/nginx/html/* $BACKUP_DIR/ 2>/dev/null || true

# If backup only, exit here
if [ "$1" = "backup-only" ]; then
    echo -e "${GREEN}Backup created successfully. Exiting without making changes.${NC}"
    exit 0
fi

# Create a temporary directory for working
TEMP_DIR="/tmp/auth0_implementation"
rm -rf $TEMP_DIR
mkdir -p $TEMP_DIR

# Function to modify index.html with Auth0 script
modify_index_html() {
    INDEX_FILE="$1"
    
    # Check if file exists
    if [ ! -f "$INDEX_FILE" ]; then
        echo -e "${RED}Error: Index file not found at $INDEX_FILE${NC}"
        return 1
    }
    
    # Make a copy for editing
    cp "$INDEX_FILE" "${TEMP_DIR}/index.html.original"
    
    # Look for the closing </head> tag
    if ! grep -q "</head>" "$INDEX_FILE"; then
        echo -e "${RED}Error: Could not find </head> tag in index.html${NC}"
        return 1
    }
    
    # Add Auth0 script before the closing head tag
    AUTH0_SCRIPT='
  <!-- Auth0 SPA JS -->
  <script src="https://cdn.auth0.com/js/auth0-spa-js/2.0/auth0-spa-js.production.js"></script>
  
  <!-- Auth0 callback handler -->
  <script>
    // Handle Auth0 callback redirect
    window.handleAuth0Callback = function() {
      const urlParams = new URLSearchParams(window.location.search);
      const code = urlParams.get("code");
      const state = urlParams.get("state");
      
      if (code && state) {
        console.log("Auth0 callback detected, code and state present");
        // Store in sessionStorage for Flutter to access
        sessionStorage.setItem("auth0_code", code);
        sessionStorage.setItem("auth0_state", state);
        
        // Remove code and state from URL to avoid issues
        if (window.history && window.history.replaceState) {
          window.history.replaceState({}, document.title, "/");
        }
      }
    };
    
    // Run on page load
    window.addEventListener("load", function() {
      window.handleAuth0Callback();
    });
  </script>'
    
    sed -i "s|</head>|${AUTH0_SCRIPT}\n</head>|" "$INDEX_FILE"
    echo -e "${GREEN}Added Auth0 script to index.html${NC}"
    return 0
}

# Function to modify main.dart.js file to update Auth0 client ID
update_auth0_config() {
    # Find all JavaScript files
    JS_FILES=$(find /opt/cloudtolocalllm/nginx/html -name "*.js" -type f)
    
    # Look for files that contain Auth0 configuration
    for JS_FILE in $JS_FILES; do
        # Check if this file contains Auth0 client ID placeholder
        if grep -q "your_auth0_client_id" "$JS_FILE"; then
            echo -e "${YELLOW}Updating Auth0 client ID in $JS_FILE...${NC}"
            sed -i "s/your_auth0_client_id/${AUTH0_CLIENT_ID}/g" "$JS_FILE"
            
            # Update Auth0 domain if needed
            sed -i "s/dev-cloudtolocalllm\.us\.auth0\.com/${AUTH0_DOMAIN}/g" "$JS_FILE"
            
            # Update Auth0 redirect URI if needed
            ESCAPED_REDIRECT_URI=$(echo "$AUTH0_REDIRECT_URI" | sed 's/\//\\\//g')
            sed -i "s/https:\/\/cloudtolocalllm\.online\//${ESCAPED_REDIRECT_URI}/g" "$JS_FILE"
            
            echo -e "${GREEN}Updated Auth0 configuration in $JS_FILE${NC}"
        fi
    done
}

# Modify login page - we'll create a custom HTML page that has better styling
create_login_page() {
    LOGIN_HTML="${TEMP_DIR}/login.html"
    
    cat > "$LOGIN_HTML" << EOF
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>CloudToLocalLLM - Login</title>
  <style>
    body {
      background: linear-gradient(135deg, #6e8efb, #a777e3);
      min-height: 100vh;
      display: flex;
      align-items: center;
      justify-content: center;
      font-family: Arial, sans-serif;
      margin: 0;
      padding: 0;
    }
    .login-container {
      background: white;
      border-radius: 8px;
      padding: 2.5rem;
      width: 90%;
      max-width: 500px;
      box-shadow: 0 10px 25px rgba(0,0,0,0.1);
    }
    .logo {
      text-align: center;
      margin-bottom: 2rem;
    }
    .logo img {
      max-width: 150px;
    }
    .title {
      color: #333;
      text-align: center;
      margin-bottom: 2rem;
      font-size: 1.5rem;
      font-weight: bold;
    }
    .login-button {
      width: 100%;
      margin-top: 1rem;
      background-color: #6e8efb;
      border: none;
      color: white;
      padding: 12px 20px;
      text-align: center;
      text-decoration: none;
      display: inline-block;
      font-size: 16px;
      border-radius: 4px;
      cursor: pointer;
      transition: background-color 0.3s;
    }
    .login-button:hover {
      background-color: #5470c6;
    }
    .footer-text {
      text-align: center;
      margin-top: 2rem;
      color: #888;
      font-size: 0.9rem;
    }
  </style>
  <script src="https://cdn.auth0.com/js/auth0-spa-js/2.0/auth0-spa-js.production.js"></script>
</head>
<body>
  <div class="login-container">
    <div class="logo">
      <img src="assets/assets/CloudToLocalLLM_logo.jpg" alt="CloudToLocalLLM Logo">
    </div>
    <h1 class="title">Cloud-Based LLM Management</h1>
    
    <div id="login-container">
      <button id="login-button" class="login-button">
        Login
      </button>
    </div>
    
    <p class="footer-text">
      Run powerful Large Language Models locally with cloud-based management
    </p>
  </div>

  <script>
    // Initialize Auth0 client
    let auth0Client = null;
    
    const configureClient = async () => {
      auth0Client = await createAuth0Client({
        domain: '${AUTH0_DOMAIN}',
        clientId: '${AUTH0_CLIENT_ID}',
        authorizationParams: {
          redirect_uri: '${AUTH0_REDIRECT_URI}',
          audience: '${AUTH0_AUDIENCE}'
        }
      });
    };
    
    // Handle login click
    const login = async () => {
      try {
        console.log('Redirecting to Auth0 login...');
        await auth0Client.loginWithRedirect();
      } catch (error) {
        console.error('Login error:', error);
        alert('Login failed. Please try again.');
      }
    };
    
    // Initialize on page load
    window.addEventListener('load', async () => {
      await configureClient();
      document.getElementById('login-button').addEventListener('click', login);
    });
  </script>
</body>
</html>
EOF

    # Copy login page to nginx html directory
    cp "$LOGIN_HTML" "/opt/cloudtolocalllm/nginx/html/login.html"
    echo -e "${GREEN}Created custom login page at /login.html${NC}"
}

# Update Nginx configuration to fix CSP issues
update_nginx_config() {
    echo -e "${YELLOW}Updating Nginx configuration to fix CSP issues...${NC}"
    
    # First check if the custom configuration directory exists
    NGINX_CONF_DIR="/opt/cloudtolocalllm/nginx/custom_conf"
    
    if [ ! -d "$NGINX_CONF_DIR" ]; then
        echo -e "${YELLOW}Creating custom Nginx configuration directory...${NC}"
        mkdir -p "$NGINX_CONF_DIR"
    fi
    
    # Create a configuration file for CSP headers
    CSP_CONF="${NGINX_CONF_DIR}/csp_headers.conf"
    
    cat > "$CSP_CONF" << EOF
# CloudToLocalLLM CSP Headers Configuration
add_header Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval' https://cdn.auth0.com; style-src 'self' 'unsafe-inline' https://cdn.jsdelivr.net https://cdnjs.cloudflare.com https://cdn.auth0.com; img-src 'self' data: https://*.auth0.com; font-src 'self' https://cdnjs.cloudflare.com; connect-src 'self' https://*.auth0.com https://api.cloudtolocalllm.online; frame-src 'self' https://*.auth0.com;" always;
add_header X-Frame-Options "SAMEORIGIN" always;
add_header X-Content-Type-Options "nosniff" always;
add_header X-XSS-Protection "1; mode=block" always;
add_header Referrer-Policy "strict-origin-when-cross-origin" always;
EOF

    echo -e "${GREEN}Created CSP headers configuration file${NC}"
    
    # Check if we need to modify the nginx.conf to include our custom configuration
    NGINX_CONF="/opt/cloudtolocalllm/nginx/nginx.conf"
    
    # If nginx.conf exists, check if it already includes our custom configuration
    if [ -f "$NGINX_CONF" ]; then
        if ! grep -q "include /etc/nginx/custom_conf/\*.conf;" "$NGINX_CONF"; then
            echo -e "${YELLOW}Updating nginx.conf to include custom configurations...${NC}"
            
            # Make a backup of the original nginx.conf
            cp "$NGINX_CONF" "${BACKUP_DIR}/nginx.conf.original"
            
            # Look for the server context and add our include directive
            sed -i '/server {/a \ \ \ \ include /etc/nginx/custom_conf/*.conf;' "$NGINX_CONF"
            
            echo -e "${GREEN}Updated nginx.conf to include custom configurations${NC}"
        else
            echo -e "${GREEN}nginx.conf already includes custom configurations${NC}"
        fi
    else
        echo -e "${YELLOW}nginx.conf not found at $NGINX_CONF, attempting to find and update server configuration...${NC}"
        
        # Try to find server configuration files
        SERVER_CONFS=$(find /opt/cloudtolocalllm/nginx -name "*.conf" -type f -exec grep -l "server {" {} \;)
        
        if [ -n "$SERVER_CONFS" ]; then
            for CONF in $SERVER_CONFS; do
                echo -e "${YELLOW}Updating server configuration in $CONF...${NC}"
                
                # Make a backup of the original configuration
                cp "$CONF" "${BACKUP_DIR}/$(basename "$CONF").original"
                
                # Look for the server context and add our include directive
                sed -i '/server {/a \ \ \ \ include /etc/nginx/custom_conf/*.conf;' "$CONF"
                
                echo -e "${GREEN}Updated $CONF to include custom configurations${NC}"
            done
        else
            echo -e "${RED}Could not find any server configuration files. CSP headers will need to be added manually.${NC}"
            
            # Create a simple nginx configuration with our CSP headers
            SIMPLE_CONF="/opt/cloudtolocalllm/nginx/conf.d/default.conf"
            mkdir -p "$(dirname "$SIMPLE_CONF")"
            
            cat > "$SIMPLE_CONF" << EOF
server {
    listen 80;
    server_name cloudtolocalllm.online;
    
    include /etc/nginx/custom_conf/*.conf;
    
    location / {
        root /usr/share/nginx/html;
        index index.html;
        try_files \$uri \$uri/ /index.html;
    }
}
EOF
            echo -e "${YELLOW}Created a simple default configuration at $SIMPLE_CONF${NC}"
        fi
    fi
    
    return 0
}

# Implement the changes
echo -e "${YELLOW}Modifying index.html...${NC}"
modify_index_html "/opt/cloudtolocalllm/nginx/html/index.html" || echo -e "${RED}Failed to modify index.html${NC}"

echo -e "${YELLOW}Creating custom login page...${NC}"
create_login_page || echo -e "${RED}Failed to create login page${NC}"

echo -e "${YELLOW}Updating Auth0 configuration in JS files...${NC}"
update_auth0_config || echo -e "${RED}Failed to update Auth0 configuration${NC}"

echo -e "${YELLOW}Updating Nginx configuration to fix CSP issues...${NC}"
update_nginx_config || echo -e "${RED}Failed to update Nginx configuration${NC}"

# Restart Nginx container
echo -e "${YELLOW}Restarting Nginx container...${NC}"
cd /opt/cloudtolocalllm
docker-compose restart nginx-proxy

echo -e "${GREEN}Auth0 login implementation completed!${NC}"
echo -e "${YELLOW}Auth0 direct login is now available at:${NC} ${GREEN}https://cloudtolocalllm.online${NC}"
echo -e "${YELLOW}Custom login page is available at:${NC} ${GREEN}https://cloudtolocalllm.online/login.html${NC}"
echo -e "${YELLOW}CSP headers have been updated to fix style loading issues${NC}"
'@

# Replace placeholder with actual Auth0 client ID
$vpsScript = $vpsScript -replace "__AUTH0_CLIENT_ID__", $Auth0ClientId

# Convert to Unix line endings (LF)
$vpsScript = $vpsScript -replace "`r`n", "`n"
$vpsScriptPath = [System.IO.Path]::GetTempFileName()
Set-Content -Path $vpsScriptPath -Value $vpsScript -NoNewline -Encoding utf8

# Upload and run the script on the VPS
Write-ColorOutput Yellow "Uploading script to VPS..."
scp -i $SshKeyPath $vpsScriptPath "${VpsHost}:/tmp/implement_auth0_login.sh"
ssh -i $SshKeyPath $VpsHost "chmod +x /tmp/implement_auth0_login.sh"

if ($CreateBackupOnly) {
    Write-ColorOutput Yellow "Creating backup only (not implementing changes)..."
    ssh -i $SshKeyPath $VpsHost "sudo /tmp/implement_auth0_login.sh backup-only"
} else {
    Write-ColorOutput Yellow "Implementing Auth0 login changes on VPS..."
    ssh -i $SshKeyPath $VpsHost "sudo /tmp/implement_auth0_login.sh"
}

# Clean up
Write-ColorOutput Yellow "Cleaning up temporary files..."
Remove-Item -Force $vpsScriptPath

if ($CreateBackupOnly) {
    Write-ColorOutput Green "Backup created successfully on VPS."
} else {
    Write-ColorOutput Green "Auth0 login implementation completed!"
    Write-ColorOutput Yellow "Auth0 direct login is now available at:"
    Write-Host "https://cloudtolocalllm.online"
    Write-ColorOutput Yellow "Custom login page is available at:"
    Write-Host "https://cloudtolocalllm.online/login.html"
    Write-ColorOutput Yellow "CSP headers have been updated to fix style loading issues"
} 