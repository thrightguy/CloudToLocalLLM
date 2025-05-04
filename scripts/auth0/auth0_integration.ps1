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

Write-ColorOutput Green "Setting up Auth0 integration on $VpsHost..."

# Create the Auth0 integration script
$auth0Script = @'
#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}Setting up Auth0 integration...${NC}"

# Create API service directly in container
echo -e "${YELLOW}Configuring API service in container...${NC}"
docker exec -i api-service sh -c "mkdir -p /app"

# Create package.json with Auth0 dependencies
echo -e "${YELLOW}Creating package.json with Auth0 dependencies...${NC}"
cat > /tmp/package.json << 'EOF'
{
  "name": "cloudtolocalllm-api",
  "version": "1.0.0",
  "description": "API service for CloudToLocalLLM with Auth0 integration",
  "main": "server.js",
  "scripts": {
    "start": "node server.js"
  },
  "dependencies": {
    "express": "^4.18.2",
    "express-jwt": "^8.4.1",
    "express-jwt-authz": "^2.4.1",
    "jwks-rsa": "^3.0.1",
    "cors": "^2.8.5",
    "pg": "^8.10.0",
    "dotenv": "^16.0.3",
    "axios": "^1.3.4"
  }
}
EOF

# Copy package.json to container
docker cp /tmp/package.json api-service:/app/

# Create .env file with Auth0 configuration
cat > /tmp/.env << 'EOF'
AUTH0_DOMAIN=dev-cloudtolocalllm.us.auth0.com
AUTH0_API_AUDIENCE=https://api.cloudtolocalllm.online
AUTH0_ISSUER=https://dev-cloudtolocalllm.us.auth0.com/
AUTH0_CLIENT_ID=your_auth0_client_id
AUTH0_CLIENT_SECRET=your_auth0_client_secret
ADMIN_EMAIL=christopher.maltais@gmail.com
EOF

# Copy .env file to container
docker cp /tmp/.env api-service:/app/

# Create server.js with Auth0 integration
echo -e "${YELLOW}Creating API server with Auth0 integration...${NC}"
cat > /tmp/server.js << 'EOF'
const express = require('express');
const cors = require('cors');
const { expressjwt: jwt } = require('express-jwt');
const jwksRsa = require('jwks-rsa');
const jwtAuthz = require('express-jwt-authz');
const axios = require('axios');
const { Pool } = require('pg');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 8080;

// Auth0 configuration
const domain = process.env.AUTH0_DOMAIN;
const audience = process.env.AUTH0_API_AUDIENCE;
const issuer = process.env.AUTH0_ISSUER;
const adminEmail = process.env.ADMIN_EMAIL;

// Database connection
const pool = new Pool({
  user: 'postgres',
  host: 'db-service',
  database: 'cloudtolocalllm',
  password: 'securepassword',
  port: 5432,
});

// Middleware
app.use(express.json());
app.use(cors({
  origin: '*',
  methods: ['GET', 'POST', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization']
}));

// Configure JWT validation middleware
const checkJwt = jwt({
  secret: jwksRsa.expressJwtSecret({
    cache: true,
    rateLimit: true,
    jwksRequestsPerMinute: 5,
    jwksUri: `https://${domain}/.well-known/jwks.json`
  }),
  audience: audience,
  issuer: issuer,
  algorithms: ['RS256']
});

// Create tables if they don't exist
async function initDb() {
  try {
    await pool.query(`
      CREATE TABLE IF NOT EXISTS users (
        id SERIAL PRIMARY KEY,
        auth0_id VARCHAR(100) UNIQUE NOT NULL,
        email VARCHAR(255) UNIQUE NOT NULL,
        name VARCHAR(255),
        is_admin BOOLEAN DEFAULT FALSE,
        created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
      );

      CREATE TABLE IF NOT EXISTS user_containers (
        id SERIAL PRIMARY KEY,
        user_id INTEGER REFERENCES users(id),
        container_id VARCHAR(255),
        container_name VARCHAR(255),
        status VARCHAR(50),
        created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
      );
    `);
    
    console.log('Database tables initialized');
  } catch (err) {
    console.error('Database initialization error:', err);
  }
}

// Initialize database
initDb();

// Main status endpoint
app.get('/', (req, res) => {
  res.json({
    status: 'online',
    message: 'CloudToLocalLLM API is running with Auth0 integration',
    timestamp: new Date().toISOString()
  });
});

// Get user metadata from Auth0
app.get('/auth/profile', checkJwt, async (req, res) => {
  try {
    const auth0Id = req.auth.sub;
    
    // Check if user exists in database
    let userQuery = await pool.query(
      'SELECT * FROM users WHERE auth0_id = $1',
      [auth0Id]
    );
    
    // If user doesn't exist, create new user record
    if (userQuery.rows.length === 0) {
      // Get user info from Auth0
      const userInfo = req.auth;
      const email = userInfo.email || '';
      const name = userInfo.name || '';
      
      // Check if user is admin
      const isAdmin = email === adminEmail;
      
      // Create user in database
      const newUserResult = await pool.query(
        'INSERT INTO users (auth0_id, email, name, is_admin) VALUES ($1, $2, $3, $4) RETURNING *',
        [auth0Id, email, name, isAdmin]
      );
      
      userQuery = { rows: [newUserResult.rows[0]] };
    }
    
    res.json({
      user: userQuery.rows[0],
      auth0: req.auth
    });
  } catch (err) {
    console.error('Profile error:', err);
    res.status(500).json({ message: 'Server error' });
  }
});

// Check if user is admin
app.get('/auth/admin', checkJwt, async (req, res) => {
  try {
    const auth0Id = req.auth.sub;
    
    const userQuery = await pool.query(
      'SELECT is_admin FROM users WHERE auth0_id = $1',
      [auth0Id]
    );
    
    if (userQuery.rows.length === 0) {
      return res.status(404).json({ message: 'User not found' });
    }
    
    res.json({
      isAdmin: userQuery.rows[0].is_admin
    });
  } catch (err) {
    console.error('Admin check error:', err);
    res.status(500).json({ message: 'Server error' });
  }
});

// Container management endpoints (protected, admin only)
app.post('/containers/create', checkJwt, async (req, res) => {
  try {
    const auth0Id = req.auth.sub;
    
    // Check if user is admin or creating for self
    const userQuery = await pool.query(
      'SELECT id, is_admin FROM users WHERE auth0_id = $1',
      [auth0Id]
    );
    
    if (userQuery.rows.length === 0) {
      return res.status(404).json({ message: 'User not found' });
    }
    
    const { id: userId, is_admin: isAdmin } = userQuery.rows[0];
    
    // If user is not an admin and trying to create for someone else, reject
    if (!isAdmin && req.body.userId && req.body.userId !== userId) {
      return res.status(403).json({ message: 'Unauthorized access' });
    }
    
    // Target user is either specified in request or self
    const targetUserId = req.body.userId || userId;
    
    // Check if user already has a container
    const containerCheck = await pool.query(
      'SELECT * FROM user_containers WHERE user_id = $1',
      [targetUserId]
    );
    
    if (containerCheck.rows.length > 0) {
      return res.status(409).json({ message: 'User already has a container' });
    }
    
    // Container creation logic would go here
    // This is a placeholder for actual Docker container creation
    res.json({
      message: 'Container creation request received',
      status: 'pending',
      userId: targetUserId
    });
  } catch (err) {
    console.error('Container creation error:', err);
    res.status(500).json({ message: 'Server error' });
  }
});

app.listen(PORT, () => {
  console.log(`API server running on port ${PORT}`);
});
EOF

# Copy server.js to container
docker cp /tmp/server.js api-service:/app/

# Create a simple Auth0 login page for the frontend
echo -e "${YELLOW}Creating Auth0 login page...${NC}"
cat > /tmp/auth0-login.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>CloudToLocalLLM - Auth0 Login</title>
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
  </style>
</head>
<body>
  <section class="hero is-medium">
    <div class="hero-body">
      <div class="container">
        <h1 class="title is-1">CloudToLocalLLM</h1>
        <h2 class="subtitle is-3">Run powerful Large Language Models locally with cloud-based management</h2>
        <div id="login-container">
          <button id="login" class="button is-large is-primary login-btn">Log In with Auth0</button>
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

# Copy login page to Nginx HTML directory
docker cp /tmp/auth0-login.html nginx-proxy:/usr/share/nginx/html/login.html

# Install dependencies and start app in container
echo -e "${YELLOW}Installing dependencies and starting service...${NC}"
docker exec -i api-service sh -c "cd /app && npm install && node server.js > /app/server.log 2>&1 &"

echo -e "${GREEN}Auth0 integration is now set up!${NC}"
echo -e "${YELLOW}Next steps:${NC}"
echo -e "1. ${GREEN}Create an Auth0 account if you don't have one${NC}"
echo -e "2. ${GREEN}Set up a new Auth0 Application (Single Page Application)${NC}"
echo -e "3. ${GREEN}Configure Allowed Callback URLs: https://cloudtolocalllm.online${NC}"
echo -e "4. ${GREEN}Configure Allowed Logout URLs: https://cloudtolocalllm.online${NC}"
echo -e "5. ${GREEN}Configure Allowed Web Origins: https://cloudtolocalllm.online${NC}"
echo -e "6. ${GREEN}Create an API in Auth0 with Identifier: https://api.cloudtolocalllm.online${NC}"
echo -e "7. ${GREEN}Enable Google Social Connection in Auth0${NC}"
echo -e "8. ${GREEN}Update Client ID in /app/.env file${NC}"
echo -e "9. ${GREEN}Update Client ID in login.html file${NC}"
echo -e "${YELLOW}Your Auth0 login page is available at:${NC} ${GREEN}https://cloudtolocalllm.online/login.html${NC}"
echo -e "${YELLOW}Admin email is set to:${NC} ${GREEN}christopher.maltais@gmail.com${NC}"
'@

# Convert to Unix line endings (LF)
$auth0Script = $auth0Script -replace "`r`n", "`n"
$auth0ScriptPath = [System.IO.Path]::GetTempFileName()
Set-Content -Path $auth0ScriptPath -Value $auth0Script -NoNewline -Encoding utf8

# Upload and run the Auth0 script
Write-ColorOutput Yellow "Uploading and running Auth0 integration script on VPS..."
scp -i $SshKeyPath $auth0ScriptPath "${VpsHost}:/tmp/auth0_integration.sh"
ssh -i $SshKeyPath $VpsHost "chmod +x /tmp/auth0_integration.sh && sudo /tmp/auth0_integration.sh"

# Clean up
Write-ColorOutput Yellow "Cleaning up temporary files..."
Remove-Item -Force $auth0ScriptPath

Write-ColorOutput Green "Auth0 integration setup completed!"
Write-ColorOutput Yellow "Your services are now accessible at:"
Write-Host "Main portal: https://cloudtolocalllm.online"
Write-Host "Auth0 Login: https://cloudtolocalllm.online/login.html"
Write-Host "API service: https://api.cloudtolocalllm.online"
Write-ColorOutput Yellow "Admin email set to: christopher.maltais@gmail.com" 