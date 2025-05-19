// Firebase Authentication MCP Server
const express = require('express');
const { createServer } = require('http');
const { Server } = require('socket.io');
const axios = require('axios');
const cors = require('cors');
require('dotenv').config();

// Initialize Express app
const app = express();
app.use(cors());
app.use(express.json());

const httpServer = createServer(app);
const io = new Server(httpServer, {
  cors: {
    origin: '*',
    methods: ['GET', 'POST']
  }
});

// Firebase Auth API endpoints
const FIREBASE_API_KEY = process.env.FIREBASE_API_KEY || 'AIzaSyAjoUZYOf_F9LOv1mNp8NjtlcVQOQ4tKv8';
const FIREBASE_AUTH_URL = 'https://identitytoolkit.googleapis.com/v1/accounts';
const FIREBASE_REFRESH_URL = 'https://securetoken.googleapis.com/v1/token';

// MCP protocol implementation
app.get('/mcp-info', (req, res) => {
  res.json({
    name: 'firebase-auth-server',
    version: '1.0.0',
    tools: [
      {
        name: 'signin_with_email_password',
        description: 'Sign in with email and password using Firebase Authentication',
        input_schema: {
          type: 'object',
          properties: {
            email: {
              type: 'string',
              description: 'Email address'
            },
            password: {
              type: 'string',
              description: 'Password'
            }
          },
          required: ['email', 'password']
        }
      },
      {
        name: 'signup_with_email_password',
        description: 'Create a new account using email and password',
        input_schema: {
          type: 'object',
          properties: {
            email: {
              type: 'string',
              description: 'Email address'
            },
            password: {
              type: 'string',
              description: 'Password'
            }
          },
          required: ['email', 'password']
        }
      },
      {
        name: 'signout',
        description: 'Sign out the current user',
        input_schema: {
          type: 'object',
          properties: {}
        }
      },
      {
        name: 'refresh_token',
        description: 'Refresh the authentication token',
        input_schema: {
          type: 'object',
          properties: {
            refresh_token: {
              type: 'string',
              description: 'Firebase refresh token'
            }
          },
          required: ['refresh_token']
        }
      }
    ],
    resources: [
      {
        uri: 'auth-status',
        description: 'Current authentication status'
      },
      {
        uri: 'user-profile',
        description: 'User profile information when logged in'
      }
    ]
  });
});

// Tools Implementation
app.post('/mcp-tools/signin_with_email_password', async (req, res) => {
  try {
    const { email, password } = req.body;
    
    const response = await axios.post(`${FIREBASE_AUTH_URL}:signInWithPassword?key=${FIREBASE_API_KEY}`, {
      email,
      password,
      returnSecureToken: true
    });
    
    res.json({
      success: true,
      user: {
        uid: response.data.localId,
        email: response.data.email,
        displayName: response.data.displayName,
        idToken: response.data.idToken,
        refreshToken: response.data.refreshToken,
        expiresIn: response.data.expiresIn
      }
    });
  } catch (error) {
    res.status(400).json({
      success: false,
      error: {
        code: error.response?.data?.error?.message || 'auth/unknown',
        message: error.response?.data?.error?.message || error.message
      }
    });
  }
});

app.post('/mcp-tools/signup_with_email_password', async (req, res) => {
  try {
    const { email, password } = req.body;
    
    const response = await axios.post(`${FIREBASE_AUTH_URL}:signUp?key=${FIREBASE_API_KEY}`, {
      email,
      password,
      returnSecureToken: true
    });
    
    res.json({
      success: true,
      user: {
        uid: response.data.localId,
        email: response.data.email,
        idToken: response.data.idToken,
        refreshToken: response.data.refreshToken,
        expiresIn: response.data.expiresIn
      }
    });
  } catch (error) {
    res.status(400).json({
      success: false,
      error: {
        code: error.response?.data?.error?.message || 'auth/unknown',
        message: error.response?.data?.error?.message || error.message
      }
    });
  }
});

app.post('/mcp-tools/signout', (req, res) => {
  // Since Firebase Auth is stateless on the server, we just return success
  res.json({
    success: true
  });
});

app.post('/mcp-tools/refresh_token', async (req, res) => {
  try {
    const { refresh_token } = req.body;
    
    const response = await axios.post(`${FIREBASE_REFRESH_URL}?key=${FIREBASE_API_KEY}`, {
      grant_type: 'refresh_token',
      refresh_token
    });
    
    res.json({
      success: true,
      auth: {
        id_token: response.data.id_token,
        refresh_token: response.data.refresh_token,
        expires_in: response.data.expires_in
      }
    });
  } catch (error) {
    res.status(400).json({
      success: false,
      error: {
        code: error.response?.data?.error?.message || 'auth/unknown',
        message: error.response?.data?.error?.message || error.message
      }
    });
  }
});

// Resources Implementation
app.get('/mcp-resources/auth-status', (req, res) => {
  // This would typically be implemented using a stateful session or token validation
  const authHeader = req.headers.authorization;
  
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.json({
      authenticated: false
    });
  }
  
  // In a real implementation, you would validate the token here
  // For now, we just assume if a token is present, the user is authenticated
  res.json({
    authenticated: true
  });
});

app.get('/mcp-resources/user-profile', async (req, res) => {
  const authHeader = req.headers.authorization;
  
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({
      error: {
        code: 'auth/not-authenticated',
        message: 'User is not authenticated'
      }
    });
  }
  
  const idToken = authHeader.split('Bearer ')[1];
  
  try {
    // Get user data using the ID token
    const response = await axios.post(`${FIREBASE_AUTH_URL}:lookup?key=${FIREBASE_API_KEY}`, {
      idToken
    });
    
    const userData = response.data.users[0];
    
    res.json({
      uid: userData.localId,
      email: userData.email,
      emailVerified: userData.emailVerified,
      displayName: userData.displayName,
      photoURL: userData.photoUrl,
      createdAt: userData.createdAt
    });
  } catch (error) {
    res.status(401).json({
      error: {
        code: error.response?.data?.error?.message || 'auth/unknown',
        message: error.response?.data?.error?.message || error.message
      }
    });
  }
});

// WebSocket support
io.on('connection', (socket) => {
  console.log('Client connected');
  
  socket.on('authenticate', (data) => {
    // Save authentication state
    socket.auth = data;
    socket.emit('auth_state', { authenticated: true, uid: data.uid });
  });
  
  socket.on('unauthenticate', () => {
    socket.auth = null;
    socket.emit('auth_state', { authenticated: false });
  });
  
  socket.on('disconnect', () => {
    console.log('Client disconnected');
  });
});

// Start the server
const PORT = process.env.PORT || 3030;
httpServer.listen(PORT, () => {
  console.log(`Firebase Auth MCP Server running on port ${PORT}`);
});
