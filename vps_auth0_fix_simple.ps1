param (
    [Parameter(Mandatory=$true)]
    [string]$VpsHost,
    
    [Parameter(Mandatory=$false)]
    [string]$SshKeyPath = "$env:USERPROFILE\.ssh\id_rsa",
    
    [Parameter(Mandatory=$false)]
    [string]$Auth0ClientId = "WBibIxpJlvVp64UIpfMqYxDyYC8XDWbU"
)

# Create the VPS script
$vpsScript = @'
#!/bin/bash
set -e

# Set Auth0 client ID
AUTH0_CLIENT_ID="__AUTH0_CLIENT_ID__"
AUTH0_DOMAIN="dev-cloudtolocalllm.us.auth0.com"

echo "Starting Auth0 implementation..."

# Create backup
TIMESTAMP=$(date +%Y%m%d%H%M%S)
BACKUP_DIR="/opt/cloudtolocalllm/backup_${TIMESTAMP}"
mkdir -p $BACKUP_DIR
echo "Created backup directory: $BACKUP_DIR"

# Backup the original files
cp -r /opt/cloudtolocalllm/nginx/html/* $BACKUP_DIR/ 2>/dev/null || true
echo "Copied website files to backup"

# Function to restart all containers and clear caches
restart_and_clear_cache() {
    echo "Restarting all containers and clearing caches..."
    
    # First stop all running containers
    cd /opt/cloudtolocalllm || return
    
    if [ -f "docker-compose.yml" ]; then
        echo "Stopping all services with docker-compose..."
        docker-compose down || echo "Warning: docker-compose down failed"
    else
        echo "docker-compose.yml not found, stopping containers manually..."
        # Get all containers in the project
        CONTAINERS=$(docker ps -a --filter "label=com.docker.compose.project=cloudtolocalllm" -q)
        if [ -n "$CONTAINERS" ]; then
            docker stop $CONTAINERS || echo "Warning: Failed to stop some containers"
        else
            # Try to find Nginx containers
            NGINX_CONTAINERS=$(docker ps -a | grep -i nginx | awk '{print $1}')
            if [ -n "$NGINX_CONTAINERS" ]; then
                docker stop $NGINX_CONTAINERS || echo "Warning: Failed to stop Nginx containers"
            fi
        fi
    fi
    
    # Clear Docker cache
    echo "Clearing Docker cache..."
    docker system prune -f || echo "Warning: Failed to clear Docker cache"
    
    # Clear Nginx cache if it exists
    if [ -d "/opt/cloudtolocalllm/nginx/cache" ]; then
        echo "Clearing Nginx cache..."
        rm -rf /opt/cloudtolocalllm/nginx/cache/*
        mkdir -p /opt/cloudtolocalllm/nginx/cache
    fi
    
    # Add cache-busting query parameters to all HTML and JS files
    CACHE_BUSTER=$(date +%s)
    echo "Adding cache buster ($CACHE_BUSTER) to HTML and JS files..."
    
    # Update references in HTML files
    find /opt/cloudtolocalllm/nginx/html -name "*.html" -type f -exec sed -i "s/\.js/\.js?v=$CACHE_BUSTER/g" {} \; 2>/dev/null || true
    find /opt/cloudtolocalllm/nginx/html -name "*.html" -type f -exec sed -i "s/\.css/\.css?v=$CACHE_BUSTER/g" {} \; 2>/dev/null || true
    
    # Add no-cache headers to Nginx configuration
    for CONFIG_DIR in "/opt/cloudtolocalllm/nginx/conf.d" "/etc/nginx/conf.d" "/opt/cloudtolocalllm/nginx-proxy/conf.d"; do
        if [ -d "$CONFIG_DIR" ]; then
            echo "Adding no-cache headers to $CONFIG_DIR/cache_control.conf"
            cat > "$CONFIG_DIR/cache_control.conf" << 'EOF'
# Disable browser caching
add_header Cache-Control "no-store, no-cache, must-revalidate, proxy-revalidate, max-age=0";
add_header Pragma "no-cache";
add_header Expires "0";
EOF
            break
        fi
    done
    
    # Restart all services
    if [ -f "/opt/cloudtolocalllm/docker-compose.yml" ]; then
        echo "Starting all services with docker-compose..."
        cd /opt/cloudtolocalllm
        docker-compose up -d || echo "Warning: docker-compose up failed"
    else
        echo "Restarting containers manually..."
        if [ -n "$CONTAINERS" ]; then
            docker start $CONTAINERS || echo "Warning: Failed to start some containers"
        elif [ -n "$NGINX_CONTAINERS" ]; then
            docker start $NGINX_CONTAINERS || echo "Warning: Failed to start Nginx containers"
        fi
    fi
    
    echo "All services restarted and caches cleared!"
}

# Create custom login page with inline styles only
cat > /opt/cloudtolocalllm/nginx/html/login.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>CloudToLocalLLM - Login</title>
  <!-- No-cache meta tags -->
  <meta http-equiv="Cache-Control" content="no-cache, no-store, must-revalidate">
  <meta http-equiv="Pragma" content="no-cache">
  <meta http-equiv="Expires" content="0">
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
</head>
<body>
  <div class="login-container">
    <div class="logo">
      <img src="assets/assets/CloudToLocalLLM_logo.jpg" alt="CloudToLocalLLM Logo">
    </div>
    <h1 class="title">Cloud-Based LLM Management</h1>
    
    <div id="login-container">
      <button id="login-button" class="login-button">Login</button>
    </div>
    
    <p class="footer-text">
      Run powerful Large Language Models locally with cloud-based management
    </p>
  </div>

  <script>
    document.getElementById('login-button').addEventListener('click', function() {
      // Replace with your Auth0 configuration
      const clientId = '__AUTH0_CLIENT_ID__';
      const domain = 'dev-cloudtolocalllm.us.auth0.com';
      const redirectUri = window.location.origin + '/auth0-callback.html';
      
      // Redirect to Auth0 login
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
sed -i "s/__AUTH0_CLIENT_ID__/$AUTH0_CLIENT_ID/g" /opt/cloudtolocalllm/nginx/html/login.html
echo "Created custom login page with Auth0 integration"

# Add Auth0 callback handler to index.html
INDEX_FILE="/opt/cloudtolocalllm/nginx/html/index.html"
if [ -f "$INDEX_FILE" ]; then
    # Create backup of index.html
    cp "$INDEX_FILE" "$BACKUP_DIR/index.html.original"
    
    # Add no-cache meta tags to the head section
    if grep -q "<head>" "$INDEX_FILE"; then
        # Insert no-cache meta tags after the opening head tag
        NO_CACHE_TAGS='
  <!-- No-cache meta tags -->
  <meta http-equiv="Cache-Control" content="no-cache, no-store, must-revalidate">
  <meta http-equiv="Pragma" content="no-cache">
  <meta http-equiv="Expires" content="0">'
        
        # Use sed to insert after <head> tag
        sed -i "s|<head>|<head>${NO_CACHE_TAGS}|" "$INDEX_FILE"
        echo "Added no-cache meta tags to index.html"
    fi
    
    # Create Auth0 callback script file
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
      // Store in sessionStorage for the app to access
      sessionStorage.setItem("auth0_code", code);
      sessionStorage.setItem("auth0_state", state);
      
      // Clean up URL
      if (window.history && window.history.replaceState) {
        window.history.replaceState({}, document.title, "/");
      }
    }
  })();
</script>
EOF

    # Use awk to insert the script before </head>
    awk '/<\/head>/{system("cat /tmp/auth0_callback.js"); print; next} {print}' "$INDEX_FILE" > /tmp/index.html.new
    
    # Check if the modification worked
    if [ -s "/tmp/index.html.new" ]; then
        mv /tmp/index.html.new "$INDEX_FILE"
        echo "Added Auth0 callback handler to index.html"
    else
        echo "Warning: Failed to modify index.html, trying alternative approach"
        
        # Try another approach - using search and replace
        HEAD_LINE=$(grep -n "</head>" "$INDEX_FILE" | cut -d':' -f1 | head -n 1)
        if [ -n "$HEAD_LINE" ]; then
            # Split the file
            head -n $((HEAD_LINE-1)) "$INDEX_FILE" > /tmp/index.head
            cat /tmp/auth0_callback.js >> /tmp/index.head
            tail -n +$HEAD_LINE "$INDEX_FILE" >> /tmp/index.head
            
            # Replace original file
            mv /tmp/index.head "$INDEX_FILE"
            echo "Added Auth0 callback handler to index.html using alternative approach"
        else
            echo "Warning: Could not find </head> tag in index.html"
        fi
    fi
else
    echo "Warning: index.html not found at $INDEX_FILE"
fi

# Create a separate Auth0 callback page
cat > /opt/cloudtolocalllm/nginx/html/auth0-callback.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Auth0 Callback</title>
  <!-- No-cache meta tags -->
  <meta http-equiv="Cache-Control" content="no-cache, no-store, must-revalidate">
  <meta http-equiv="Pragma" content="no-cache">
  <meta http-equiv="Expires" content="0">
  <script>
    // Handle Auth0 callback and redirect
    (function() {
      const urlParams = new URLSearchParams(window.location.search);
      const code = urlParams.get("code");
      const state = urlParams.get("state");
      
      if (code && state) {
        // Store in sessionStorage
        sessionStorage.setItem("auth0_code", code);
        sessionStorage.setItem("auth0_state", state);
        console.log("Auth0 callback processed, redirecting...");
      }
      
      // Redirect to main page
      window.location.href = "/?nocache=" + new Date().getTime();
    })();
  </script>
</head>
<body>
  <p>Processing Auth0 login...</p>
</body>
</html>
EOF
echo "Created dedicated Auth0 callback page"

# Disable CSP to avoid stylesheet loading issues
# First, let's check if we need to modify the nginx config
if [ -d "/opt/cloudtolocalllm/nginx/conf.d" ]; then
    # Create a simple configuration file to set CSP
    cat > "/opt/cloudtolocalllm/nginx/conf.d/security_headers.conf" << 'EOF'
# Allow all content sources to fix CSP issues
add_header Content-Security-Policy "default-src * 'unsafe-inline' 'unsafe-eval'; img-src * data:; font-src * data:;" always;
EOF
    echo "Created permissive CSP header configuration"
else
    echo "Warning: Nginx conf.d directory not found at /opt/cloudtolocalllm/nginx/conf.d"
    echo "Trying alternate location..."
    
    # Try to find and modify Nginx configuration
    for CONFIG_DIR in "/etc/nginx/conf.d" "/opt/cloudtolocalllm/nginx-proxy/conf.d"; do
        if [ -d "$CONFIG_DIR" ]; then
            echo "Found alternative Nginx config directory: $CONFIG_DIR"
            cat > "$CONFIG_DIR/security_headers.conf" << 'EOF'
# Allow all content sources to fix CSP issues
add_header Content-Security-Policy "default-src * 'unsafe-inline' 'unsafe-eval'; img-src * data:; font-src * data:;" always;
EOF
            echo "Created permissive CSP header configuration in $CONFIG_DIR"
            break
        fi
    done
fi

# Now restart everything and clear all caches
restart_and_clear_cache

echo "Auth0 implementation completed"
echo "Custom login page available at: /login.html"
echo "All services restarted and caches cleared"
echo "Note: You may still need to clear your browser cache to see changes"
'@

# Replace placeholder with actual Auth0 client ID
$vpsScript = $vpsScript -replace "__AUTH0_CLIENT_ID__", $Auth0ClientId

# Convert to Unix line endings (LF)
$vpsScript = $vpsScript -replace "`r`n", "`n"
$vpsScriptPath = [System.IO.Path]::GetTempFileName()
Set-Content -Path $vpsScriptPath -Value $vpsScript -NoNewline -Encoding utf8

# Display info to the user
Write-Host "Uploading and running simplified Auth0 implementation script on $VpsHost"
Write-Host "Using Auth0 Client ID: $Auth0ClientId"

# Upload and run the script on the VPS
Write-Host "Uploading script to VPS..."
scp -i $SshKeyPath $vpsScriptPath "${VpsHost}:/tmp/auth0_simple_fix.sh"
ssh -i $SshKeyPath $VpsHost "chmod +x /tmp/auth0_simple_fix.sh"
Write-Host "Running script on VPS..."
ssh -i $SshKeyPath $VpsHost "sudo /tmp/auth0_simple_fix.sh"

# Clean up
Remove-Item -Force $vpsScriptPath
Write-Host "Script execution completed."
Write-Host "Login page available at: https://cloudtolocalllm.online/login.html"
Write-Host "All services have been restarted and caches cleared." 