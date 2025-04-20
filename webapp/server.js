const express = require('express');
const session = require('express-session');
const passport = require('passport');
const Auth0Strategy = require('passport-auth0');
const jwt = require('jsonwebtoken');
const cors = require('cors');
const http = require('http');
const WebSocket = require('ws');
const path = require('path');
const fs = require('fs');
const { v4: uuidv4 } = require('uuid');

// Load environment variables
require('dotenv').config();

// Initialize Express app
const app = express();
const port = process.env.PORT || 3000;

// Configure middleware
app.use(express.json());
app.use(express.urlencoded({ extended: true }));
app.use(cors());
app.use(express.static(path.join(__dirname, 'public')));

// Configure session
app.use(session({
  secret: process.env.SESSION_SECRET || 'your-secret-key',
  resave: false,
  saveUninitialized: true,
  cookie: { secure: process.env.NODE_ENV === 'production' }
}));

// Configure Auth0
const auth0Config = {
  domain: process.env.AUTH0_DOMAIN || 'your-auth0-domain.auth0.com',
  clientID: process.env.AUTH0_CLIENT_ID || 'your-auth0-client-id',
  clientSecret: process.env.AUTH0_CLIENT_SECRET || 'your-auth0-client-secret',
  callbackURL: process.env.AUTH0_CALLBACK_URL || 'http://localhost:3000/callback'
};

// Initialize Passport with Auth0
passport.use(new Auth0Strategy(auth0Config, (accessToken, refreshToken, extraParams, profile, done) => {
  // Store user information in the session
  return done(null, profile);
}));

passport.serializeUser((user, done) => {
  done(null, user);
});

passport.deserializeUser((user, done) => {
  done(null, user);
});

app.use(passport.initialize());
app.use(passport.session());

// In-memory storage for connected tunnels
const connectedTunnels = new Map();

// Create HTTP server
const server = http.createServer(app);

// Create WebSocket server
const wss = new WebSocket.Server({ server });

// Handle WebSocket connections
wss.on('connection', (ws, req) => {
  const userId = req.url.split('?userId=')[1];
  if (!userId) {
    ws.close(1008, 'Missing userId');
    return;
  }

  // Store the WebSocket connection
  connectedTunnels.set(userId, ws);

  // Handle messages from the client
  ws.on('message', (message) => {
    try {
      const data = JSON.parse(message);
      // Handle different message types
      if (data.type === 'ping') {
        ws.send(JSON.stringify({ type: 'pong' }));
      }
    } catch (error) {
      console.error('Error handling WebSocket message:', error);
    }
  });

  // Handle WebSocket close
  ws.on('close', () => {
    connectedTunnels.delete(userId);
  });
});

// Authentication routes
app.get('/login', passport.authenticate('auth0', {
  scope: 'openid email profile'
}));

app.get('/callback', passport.authenticate('auth0', {
  failureRedirect: '/login'
}), (req, res) => {
  // Generate JWT token
  const token = jwt.sign(
    { 
      sub: req.user.id,
      email: req.user.emails[0].value,
      name: req.user.displayName
    },
    process.env.JWT_SECRET || 'your-jwt-secret',
    { expiresIn: '1h' }
  );
  
  // Redirect to the app with the token
  res.redirect(`/auth-success?token=${token}`);
});

app.get('/logout', (req, res) => {
  req.logout();
  res.redirect('/');
});

// Auth success page
app.get('/auth-success', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'auth-success.html'));
});

// API routes
// Middleware to verify JWT token
const authenticateJWT = (req, res, next) => {
  const authHeader = req.headers.authorization;
  
  if (authHeader) {
    const token = authHeader.split(' ')[1];
    
    jwt.verify(token, process.env.JWT_SECRET || 'your-jwt-secret', (err, user) => {
      if (err) {
        return res.sendStatus(403);
      }
      
      req.user = user;
      next();
    });
  } else {
    res.sendStatus(401);
  }
};

// User profile endpoint
app.get('/api/user/profile', authenticateJWT, (req, res) => {
  res.json({
    id: req.user.sub,
    email: req.user.email,
    name: req.user.name,
    isAuthenticated: true,
    lastLogin: new Date().toISOString()
  });
});

// Tunnel registration endpoint
app.post('/api/tunnel/register', authenticateJWT, (req, res) => {
  const { userId } = req.body;
  
  if (!userId) {
    return res.status(400).json({ error: 'Missing userId' });
  }
  
  // Generate a unique tunnel ID
  const tunnelId = uuidv4();
  
  // Store tunnel information
  const tunnelInfo = {
    userId,
    tunnelId,
    createdAt: new Date().toISOString()
  };
  
  // Return tunnel information
  res.json({
    tunnelId,
    tunnelUrl: `https://cloudtolocalllm.example.com/tunnel/${tunnelId}`,
    isConnected: true
  });
});

// Tunnel unregistration endpoint
app.post('/api/tunnel/unregister', authenticateJWT, (req, res) => {
  const { userId } = req.body;
  
  if (!userId) {
    return res.status(400).json({ error: 'Missing userId' });
  }
  
  // Remove tunnel connection
  connectedTunnels.delete(userId);
  
  res.json({ success: true });
});

// Tunnel status endpoint
app.get('/api/tunnel/status', authenticateJWT, (req, res) => {
  const userId = req.user.sub;
  
  // Check if tunnel is connected
  const isConnected = connectedTunnels.has(userId);
  
  res.json({
    isConnected,
    tunnelUrl: isConnected ? `https://cloudtolocalllm.example.com/tunnel/${userId}` : null
  });
});

// LLM API endpoint
app.post('/api/llm', authenticateJWT, async (req, res) => {
  const { prompt, model, tunnelId } = req.body;
  
  if (!prompt) {
    return res.status(400).json({ error: 'Missing prompt' });
  }
  
  if (!tunnelId) {
    return res.status(400).json({ error: 'Missing tunnelId' });
  }
  
  // Find the WebSocket connection for the tunnel
  const ws = connectedTunnels.get(tunnelId);
  
  if (!ws) {
    return res.status(404).json({ error: 'Tunnel not found or disconnected' });
  }
  
  try {
    // Send the request to the tunnel
    const requestId = uuidv4();
    
    // Create a promise that will be resolved when the response is received
    const responsePromise = new Promise((resolve, reject) => {
      const timeout = setTimeout(() => {
        reject(new Error('Request timed out'));
      }, 30000); // 30 seconds timeout
      
      // Handle the response
      const messageHandler = (message) => {
        try {
          const data = JSON.parse(message);
          
          if (data.requestId === requestId) {
            clearTimeout(timeout);
            ws.removeListener('message', messageHandler);
            
            if (data.error) {
              reject(new Error(data.error));
            } else {
              resolve(data.response);
            }
          }
        } catch (error) {
          // Ignore parsing errors
        }
      };
      
      ws.on('message', messageHandler);
      
      // Send the request
      ws.send(JSON.stringify({
        type: 'llm_request',
        requestId,
        prompt,
        model: model || 'tinyllama'
      }));
    });
    
    // Wait for the response
    const response = await responsePromise;
    
    res.json({ response });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Start the server
server.listen(port, () => {
  console.log(`Server running on port ${port}`);
});