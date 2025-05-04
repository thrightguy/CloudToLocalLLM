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

Write-ColorOutput Green "Setting up API service with login on $VpsHost..."

# Create the fix script
$fixScript = @'
#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}Setting up API service with login functionality...${NC}"

# Fix any package locks
rm -f /var/lib/dpkg/lock-frontend
rm -f /var/lib/apt/lists/lock
rm -f /var/cache/apt/archives/lock
rm -f /var/lib/dpkg/lock

# Create API service directly in container
echo -e "${YELLOW}Configuring API service in container...${NC}"
docker exec -i api-service sh -c "mkdir -p /app"

# Create package.json
echo -e "${YELLOW}Creating package.json...${NC}"
cat > /tmp/package.json << 'EOF'
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
    "pg": "^8.10.0"
  }
}
EOF

# Copy package.json to container
docker cp /tmp/package.json api-service:/app/

# Create server.js with authentication
echo -e "${YELLOW}Creating API server with auth...${NC}"
cat > /tmp/server.js << 'EOF'
const express = require('express');
const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
const cors = require('cors');
const { Pool } = require('pg');

const app = express();
const PORT = process.env.PORT || 8080;
const JWT_SECRET = 'cloudtolocalllm-secret-key-change-in-production';

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

# Copy server.js to container
docker cp /tmp/server.js api-service:/app/

# Install dependencies and start app in container
echo -e "${YELLOW}Installing dependencies and starting service...${NC}"
docker exec -i api-service sh -c "cd /app && npm install && node server.js > /app/server.log 2>&1 &"

echo -e "${GREEN}API service with login functionality is now set up!${NC}"
echo -e "${YELLOW}Your API is accessible at:${NC} ${GREEN}https://api.cloudtolocalllm.online${NC}"
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
scp -i $SshKeyPath $fixScriptPath "${VpsHost}:/tmp/fix_api_login.sh"
ssh -i $SshKeyPath $VpsHost "chmod +x /tmp/fix_api_login.sh && sudo /tmp/fix_api_login.sh"

# Clean up
Write-ColorOutput Yellow "Cleaning up temporary files..."
Remove-Item -Force $fixScriptPath

Write-ColorOutput Green "API service setup completed!"
Write-ColorOutput Yellow "Your services are now accessible at:"
Write-Host "Main portal: https://cloudtolocalllm.online"
Write-Host "API service: https://api.cloudtolocalllm.online"
Write-ColorOutput Yellow "Default admin credentials:"
Write-Host "  Username: admin"
Write-Host "  Password: admin123" 