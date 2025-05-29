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

Write-ColorOutput Green "Updating platform information on CloudToLocalLLM website on $VpsHost..."

# Create the script to update platform information
$updateScript = @'
#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}Updating platform information on the website...${NC}"

# Create updated index.html with platform information
echo -e "${YELLOW}Updating main page with platform information...${NC}"
cat > /tmp/index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>CloudToLocalLLM - UNDER CONSTRUCTION</title>
  <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bulma@0.9.4/css/bulma.min.css">
  <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/5.15.4/css/all.min.css">
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
    .platform-section {
      background-color: #f5f5f5;
      padding: 2rem 0;
    }
    .platform-icon {
      font-size: 2.5rem;
      margin-bottom: 1rem;
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
          <a href="https://github.com/imrightguy/CloudToLocalLLM" class="button is-light is-large">
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

  <section class="section platform-section">
    <div class="container">
      <h2 class="title is-2 has-text-centered mb-6">Available Platforms</h2>
      <p class="subtitle has-text-centered mb-6">
        CloudToLocalLLM will initially be available on the following platforms:
      </p>
      
      <div class="columns is-centered mt-5">
        <div class="column is-2 has-text-centered">
          <div class="platform-icon">
            <i class="fab fa-windows"></i>
          </div>
          <p class="is-size-5 has-text-weight-bold">Windows</p>
        </div>
        
        <div class="column is-2 has-text-centered">
          <div class="platform-icon">
            <i class="fab fa-ubuntu"></i>
          </div>
          <p class="is-size-5 has-text-weight-bold">Ubuntu</p>
        </div>
        
        <div class="column is-2 has-text-centered">
          <div class="platform-icon">
            <i class="fab fa-android"></i>
          </div>
          <p class="is-size-5 has-text-weight-bold">Android</p>
        </div>
        
        <div class="column is-2 has-text-centered">
          <div class="platform-icon">
            <i class="fas fa-globe"></i>
          </div>
          <p class="is-size-5 has-text-weight-bold">Web</p>
        </div>
      </div>
      
      <p class="has-text-centered mt-5">
        <strong>Note:</strong> Support for other platforms may be added in future releases.
      </p>
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

# Update login page with platform information banner
echo -e "${YELLOW}Updating login page with platform information...${NC}"
cat > /tmp/login.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>CloudToLocalLLM - Login (UNDER CONSTRUCTION)</title>
  <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bulma@0.9.4/css/bulma.min.css">
  <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/5.15.4/css/all.min.css">
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
    .platform-info {
      background-color: #f5f5f5;
      padding: 1rem;
      border-radius: 6px;
      margin-top: 20px;
    }
    .platform-icons {
      font-size: 1.5rem;
      margin: 0.5rem 0;
    }
    .platform-icons i {
      margin: 0 0.5rem;
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
          
          <div class="platform-info">
            <p class="has-text-centered has-text-weight-bold">Available on:</p>
            <div class="platform-icons has-text-centered">
              <i class="fab fa-windows"></i>
              <i class="fab fa-ubuntu"></i>
              <i class="fab fa-android"></i>
              <i class="fas fa-globe"></i>
            </div>
            <p class="has-text-centered is-size-7">Windows, Ubuntu, Android, and Web</p>
          </div>
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

# Copy updated HTML files to Nginx web directory
echo -e "${YELLOW}Deploying updated HTML files...${NC}"
docker cp /tmp/index.html nginx-proxy:/usr/share/nginx/html/index.html
docker cp /tmp/login.html nginx-proxy:/usr/share/nginx/html/login.html

echo -e "${GREEN}Platform information has been added to the website!${NC}"
echo -e "${YELLOW}Main portal:${NC} ${GREEN}https://cloudtolocalllm.online${NC}"
echo -e "${YELLOW}Login page:${NC} ${GREEN}https://cloudtolocalllm.online/login.html${NC}"
'@

# Convert to Unix line endings (LF)
$updateScript = $updateScript -replace "`r`n", "`n"
$updateScriptPath = [System.IO.Path]::GetTempFileName()
Set-Content -Path $updateScriptPath -Value $updateScript -NoNewline -Encoding utf8

# Upload and run the script
Write-ColorOutput Yellow "Uploading and running platform information update script on VPS..."
scp -i $SshKeyPath $updateScriptPath "${VpsHost}:/tmp/update_platform_info.sh"
ssh -i $SshKeyPath $VpsHost "chmod +x /tmp/update_platform_info.sh && sudo /tmp/update_platform_info.sh"

# Clean up
Write-ColorOutput Yellow "Cleaning up temporary files..."
Remove-Item -Force $updateScriptPath

Write-ColorOutput Green "Platform information has been added to the website!"
Write-ColorOutput Yellow "Your website is now accessible at:"
Write-Host "Main portal: https://cloudtolocalllm.online"
Write-Host "Login page: https://cloudtolocalllm.online/login.html" 