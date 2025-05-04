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