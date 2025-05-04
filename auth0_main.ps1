param (
    [Parameter(Mandatory=$true)]
    [string]$VpsHost,
    
    [Parameter(Mandatory=$false)]
    [string]$SshKeyPath = "$env:USERPROFILE\.ssh\id_rsa",
    
    [Parameter(Mandatory=$false)]
    [string]$Auth0ClientId = "WBibIxpJlvVp64UIpfMqYxDyYC8XDWbU"
)

# Create a directory for the scripts
$ScriptsDir = "auth0_scripts"
if (-not (Test-Path $ScriptsDir)) {
    New-Item -ItemType Directory -Path $ScriptsDir | Out-Null
}

# Colors for better readability
function Write-ColorOutput($ForegroundColor) {
    $fc = $host.UI.RawUI.ForegroundColor
    $host.UI.RawUI.ForegroundColor = $ForegroundColor
    if ($args) { Write-Output $args }
    $host.UI.RawUI.ForegroundColor = $fc
}

Write-ColorOutput Green "Starting Auth0 implementation on $VpsHost with multiple scripts..."

# Create common script with functions used by all scripts
$commonScript = @'
#!/bin/bash

# Common variables and functions for Auth0 integration

AUTH0_CLIENT_ID="__AUTH0_CLIENT_ID__"
AUTH0_DOMAIN="dev-cloudtolocalllm.us.auth0.com"
WEB_ROOT="/opt/cloudtolocalllm/nginx/html"
TIMESTAMP=$(date +%Y%m%d%H%M%S)
BACKUP_DIR="/opt/cloudtolocalllm/backup_${TIMESTAMP}"

# Create a function for colored output
green() {
    echo -e "\033[0;32m$1\033[0m"
}

yellow() {
    echo -e "\033[1;33m$1\033[0m"
}

red() {
    echo -e "\033[0;31m$1\033[0m"
}

# Function to create backup
create_backup() {
    yellow "Creating backup in $BACKUP_DIR..."
    mkdir -p $BACKUP_DIR
    cp -r $WEB_ROOT/* $BACKUP_DIR/ 2>/dev/null || true
    green "Backup created successfully"
}
'@

$commonScript = $commonScript -replace "__AUTH0_CLIENT_ID__", $Auth0ClientId
Set-Content -Path "$ScriptsDir/common.sh" -Value $commonScript -NoNewline -Encoding utf8

# Create script to download local resources
$localResourcesScript = @'
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
'@

Set-Content -Path "$ScriptsDir/local_resources.sh" -Value $localResourcesScript -NoNewline -Encoding utf8

# Create script for Auth0 login page
$loginPageScript = @'
#!/bin/bash

# Source common functions
source /tmp/auth0_scripts/common.sh

yellow "Creating Auth0 login page..."

# Create custom login page with local styles
cat > $WEB_ROOT/login.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>CloudToLocalLLM - Login</title>
  <link rel="stylesheet" href="/css/bulma.min.css">
  <link rel="stylesheet" href="/css/fontawesome.min.css">
  <style>
    body {
      background: linear-gradient(135deg, #6e8efb, #a777e3);
      min-height: 100vh;
      display: flex;
      align-items: center;
      justify-content: center;
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
    }
    .login-button {
      width: 100%;
    }
    .footer-text {
      text-align: center;
      margin-top: 2rem;
      color: #888;
      font-size: 0.9rem;
    }
  </style>
  <script src="/js/auth0-spa-js.js"></script>
</head>
<body>
  <div class="login-container">
    <div class="logo">
      <img src="assets/assets/CloudToLocalLLM_logo.jpg" alt="CloudToLocalLLM Logo">
    </div>
    <h1 class="title is-4">Cloud-Based LLM Management</h1>
    
    <div id="login-container">
      <button id="login-button" class="button is-primary is-large login-button">
        <span class="icon">
          <i class="fas fa-sign-in-alt"></i>
        </span>
        <span>Login</span>
      </button>
    </div>
    
    <p class="footer-text">
      Run powerful Large Language Models locally with cloud-based management
    </p>
  </div>

  <script>
    document.getElementById('login-button').addEventListener('click', function() {
      const clientId = 'CLIENT_ID_PLACEHOLDER';
      const domain = 'dev-cloudtolocalllm.us.auth0.com';
      const redirectUri = window.location.origin + '/auth0-callback.html';
      
      window.location.href = 'https://' + domain + '/authorize' +
        '?response_type=code' +
        '&client_id=' + clientId +
        '&redirect_uri=' + encodeURIComponent(redirectUri) +
        '&scope=openid%20profile%20email';
    });
  </script>
</body>
</html>
EOF

# Replace Auth0 client ID in the login page
sed -i "s/CLIENT_ID_PLACEHOLDER/$AUTH0_CLIENT_ID/g" $WEB_ROOT/login.html
green "Created custom login page with Auth0 integration and local CSS"

# Create a separate Auth0 callback page
cat > $WEB_ROOT/auth0-callback.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Auth0 Callback</title>
  <script>
    // Handle Auth0 callback and redirect
    (function() {
      const urlParams = new URLSearchParams(window.location.search);
      const code = urlParams.get("code");
      const state = urlParams.get("state");
      
      if (code && state) {
        sessionStorage.setItem("auth0_code", code);
        sessionStorage.setItem("auth0_state", state);
        console.log("Auth0 callback processed, redirecting...");
      }
      
      window.location.href = "/?nocache=" + new Date().getTime();
    })();
  </script>
</head>
<body>
  <p>Processing Auth0 login...</p>
</body>
</html>
EOF
green "Created dedicated Auth0 callback page"
'@

Set-Content -Path "$ScriptsDir/login_page.sh" -Value $loginPageScript -NoNewline -Encoding utf8

# Create script to modify index.html
$indexModScript = @'
#!/bin/bash

# Source common functions
source /tmp/auth0_scripts/common.sh

yellow "Modifying index.html for Auth0 integration..."

# Add Auth0 callback handler to index.html
INDEX_FILE="$WEB_ROOT/index.html"
if [ -f "$INDEX_FILE" ]; then
    # Create backup of index.html if not already done
    if [ ! -f "$BACKUP_DIR/index.html.original" ]; then
        cp "$INDEX_FILE" "$BACKUP_DIR/index.html.original"
    fi
    
    # Create Auth0 callback script content
    cat > /tmp/auth0_callback.js << 'EOF'
<!-- Auth0 callback handler -->
<script>
  // Handle Auth0 callback redirect
  (function() {
    const urlParams = new URLSearchParams(window.location.search);
    const code = urlParams.get("code");
    const state = urlParams.get("state");
    
    if (code && state) {
      console.log("Auth0 callback detected, storing auth code");
      sessionStorage.setItem("auth0_code", code);
      sessionStorage.setItem("auth0_state", state);
      
      if (window.history && window.history.replaceState) {
        window.history.replaceState({}, document.title, "/");
      }
    }
  })();
</script>
EOF

    # Try various methods to insert the script before </head>
    # Method 1: Find the line number and split the file
    HEAD_LINE=$(grep -n "</head>" "$INDEX_FILE" | cut -d':' -f1 | head -n 1)
    if [ -n "$HEAD_LINE" ]; then
        yellow "Inserting Auth0 callback script at line $HEAD_LINE..."
        head -n $((HEAD_LINE-1)) "$INDEX_FILE" > /tmp/index.head
        cat /tmp/auth0_callback.js >> /tmp/index.head
        tail -n +$HEAD_LINE "$INDEX_FILE" >> /tmp/index.head
        
        # Replace original file
        mv /tmp/index.head "$INDEX_FILE"
        green "Added Auth0 callback handler to index.html"
    else
        # Method 2: Try sed as a fallback
        yellow "Line number method failed, trying sed method..."
        # Create a safe script with no special characters
        SAFE_SCRIPT=$(cat /tmp/auth0_callback.js | tr '\n' 'β' | sed 's/β/\\n/g')
        
        # Use awk for safer insertion
        awk '{print} /<\/head>/{print "<!-- Auth0 callback handler -->\n<script>\n  // Handle Auth0 callback redirect\n  (function() {\n    const urlParams = new URLSearchParams(window.location.search);\n    const code = urlParams.get(\"code\");\n    const state = urlParams.get(\"state\");\n    \n    if (code && state) {\n      console.log(\"Auth0 callback detected, storing auth code\");\n      sessionStorage.setItem(\"auth0_code\", code);\n      sessionStorage.setItem(\"auth0_state\", state);\n      \n      if (window.history && window.history.replaceState) {\n        window.history.replaceState({}, document.title, \"/\");\n      }\n    }\n  })();\n</script>"}' "$INDEX_FILE" > /tmp/index.new
        
        if [ -s "/tmp/index.new" ]; then
            mv /tmp/index.new "$INDEX_FILE"
            green "Added Auth0 callback handler to index.html using awk method"
        else
            red "Failed to modify index.html"
        fi
    fi
else
    red "Warning: index.html not found at $INDEX_FILE"
fi
'@

Set-Content -Path "$ScriptsDir/modify_index.sh" -Value $indexModScript -NoNewline -Encoding utf8

# Create script to restart services
$restartScript = @'
#!/bin/bash

# Source common functions
source /tmp/auth0_scripts/common.sh

yellow "Restarting services..."

# Navigate to Docker Compose directory
cd /opt/cloudtolocalllm || exit 1

# First try with docker-compose
if [ -f "docker-compose.yml" ]; then
    yellow "Using docker-compose to restart services..."
    docker-compose down || yellow "Warning: docker-compose down failed"
    docker-compose up -d || yellow "Warning: docker-compose up failed"
    green "Services restarted with docker-compose"
else
    # Try to restart manually
    yellow "docker-compose.yml not found, restarting containers manually..."
    
    # Find all nginx containers
    NGINX_CONTAINERS=$(docker ps -a | grep nginx | awk '{print $1}')
    if [ -n "$NGINX_CONTAINERS" ]; then
        yellow "Restarting Nginx containers..."
        for CONTAINER in $NGINX_CONTAINERS; do
            docker restart $CONTAINER || yellow "Warning: Failed to restart container $CONTAINER"
        done
        green "Restarted Nginx containers"
    else
        red "No Nginx containers found to restart"
    fi
    
    # Find ALL containers associated with the application if possible
    APP_CONTAINERS=$(docker ps -a --filter "label=com.docker.compose.project=cloudtolocalllm" -q)
    if [ -n "$APP_CONTAINERS" ]; then
        yellow "Restarting all application containers..."
        for CONTAINER in $APP_CONTAINERS; do
            docker restart $CONTAINER || yellow "Warning: Failed to restart container $CONTAINER"
        done
        green "Restarted all application containers"
    fi
fi

green "All services restarted successfully"
'@

Set-Content -Path "$ScriptsDir/restart_services.sh" -Value $restartScript -NoNewline -Encoding utf8

# Create main script to be executed on VPS
$vpsMainScript = @'
#!/bin/bash
set -e

echo "===== Auth0 Implementation with Local Resources ====="

# Source common functions
source /tmp/auth0_scripts/common.sh

# Create backup
create_backup

# Execute each step 
echo "===== Step 1: Setting up local resources ====="
bash /tmp/auth0_scripts/local_resources.sh
if [ $? -ne 0 ]; then
    red "Step 1 failed. Exiting."
    exit 1
fi

echo "===== Step 2: Creating Auth0 login page ====="
bash /tmp/auth0_scripts/login_page.sh
if [ $? -ne 0 ]; then
    red "Step 2 failed. Exiting."
    exit 1
fi

echo "===== Step 3: Modifying index.html ====="
bash /tmp/auth0_scripts/modify_index.sh
if [ $? -ne 0 ]; then
    red "Step 3 failed. Exiting."
    exit 1
fi

echo "===== Step 4: Restarting services ====="
bash /tmp/auth0_scripts/restart_services.sh
if [ $? -ne 0 ]; then
    red "Step 4 failed. Exiting."
    exit 1
fi

green "===== Auth0 implementation completed successfully! ====="
green "Login page available at: /login.html"
'@

Set-Content -Path "$ScriptsDir/main.sh" -Value $vpsMainScript -NoNewline -Encoding utf8

# Define function to convert scripts to Unix format
function Convert-ToUnixFormat {
    param (
        [string]$FilePath
    )
    
    $content = Get-Content -Path $FilePath -Raw
    $unixContent = $content -replace "`r`n", "`n"
    Set-Content -Path $FilePath -Value $unixContent -NoNewline -Encoding utf8
}

# Convert all scripts to Unix format
Get-ChildItem -Path $ScriptsDir -Filter "*.sh" | ForEach-Object {
    Convert-ToUnixFormat -FilePath $_.FullName
    Write-ColorOutput Yellow "Converted $($_.Name) to Unix format"
}

# Upload scripts to VPS
Write-ColorOutput Yellow "Uploading scripts to VPS..."
ssh -i $SshKeyPath $VpsHost "mkdir -p /tmp/auth0_scripts"
Get-ChildItem -Path $ScriptsDir -Filter "*.sh" | ForEach-Object {
    scp -i $SshKeyPath $_.FullName "${VpsHost}:/tmp/auth0_scripts/"
    ssh -i $SshKeyPath $VpsHost "chmod +x /tmp/auth0_scripts/$($_.Name)"
    Write-ColorOutput Green "Uploaded and made executable: $($_.Name)"
}

# Run the main script
Write-ColorOutput Yellow "Running Auth0 implementation script on VPS..."
ssh -i $SshKeyPath $VpsHost "sudo bash /tmp/auth0_scripts/main.sh"

Write-ColorOutput Green "Script execution completed."
Write-ColorOutput Yellow "Login page available at: https://cloudtolocalllm.online/login.html" 