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

Write-ColorOutput Green "Fixing SSL and adding authentication on $VpsHost..."

# Create the fix script
$fixScript = @'
#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}Starting SSL fix and authentication setup...${NC}"

# Fix SSL configuration in Nginx
echo -e "${YELLOW}Fixing SSL configuration...${NC}"
cat > /opt/cloudtolocalllm/nginx/conf.d/default.conf << 'EOF'
# HTTP redirect to HTTPS
server {
    listen 80;
    listen [::]:80;
    server_name cloudtolocalllm.online www.cloudtolocalllm.online;
    
    location / {
        return 301 https://$host$request_uri;
    }

    # For Let's Encrypt verification
    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }
}

# Main portal
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name cloudtolocalllm.online www.cloudtolocalllm.online;
    
    ssl_certificate /etc/nginx/ssl/fullchain.pem;
    ssl_certificate_key /etc/nginx/ssl/privkey.pem;
    
    # Improved SSL settings
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-SHA384;
    ssl_session_timeout 10m;
    ssl_session_cache shared:SSL:10m;
    ssl_session_tickets off;
    ssl_stapling on;
    ssl_stapling_verify on;
    
    # Security headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Content-Type-Options nosniff;
    add_header X-Frame-Options SAMEORIGIN;
    add_header X-XSS-Protection "1; mode=block";
    add_header Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; font-src 'self' data:; connect-src 'self' https://api.cloudtolocalllm.online; frame-ancestors 'none';";
    
    location / {
        root /usr/share/nginx/html;
        index index.html;
        try_files $uri $uri/ /index.html;
    }
    
    # Auth API endpoint for login
    location /auth/ {
        proxy_pass http://api-service:8080/auth/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }
}
EOF

# Update API subdomain config
cat > /opt/cloudtolocalllm/nginx/conf.d/api.conf << 'EOF'
# API service
server {
    listen 80;
    listen [::]:80;
    server_name api.cloudtolocalllm.online;
    
    location / {
        return 301 https://$host$request_uri;
    }
    
    # For Let's Encrypt verification
    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name api.cloudtolocalllm.online;
    
    ssl_certificate /etc/nginx/ssl/fullchain.pem;
    ssl_certificate_key /etc/nginx/ssl/privkey.pem;
    
    # Improved SSL settings
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-SHA384;
    ssl_session_timeout 10m;
    ssl_session_cache shared:SSL:10m;
    ssl_session_tickets off;
    ssl_stapling on;
    ssl_stapling_verify on;
    
    # Security headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Content-Type-Options nosniff;
    add_header X-Frame-Options SAMEORIGIN;
    add_header X-XSS-Protection "1; mode=block";
    
    # CORS headers for API
    add_header 'Access-Control-Allow-Origin' 'https://cloudtolocalllm.online' always;
    add_header 'Access-Control-Allow-Methods' 'GET, POST, OPTIONS' always;
    add_header 'Access-Control-Allow-Headers' 'DNT,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Range,Authorization' always;
    add_header 'Access-Control-Expose-Headers' 'Content-Length,Content-Range' always;
    
    location / {
        proxy_pass http://api-service:8080;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }
    
    # Handle OPTIONS requests for CORS
    location ~ ^/(.*)$ {
        if ($request_method = 'OPTIONS') {
            add_header 'Access-Control-Allow-Origin' 'https://cloudtolocalllm.online' always;
            add_header 'Access-Control-Allow-Methods' 'GET, POST, OPTIONS' always;
            add_header 'Access-Control-Allow-Headers' 'DNT,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Range,Authorization' always;
            add_header 'Access-Control-Max-Age' 1728000;
            add_header 'Content-Type' 'text/plain charset=UTF-8';
            add_header 'Content-Length' 0;
            return 204;
        }
        try_files $uri @proxy;
    }
    
    location @proxy {
        proxy_pass http://api-service:8080;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOF

# Update Users subdomain config
cat > /opt/cloudtolocalllm/nginx/conf.d/users.conf << 'EOF'
# User containers
server {
    listen 80;
    listen [::]:80;
    server_name users.cloudtolocalllm.online ~^(?<username>[^.]+)\.users\.cloudtolocalllm\.online$;
    
    location / {
        return 301 https://$host$request_uri;
    }
    
    # For Let's Encrypt verification
    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name users.cloudtolocalllm.online;
    
    ssl_certificate /etc/nginx/ssl/fullchain.pem;
    ssl_certificate_key /etc/nginx/ssl/privkey.pem;
    
    # Improved SSL settings
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-SHA384;
    ssl_session_timeout 10m;
    ssl_session_cache shared:SSL:10m;
    ssl_session_tickets off;
    ssl_stapling on;
    ssl_stapling_verify on;
    
    # Security headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Content-Type-Options nosniff;
    add_header X-Frame-Options SAMEORIGIN;
    add_header X-XSS-Protection "1; mode=block";
    
    location / {
        root /usr/share/nginx/html/users;
        index index.html;
        try_files $uri $uri/ /index.html;
    }
}

# Dynamic user subdomains
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name ~^(?<username>[^.]+)\.users\.cloudtolocalllm\.online$;
    
    ssl_certificate /etc/nginx/ssl/fullchain.pem;
    ssl_certificate_key /etc/nginx/ssl/privkey.pem;
    
    # Improved SSL settings
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-SHA384;
    ssl_session_timeout 10m;
    ssl_session_cache shared:SSL:10m;
    ssl_session_tickets off;
    ssl_stapling on;
    ssl_stapling_verify on;
    
    # Security headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Content-Type-Options nosniff;
    add_header X-Frame-Options SAMEORIGIN;
    add_header X-XSS-Protection "1; mode=block";
    
    location / {
        # JWT token verification could be added here with auth_request
        proxy_pass http://user-$username:8080;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
        
        # If user container doesn't exist, show error page
        proxy_intercept_errors on;
        error_page 502 503 504 = @user_not_found;
    }
    
    location @user_not_found {
        root /usr/share/nginx/html/errors;
        try_files /user_not_found.html =404;
    }
}
EOF

# Create ACME challenge directory
mkdir -p /var/www/html/.well-known/acme-challenge

# Create authentication API service
echo -e "${YELLOW}Setting up authentication API...${NC}"
mkdir -p /opt/cloudtolocalllm/data/api
cat > /opt/cloudtolocalllm/data/api/package.json << 'EOF'
{
  "name": "cloudtolocalllm-api",
  "version": "1.0.0",
  "description": "API service for CloudToLocalLLM",
  "main": "server.js",
  "scripts": {
    "start": "node server.js"
  },
  "dependencies": {
    "express": "^4.18.2",
    "jsonwebtoken": "^9.0.0",
    "bcryptjs": "^2.4.3",
    "cors": "^2.8.5",
    "pg": "^8.10.0",
    "dotenv": "^16.0.3"
  }
}
EOF

cat > /opt/cloudtolocalllm/data/api/server.js << 'EOF'
const express = require('express');
const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
const cors = require('cors');
const { Pool } = require('pg');

const app = express();
const PORT = process.env.PORT || 8080;
const JWT_SECRET = process.env.JWT_SECRET || 'cloudtolocalllm-secret-key-change-in-production';

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
  origin: 'https://cloudtolocalllm.online',
  methods: ['GET', 'POST', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization']
}));

// Create tables if they don't exist
async function initDb() {
  try {
    await pool.query(`
      CREATE TABLE IF NOT EXISTS users (
        id SERIAL PRIMARY KEY,
        username VARCHAR(50) UNIQUE NOT NULL,
        email VARCHAR(255) UNIQUE NOT NULL,
        password VARCHAR(255) NOT NULL,
        created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
      );
    `);
    
    // Add a default admin user if none exists
    const userCount = await pool.query('SELECT COUNT(*) FROM users');
    if (parseInt(userCount.rows[0].count) === 0) {
      const hashedPassword = await bcrypt.hash('admin123', 10);
      await pool.query(
        'INSERT INTO users (username, email, password) VALUES ($1, $2, $3)',
        ['admin', 'admin@cloudtolocalllm.online', hashedPassword]
      );
      console.log('Default admin user created');
    }
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
    message: 'CloudToLocalLLM API is running',
    timestamp: new Date().toISOString()
  });
});

// Auth endpoints
app.post('/auth/register', async (req, res) => {
  try {
    const { username, email, password } = req.body;
    
    // Validate input
    if (!username || !email || !password) {
      return res.status(400).json({ message: 'All fields are required' });
    }
    
    // Check if user already exists
    const userCheck = await pool.query(
      'SELECT * FROM users WHERE username = $1 OR email = $2',
      [username, email]
    );
    
    if (userCheck.rows.length > 0) {
      return res.status(409).json({ message: 'Username or email already exists' });
    }
    
    // Hash password
    const hashedPassword = await bcrypt.hash(password, 10);
    
    // Insert new user
    const result = await pool.query(
      'INSERT INTO users (username, email, password) VALUES ($1, $2, $3) RETURNING id, username, email',
      [username, email, hashedPassword]
    );
    
    res.status(201).json({
      message: 'User registered successfully',
      user: result.rows[0]
    });
  } catch (err) {
    console.error('Registration error:', err);
    res.status(500).json({ message: 'Server error' });
  }
});

app.post('/auth/login', async (req, res) => {
  try {
    const { username, password } = req.body;
    
    // Validate input
    if (!username || !password) {
      return res.status(400).json({ message: 'Username and password are required' });
    }
    
    // Find user
    const result = await pool.query(
      'SELECT * FROM users WHERE username = $1',
      [username]
    );
    
    if (result.rows.length === 0) {
      return res.status(401).json({ message: 'Invalid credentials' });
    }
    
    const user = result.rows[0];
    
    // Check password
    const isPasswordValid = await bcrypt.compare(password, user.password);
    
    if (!isPasswordValid) {
      return res.status(401).json({ message: 'Invalid credentials' });
    }
    
    // Generate JWT token
    const token = jwt.sign(
      { id: user.id, username: user.username },
      JWT_SECRET,
      { expiresIn: '24h' }
    );
    
    res.json({
      message: 'Login successful',
      token,
      user: {
        id: user.id,
        username: user.username,
        email: user.email
      }
    });
  } catch (err) {
    console.error('Login error:', err);
    res.status(500).json({ message: 'Server error' });
  }
});

// Protected route example
app.get('/auth/profile', authenticateToken, async (req, res) => {
  try {
    const result = await pool.query(
      'SELECT id, username, email, created_at FROM users WHERE id = $1',
      [req.user.id]
    );
    
    if (result.rows.length === 0) {
      return res.status(404).json({ message: 'User not found' });
    }
    
    res.json(result.rows[0]);
  } catch (err) {
    console.error('Profile error:', err);
    res.status(500).json({ message: 'Server error' });
  }
});

// Middleware to verify JWT token
function authenticateToken(req, res, next) {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];
  
  if (!token) {
    return res.status(401).json({ message: 'Authentication required' });
  }
  
  jwt.verify(token, JWT_SECRET, (err, user) => {
    if (err) {
      return res.status(403).json({ message: 'Invalid or expired token' });
    }
    
    req.user = user;
    next();
  });
}

app.listen(PORT, () => {
  console.log(`API server running on port ${PORT}`);
});
EOF

# Install Node.js dependencies
echo -e "${YELLOW}Installing API dependencies...${NC}"
cd /opt/cloudtolocalllm/data/api
npm install

# Create authentication middleware for user manager
echo -e "${YELLOW}Setting up user manager authentication...${NC}"
mkdir -p /opt/cloudtolocalllm/data/user-manager
cat > /opt/cloudtolocalllm/data/user-manager/package.json << 'EOF'
{
  "name": "cloudtolocalllm-user-manager",
  "version": "1.0.0",
  "description": "User container manager for CloudToLocalLLM",
  "main": "server.js",
  "scripts": {
    "start": "node server.js"
  },
  "dependencies": {
    "express": "^4.18.2",
    "jsonwebtoken": "^9.0.0",
    "dockerode": "^3.3.5",
    "pg": "^8.10.0",
    "dotenv": "^16.0.3"
  }
}
EOF

cat > /opt/cloudtolocalllm/data/user-manager/server.js << 'EOF'
const express = require('express');
const jwt = require('jsonwebtoken');
const Docker = require('dockerode');
const { Pool } = require('pg');

const app = express();
const PORT = process.env.PORT || 8081;
const JWT_SECRET = process.env.JWT_SECRET || 'cloudtolocalllm-secret-key-change-in-production';

// Connect to Docker daemon
const docker = new Docker({ socketPath: '/var/run/docker.sock' });

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

// Create tables if they don't exist
async function initDb() {
  try {
    await pool.query(`
      CREATE TABLE IF NOT EXISTS user_containers (
        id SERIAL PRIMARY KEY,
        user_id INTEGER REFERENCES users(id),
        container_id VARCHAR(255),
        container_name VARCHAR(255),
        status VARCHAR(50),
        created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
      );
    `);
    console.log('User containers table initialized');
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
    message: 'User manager service is running',
    timestamp: new Date().toISOString()
  });
});

// Protected routes for container management
app.post('/containers/create', authenticateToken, async (req, res) => {
  try {
    const { userId, username } = req.user;
    
    // Check if user already has a container
    const containerCheck = await pool.query(
      'SELECT * FROM user_containers WHERE user_id = $1',
      [userId]
    );
    
    if (containerCheck.rows.length > 0) {
      return res.status(409).json({ message: 'User already has a container' });
    }
    
    // Container creation would go here
    // This is a placeholder for actual Docker container creation
    res.json({
      message: 'Container creation request received',
      status: 'pending',
      username
    });
  } catch (err) {
    console.error('Container creation error:', err);
    res.status(500).json({ message: 'Server error' });
  }
});

// Middleware to verify JWT token
function authenticateToken(req, res, next) {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];
  
  if (!token) {
    return res.status(401).json({ message: 'Authentication required' });
  }
  
  jwt.verify(token, JWT_SECRET, (err, user) => {
    if (err) {
      return res.status(403).json({ message: 'Invalid or expired token' });
    }
    
    req.user = user;
    next();
  });
}

app.listen(PORT, () => {
  console.log(`User manager running on port ${PORT}`);
});
EOF

# Install Node.js dependencies for user manager
echo -e "${YELLOW}Installing user manager dependencies...${NC}"
cd /opt/cloudtolocalllm/data/user-manager
npm install

# Restart containers
echo -e "${YELLOW}Restarting containers with new configuration...${NC}"
cd /opt/cloudtolocalllm
docker-compose restart

echo -e "${GREEN}SSL fix and authentication setup completed!${NC}"
echo -e "${YELLOW}Main portal:${NC} ${GREEN}https://cloudtolocalllm.online${NC}"
echo -e "${YELLOW}API service:${NC} ${GREEN}https://api.cloudtolocalllm.online${NC}"
echo -e "${YELLOW}Users portal:${NC} ${GREEN}https://users.cloudtolocalllm.online${NC}"
echo -e "${YELLOW}Default admin credentials:${NC}"
echo -e "  Username: ${GREEN}admin${NC}"
echo -e "  Password: ${GREEN}admin123${NC}"
'@

# Convert to Unix line endings (LF)
$fixScript = $fixScript -replace "`r`n", "`n"
$fixScriptPath = [System.IO.Path]::GetTempFileName()
Set-Content -Path $fixScriptPath -Value $fixScript -NoNewline -Encoding utf8

# Upload and run the fix script
Write-ColorOutput Yellow "Uploading and running fix script on VPS..."
scp -i $SshKeyPath $fixScriptPath "${VpsHost}:/tmp/fix_ssl_and_add_auth.sh"
ssh -i $SshKeyPath $VpsHost "chmod +x /tmp/fix_ssl_and_add_auth.sh && sudo /tmp/fix_ssl_and_add_auth.sh"

# Clean up
Write-ColorOutput Yellow "Cleaning up temporary files..."
Remove-Item -Force $fixScriptPath

Write-ColorOutput Green "SSL fix and authentication setup completed!"
Write-ColorOutput Yellow "Your services are now accessible at:"
Write-Host "Main portal: https://cloudtolocalllm.online"
Write-Host "API service: https://api.cloudtolocalllm.online"
Write-Host "Users portal: https://users.cloudtolocalllm.online"
Write-ColorOutput Yellow "Default admin credentials:"
Write-Host "  Username: admin"
Write-Host "  Password: admin123" 