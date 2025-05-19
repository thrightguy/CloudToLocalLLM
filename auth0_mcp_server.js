// Auth0 Authentication MCP Server
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

// Auth0 Configuration
const AUTH0_DOMAIN = process.env.AUTH0_DOMAIN || 'dev-xafu7oedkd5wlrbo.us.auth0.com';
const AUTH0_CLIENT_ID = process.env.AUTH0_CLIENT_ID || 'HlOeY1pG9e2g6MvFKPDFbJ3ASIhxDgNu';
const AUTH0_CLIENT_SECRET = process.env.AUTH0_CLIENT_SECRET;
const AUTH0_AUDIENCE = process.env.AUTH0_AUDIENCE || `https://${AUTH0_DOMAIN}/api/v2/`;
const AUTH0_OAUTH_URL = `https://${AUTH0_DOMAIN}/oauth/token`;
const AUTH0_USERINFO_URL = `https://${AUTH0_DOMAIN}/userinfo`;

// MCP protocol implementation
app.get('/mcp-info', (req, res) => {
  res.json({
    name: 'auth0-auth-server',
    version: '1.0.0',
    tools: [
      {
        name: 'signin_with_credentials',
        description: 'Sign in with username/email and password using Auth0',
        input_schema: {
          type: 'object',
          properties: {
            username: {
              type: 'string',
              description: 'Username or email address'
            },
            password: {
              type: 'string',
              description: 'Password'
            }
          },
          required: ['username', 'password']
        }
      },
      {
        name: 'signup_with_credentials',
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
            },
            name: {
              type: 'string',
              description: 'Full name (optional)'
            }
          },
          required: ['email', 'password']
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
              description: 'Auth0 refresh token'
            }
          },
          required: ['refresh_token']
        }
      },
      {
        name: 'get_user_info',
        description: 'Get user information using an access token',
        input_schema: {
          type: 'object',
          properties: {
            access_token: {
              type: 'string',
              description: 'Auth0 access token'
            }
          },
          required: ['access_token']
        }
      },
      {
        name: 'signout',
        description: 'Sign out the current user',
        input_schema: {
          type: 'object',
          properties: {}
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
app.post('/mcp-tools/signin_with_credentials', async (req, res) => {
  try {
    const { username, password } = req.body;
    
    // Use Auth0 Password Grant to authenticate user
    const response = await axios.post(AUTH0_OAUTH_URL, {
      grant_type: 'password',
      username,
      password,
      client_id: AUTH0_CLIENT_ID,
      client_secret: AUTH0_CLIENT_SECRET,
      audience: AUTH0_AUDIENCE,
      scope: 'openid profile email offline_access'
    });
    
    // Get user profile with the access token
    const userInfoResponse = await axios.get(AUTH0_USERINFO_URL, {
      headers: {
        Authorization: `Bearer ${response.data.access_token}`
      }
    });
    
    res.json({
      success: true,
      auth: {
        access_token: response.data.access_token,
        id_token: response.data.id_token,
        refresh_token: response.data.refresh_token,
        expires_in: response.data.expires_in,
        token_type: response.data.token_type
      },
      user: userInfoResponse.data
    });
  } catch (error) {
    res.status(400).json({
      success: false,
      error: {
        code: error.response?.data?.error || 'auth/unknown',
        message: error.response?.data?.error_description || error.message
      }
    });
  }
});

app.post('/mcp-tools/signup_with_credentials', async (req, res) => {
  try {
    const { email, password, name } = req.body;
    
    // Get management API token
    const tokenResponse = await axios.post(AUTH0_OAUTH_URL, {
      grant_type: 'client_credentials',
      client_id: AUTH0_CLIENT_ID,
      client_secret: AUTH0_CLIENT_SECRET,
      audience: `https://${AUTH0_DOMAIN}/api/v2/`
    });
    
    const managementToken = tokenResponse.data.access_token;
    
    // Create user
    const userResponse = await axios.post(`https://${AUTH0_DOMAIN}/api/v2/users`, {
      email,
      password,
      connection: 'Username-Password-Authentication',
      name: name || email,
      email_verified: false
    }, {
      headers: {
        Authorization: `Bearer ${managementToken}`
      }
    });
    
    res.json({
      success: true,
      user: {
        user_id: userResponse.data.user_id,
        email: userResponse.data.email,
        name: userResponse.data.name
      },
      message: 'User created successfully. You can now sign in.'
    });
  } catch (error) {
    res.status(400).json({
      success: false,
      error: {
        code: error.response?.data?.error || 'auth/unknown',
        message: error.response?.data?.error_description || error.message
      }
    });
  }
});

app.post('/mcp-tools/refresh_token', async (req, res) => {
  try {
    const { refresh_token } = req.body;
    
    const response = await axios.post(AUTH0_OAUTH_URL, {
      grant_type: 'refresh_token',
      client_id: AUTH0_CLIENT_ID,
      client_secret: AUTH0_CLIENT_SECRET,
      refresh_token
    });
    
    res.json({
      success: true,
      auth: {
        access_token: response.data.access_token,
        id_token: response.data.id_token,
        refresh_token: response.data.refresh_token,
        expires_in: response.data.expires_in,
        token_type: response.data.token_type
      }
    });
  } catch (error) {
    res.status(400).json({
      success: false,
      error: {
        code: error.response?.data?.error || 'auth/unknown',
        message: error.response?.data?.error_description || error.message
      }
    });
  }
});

app.post('/mcp-tools/get_user_info', async (req, res) => {
  try {
    const { access_token } = req.body;
    
    const response = await axios.get(AUTH0_USERINFO_URL, {
      headers: {
        Authorization: `Bearer ${access_token}`
      }
    });
    
    res.json({
      success: true,
      user: response.data
    });
  } catch (error) {
    res.status(400).json({
      success: false,
      error: {
        code: error.response?.data?.error || 'auth/unknown',
        message: error.response?.data?.error_description || error.message
      }
    });
  }
});

app.post('/mcp-tools/signout', (req, res) => {
  // Auth0 is stateless on the server side, so we just return success
  res.json({
    success: true
  });
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
  
  const accessToken = authHeader.split('Bearer ')[1];
  
  try {
    // Get user data using the access token
    const response = await axios.get(AUTH0_USERINFO_URL, {
      headers: {
        Authorization: `Bearer ${accessToken}`
      }
    });
    
    res.json(response.data);
  } catch (error) {
    res.status(401).json({
      error: {
        code: error.response?.data?.error || 'auth/unknown',
        message: error.response?.data?.error_description || error.message
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
    socket.emit('auth_state', { authenticated: true, sub: data.sub });
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
const PORT = process.env.PORT || 3031;
httpServer.listen(PORT, () => {
  console.log(`Auth0 Auth MCP Server running on port ${PORT}`);
});
