param (
    [Parameter(Mandatory=$true)]
    [string]$VpsHost,
    
    [Parameter(Mandatory=$false)]
    [string]$SshKeyPath = "$env:USERPROFILE\.ssh\id_rsa"
)

# Colors for better readability
function Write-ColorOutput($ForegroundColor) {
    $fc = $host.UI.RawUI.ForegroundColor
    $host.UI.RawUI.ForegroundColor = $ForegroundColor
    if ($args) { Write-Output $args }
    $host.UI.RawUI.ForegroundColor = $fc
}

Write-ColorOutput Green "Adding 'Under Construction' notice to CloudToLocalLLM on $VpsHost..."

# Create the script to add construction notice
$constructionScript = @'
#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}Adding 'Under Construction' notice to the website...${NC}"

# Create simple index.html with under construction notice
echo -e "${YELLOW}Creating main page with construction notice...${NC}"
cat > /tmp/index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>CloudToLocalLLM - UNDER CONSTRUCTION</title>
  <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bulma@0.9.4/css/bulma.min.css">
  <style>
    .hero { 
      background: linear-gradient(135deg, #6e8efb, #a777e3);
      color: white;
    }
    .container { max-width: 800px; margin: 0 auto; padding: 20px; }
    .construction-banner {
      background-color: #ffdd57;
      color: rgba(0, 0, 0, 0.7);
      padding: 1rem;
      text-align: center;
      font-weight: bold;
      font-size: 1.25rem;
      position: relative;
      z-index: 30;
      box-shadow: 0 2px 5px rgba(0,0,0,0.2);
    }
    .construction-icon {
      display: inline-block;
      margin-right: 10px;
    }
    .feature-card {
      height: 100%;
      display: flex;
      flex-direction: column;
    }
    .feature-card .card-content {
      flex-grow: 1;
    }
  </style>
</head>
<body>
  <div class="construction-banner">
    <span class="construction-icon">🚧</span> WEBSITE UNDER CONSTRUCTION <span class="construction-icon">🚧</span>
    <p class="is-size-6 mt-2">The system is being set up and will be available soon.</p>
  </div>
  
  <section class="hero is-medium">
    <div class="hero-body">
      <div class="container">
        <h1 class="title is-1">CloudToLocalLLM</h1>
        <h2 class="subtitle is-3">Run powerful Large Language Models locally with cloud-based management</h2>
        <div class="buttons mt-5">
          <a href="/login.html" class="button is-primary is-large">
            <strong>Login</strong>
          </a>
          <a href="https://github.com/thrightguy/CloudToLocalLLM" class="button is-light is-large">
            GitHub
          </a>
        </div>
      </div>
    </div>
  </section>

  <section class="section">
    <div class="container">
      <h2 class="title is-2 has-text-centered mb-6">What is CloudToLocalLLM?</h2>
      <p class="subtitle has-text-centered mb-6">
        CloudToLocalLLM is an innovative platform that lets you run AI language models on your own computer 
        while managing them through a simple cloud interface.
      </p>
      
      <div class="columns mt-6">
        <div class="column">
          <div class="card feature-card">
            <div class="card-content">
              <p class="title is-4">Run Models Locally</p>
              <p class="subtitle is-6">
                Keep your data private by running AI models directly on your own hardware. 
                No need to send sensitive information to third-party servers.
              </p>
            </div>
          </div>
        </div>
        
        <div class="column">
          <div class="card feature-card">
            <div class="card-content">
              <p class="title is-4">Cloud Management</p>
              <p class="subtitle is-6">
                Easily manage your models, update settings, and monitor performance 
                through our intuitive cloud dashboard.
              </p>
            </div>
          </div>
        </div>
        
        <div class="column">
          <div class="card feature-card">
            <div class="card-content">
              <p class="title is-4">Cost Effective</p>
              <p class="subtitle is-6">
                Eliminate expensive API fees and cloud computing costs by leveraging 
                your existing hardware.
              </p>
            </div>
          </div>
        </div>
      </div>
    </div>
  </section>

  <footer class="footer">
    <div class="content has-text-centered">
      <p>
        <strong>CloudToLocalLLM</strong> - Currently under construction. Expected launch: Q2 2025.
        <br>
        <small>© 2024-2025 CloudToLocalLLM. All rights reserved.</small>
      </p>
    </div>
  </footer>
</body>
</html>
EOF

# Update the Auth0 login page with construction notice
echo -e "${YELLOW}Updating login page with construction notice...${NC}"
cat > /tmp/login.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>CloudToLocalLLM - Login (UNDER CONSTRUCTION)</title>
  <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bulma@0.9.4/css/bulma.min.css">
  <script src="https://cdn.auth0.com/js/auth0-spa-js/2.0/auth0-spa-js.production.js"></script>
  <style>
    .hero { 
      background: linear-gradient(135deg, #6e8efb, #a777e3);
      color: white;
    }
    .container { max-width: 800px; margin: 0 auto; padding: 20px; }
    .login-btn { margin-top: 20px; }
    .profile { 
      background: white;
      padding: 20px;
      border-radius: 6px;
      margin-top: 20px;
      box-shadow: 0 0.5em 1em -0.125em rgba(10,10,10,.1), 0 0 0 1px rgba(10,10,10,.02);
    }
    .construction-banner {
      background-color: #ffdd57;
      color: rgba(0, 0, 0, 0.7);
      padding: 1rem;
      text-align: center;
      font-weight: bold;
      font-size: 1.25rem;
      position: relative;
      z-index: 30;
      box-shadow: 0 2px 5px rgba(0,0,0,0.2);
    }
    .construction-icon {
      display: inline-block;
      margin-right: 10px;
    }
  </style>
</head>
<body>
  <div class="construction-banner">
    <span class="construction-icon">🚧</span> WEBSITE UNDER CONSTRUCTION <span class="construction-icon">🚧</span>
    <p class="is-size-6 mt-2">The authentication system is being set up and will be available soon.</p>
  </div>

  <section class="hero is-medium">
    <div class="hero-body">
      <div class="container">
        <h1 class="title is-1">CloudToLocalLLM</h1>
        <h2 class="subtitle is-3">Run powerful Large Language Models locally with cloud-based management</h2>
        <div id="login-container">
          <button id="login" class="button is-large is-primary login-btn">Log In with Google</button>
          <p class="mt-3 has-text-white">
            <a href="/" class="has-text-white"><strong>← Back to Home</strong></a>
          </p>
        </div>
        <div id="profile-container" class="profile" style="display: none;">
          <h2 class="title is-4">User Profile</h2>
          <div id="profile-details">
            <p><strong>Name:</strong> <span id="profile-name"></span></p>
            <p><strong>Email:</strong> <span id="profile-email"></span></p>
            <p><strong>User ID:</strong> <span id="profile-id"></span></p>
          </div>
          <div class="buttons is-right">
            <button id="logout" class="button is-danger">Log Out</button>
          </div>
        </div>
      </div>
    </div>
  </section>

  <footer class="footer">
    <div class="content has-text-centered">
      <p>
        <strong>CloudToLocalLLM</strong> - Currently under construction. Expected launch: Q2 2025.
        <br>
        <small>© 2024-2025 CloudToLocalLLM. All rights reserved.</small>
      </p>
    </div>
  </footer>

  <script>
    let auth0Client = null;

    const configureClient = async () => {
      auth0Client = await createAuth0Client({
        domain: 'dev-cloudtolocalllm.us.auth0.com',
        clientId: 'your_auth0_client_id',
        authorizationParams: {
          redirect_uri: window.location.origin,
          audience: 'https://api.cloudtolocalllm.online'
        }
      });
    };

    const updateUI = async () => {
      const isAuthenticated = await auth0Client.isAuthenticated();

      document.getElementById('login-container').style.display = isAuthenticated ? 'none' : 'block';
      document.getElementById('profile-container').style.display = isAuthenticated ? 'block' : 'none';

      if (isAuthenticated) {
        const user = await auth0Client.getUser();
        document.getElementById('profile-name').textContent = user.name;
        document.getElementById('profile-email').textContent = user.email;
        document.getElementById('profile-id').textContent = user.sub;
      }
    };

    const login = async () => {
      await auth0Client.loginWithRedirect();
    };

    const logout = () => {
      auth0Client.logout({
        logoutParams: {
          returnTo: window.location.origin
        }
      });
    };

    window.onload = async () => {
      await configureClient();

      // Check if user was just redirected after login
      const query = window.location.search;
      if (query.includes("code=") && query.includes("state=")) {
        // Process the login state
        await auth0Client.handleRedirectCallback();
        window.history.replaceState({}, document.title, "/");
      }

      await updateUI();

      // Setup event listeners
      document.getElementById('login').addEventListener('click', login);
      document.getElementById('logout').addEventListener('click', logout);
    };
  </script>
</body>
</html>
EOF

# Copy HTML files to Nginx web directory
echo -e "${YELLOW}Deploying HTML files...${NC}"
docker cp /tmp/index.html nginx-proxy:/usr/share/nginx/html/index.html
docker cp /tmp/login.html nginx-proxy:/usr/share/nginx/html/login.html

echo -e "${GREEN}Construction notice has been added to the website!${NC}"
echo -e "${YELLOW}Main portal:${NC} ${GREEN}https://cloudtolocalllm.online${NC}"
echo -e "${YELLOW}Login page:${NC} ${GREEN}https://cloudtolocalllm.online/login.html${NC}"
'@

# Convert to Unix line endings (LF)
$constructionScript = $constructionScript -replace "`r`n", "`n"
$constructionScriptPath = [System.IO.Path]::GetTempFileName()
Set-Content -Path $constructionScriptPath -Value $constructionScript -NoNewline -Encoding utf8

# Upload and run the script
Write-ColorOutput Yellow "Uploading and running construction notice script on VPS..."
scp -i $SshKeyPath $constructionScriptPath "${VpsHost}:/tmp/add_construction_notice.sh"
ssh -i $SshKeyPath $VpsHost "chmod +x /tmp/add_construction_notice.sh && sudo /tmp/add_construction_notice.sh"

# Clean up
Write-ColorOutput Yellow "Cleaning up temporary files..."
Remove-Item -Force $constructionScriptPath

Write-ColorOutput Green "Construction notice has been added to the website!"
Write-ColorOutput Yellow "Your website is now accessible at:"
Write-Host "Main portal (with notice): https://cloudtolocalllm.online"
Write-Host "Login page (with notice): https://cloudtolocalllm.online/login.html" 