const express = require('express');
const http = require('http');
const WebSocket = require('ws');
const cors = require('cors');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const jwt = require('jsonwebtoken');
const jwksClient = require('jwks-client');
const { v4: uuidv4 } = require('uuid');
const winston = require('winston');
require('dotenv').config();

// Initialize logger
const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.errors({ stack: true }),
    winston.format.json()
  ),
  defaultMeta: { service: 'cloudtolocalllm-api' },
  transports: [
    new winston.transports.File({ filename: 'logs/error.log', level: 'error' }),
    new winston.transports.File({ filename: 'logs/combined.log' }),
    new winston.transports.Console({
      format: winston.format.simple()
    })
  ]
});

// Configuration
const PORT = process.env.PORT || 8080;
const AUTH0_DOMAIN = process.env.AUTH0_DOMAIN || 'dev-xafu7oedkd5wlrbo.us.auth0.com';
const AUTH0_AUDIENCE = process.env.AUTH0_AUDIENCE || 'https://app.cloudtolocalllm.online';

// JWKS client for Auth0 token verification
const jwksClientInstance = jwksClient({
  jwksUri: `https://${AUTH0_DOMAIN}/.well-known/jwks.json`,
  requestHeaders: {},
  timeout: 30000,
  cache: true,
  rateLimit: true,
  jwksRequestsPerMinute: 5,
  jwksRequestsPerMinute: 5
});

// Express app setup
const app = express();
const server = http.createServer(app);

// Security middleware
app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      connectSrc: ["'self'", "wss:", "https:"],
      scriptSrc: ["'self'", "'unsafe-inline'"],
      styleSrc: ["'self'", "'unsafe-inline'"],
      imgSrc: ["'self'", "data:", "https:"],
    },
  },
}));

// CORS configuration
app.use(cors({
  origin: [
    'https://app.cloudtolocalllm.online',
    'https://cloudtolocalllm.online',
    'https://docs.cloudtolocalllm.online',
    'http://localhost:3000', // Development
    'http://localhost:8080'  // Development
  ],
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization']
}));

// Rate limiting
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // limit each IP to 100 requests per windowMs
  message: 'Too many requests from this IP, please try again later.',
  standardHeaders: true,
  legacyHeaders: false,
});

app.use(limiter);

// Body parsing middleware
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Auth middleware
async function authenticateToken(req, res, next) {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];

  if (!token) {
    return res.status(401).json({ error: 'Access token required' });
  }

  try {
    // Get the signing key
    const decoded = jwt.decode(token, { complete: true });
    if (!decoded || !decoded.header.kid) {
      return res.status(401).json({ error: 'Invalid token format' });
    }

    const key = await jwksClientInstance.getSigningKey(decoded.header.kid);
    const signingKey = key.getPublicKey();

    // Verify the token
    const verified = jwt.verify(token, signingKey, {
      audience: AUTH0_AUDIENCE,
      issuer: `https://${AUTH0_DOMAIN}/`,
      algorithms: ['RS256']
    });

    req.user = verified;
    next();
  } catch (error) {
    logger.error('Token verification failed:', error);
    return res.status(403).json({ error: 'Invalid or expired token' });
  }
}

// Store for active bridge connections
const bridgeConnections = new Map();

// WebSocket server for bridge connections
const wss = new WebSocket.Server({ 
  server,
  path: '/ws/bridge',
  verifyClient: async (info) => {
    try {
      const url = new URL(info.req.url, `http://${info.req.headers.host}`);
      const token = url.searchParams.get('token');
      
      if (!token) {
        logger.warn('WebSocket connection rejected: No token provided');
        return false;
      }

      // Verify token (similar to HTTP middleware)
      const decoded = jwt.decode(token, { complete: true });
      if (!decoded || !decoded.header.kid) {
        logger.warn('WebSocket connection rejected: Invalid token format');
        return false;
      }

      const key = await jwksClientInstance.getSigningKey(decoded.header.kid);
      const signingKey = key.getPublicKey();

      const verified = jwt.verify(token, signingKey, {
        audience: AUTH0_AUDIENCE,
        issuer: `https://${AUTH0_DOMAIN}/`,
        algorithms: ['RS256']
      });

      // Store user info for the connection
      info.req.user = verified;
      return true;
    } catch (error) {
      logger.error('WebSocket token verification failed:', error);
      return false;
    }
  }
});

wss.on('connection', (ws, req) => {
  const bridgeId = uuidv4();
  const userId = req.user.sub;
  
  logger.info(`Bridge connected: ${bridgeId} for user: ${userId}`);
  
  // Store connection
  bridgeConnections.set(bridgeId, {
    ws,
    userId,
    bridgeId,
    connectedAt: new Date(),
    lastPing: new Date()
  });

  // Send welcome message
  ws.send(JSON.stringify({
    type: 'auth',
    id: uuidv4(),
    data: { success: true, bridgeId },
    timestamp: new Date().toISOString()
  }));

  // Handle messages from bridge
  ws.on('message', (data) => {
    try {
      const message = JSON.parse(data);
      handleBridgeMessage(bridgeId, message);
    } catch (error) {
      logger.error(`Failed to parse message from bridge ${bridgeId}:`, error);
    }
  });

  // Handle connection close
  ws.on('close', () => {
    logger.info(`Bridge disconnected: ${bridgeId}`);
    bridgeConnections.delete(bridgeId);
  });

  // Handle errors
  ws.on('error', (error) => {
    logger.error(`Bridge ${bridgeId} error:`, error);
    bridgeConnections.delete(bridgeId);
  });

  // Send ping every 30 seconds
  const pingInterval = setInterval(() => {
    if (ws.readyState === WebSocket.OPEN) {
      ws.send(JSON.stringify({
        type: 'ping',
        id: uuidv4(),
        timestamp: new Date().toISOString()
      }));
    } else {
      clearInterval(pingInterval);
    }
  }, 30000);
});

// Handle messages from bridge
function handleBridgeMessage(bridgeId, message) {
  const bridge = bridgeConnections.get(bridgeId);
  if (!bridge) {
    logger.warn(`Received message from unknown bridge: ${bridgeId}`);
    return;
  }

  bridge.lastPing = new Date();

  switch (message.type) {
    case 'pong':
      // Update last ping time
      break;
    
    case 'response':
      // Handle Ollama response - forward to web client if needed
      logger.debug(`Received Ollama response from bridge ${bridgeId}`);
      break;
    
    default:
      logger.warn(`Unknown message type from bridge ${bridgeId}: ${message.type}`);
  }
}

// API Routes

// Health check
app.get('/health', (req, res) => {
  res.json({ 
    status: 'healthy', 
    timestamp: new Date().toISOString(),
    bridges: bridgeConnections.size
  });
});

// Bridge status
app.get('/api/ollama/bridge/status', authenticateToken, (req, res) => {
  const userBridges = Array.from(bridgeConnections.values())
    .filter(bridge => bridge.userId === req.user.sub);

  res.json({
    connected: userBridges.length > 0,
    bridges: userBridges.map(bridge => ({
      bridgeId: bridge.bridgeId,
      connectedAt: bridge.connectedAt,
      lastPing: bridge.lastPing
    }))
  });
});

// Bridge registration
app.post('/api/ollama/bridge/register', authenticateToken, (req, res) => {
  const { bridge_id, version, platform } = req.body;
  
  logger.info(`Bridge registration: ${bridge_id} v${version} on ${platform} for user ${req.user.sub}`);
  
  res.json({
    success: true,
    message: 'Bridge registered successfully',
    bridgeId: bridge_id
  });
});

// Ollama proxy endpoints
app.all('/api/ollama/*', authenticateToken, async (req, res) => {
  const userBridges = Array.from(bridgeConnections.values())
    .filter(bridge => bridge.userId === req.user.sub);

  if (userBridges.length === 0) {
    return res.status(503).json({ 
      error: 'No bridge connected',
      message: 'Please ensure the CloudToLocalLLM desktop bridge is running and connected.'
    });
  }

  // Use the first available bridge
  const bridge = userBridges[0];
  const requestId = uuidv4();

  // Forward request to bridge
  const bridgeMessage = {
    type: 'request',
    id: requestId,
    data: {
      method: req.method,
      path: req.path.replace('/api/ollama', ''),
      headers: req.headers,
      body: req.body ? JSON.stringify(req.body) : undefined
    },
    timestamp: new Date().toISOString()
  };

  try {
    bridge.ws.send(JSON.stringify(bridgeMessage));
    
    // For now, return a placeholder response
    // In a full implementation, you'd wait for the bridge response
    res.json({ 
      message: 'Request forwarded to bridge',
      requestId,
      bridgeId: bridge.bridgeId
    });
  } catch (error) {
    logger.error(`Failed to forward request to bridge ${bridge.bridgeId}:`, error);
    res.status(500).json({ error: 'Failed to communicate with bridge' });
  }
});

// Error handling middleware
app.use((error, req, res, next) => {
  logger.error('Unhandled error:', error);
  res.status(500).json({ 
    error: 'Internal server error',
    message: process.env.NODE_ENV === 'development' ? error.message : 'Something went wrong'
  });
});

// 404 handler
app.use((req, res) => {
  res.status(404).json({ error: 'Not found' });
});

// Start server
server.listen(PORT, () => {
  logger.info(`CloudToLocalLLM API Backend listening on port ${PORT}`);
  logger.info(`Environment: ${process.env.NODE_ENV || 'development'}`);
  logger.info(`Auth0 Domain: ${AUTH0_DOMAIN}`);
  logger.info(`Auth0 Audience: ${AUTH0_AUDIENCE}`);
});
