import express from 'express';
import http from 'http';
import { WebSocketServer, WebSocket } from 'ws';
import cors from 'cors';
import helmet from 'helmet';
import rateLimit from 'express-rate-limit';
import jwt from 'jsonwebtoken';
import jwksClient from 'jwks-client';
import { v4 as uuidv4 } from 'uuid';
import winston from 'winston';
import dotenv from 'dotenv';
import { StreamingProxyManager } from './streaming-proxy-manager.js';
import zrokRoutes from './routes/zrok.js';
import adminRoutes from './routes/admin.js';

dotenv.config();

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
    new winston.transports.Console({
      format: winston.format.combine(
        winston.format.timestamp(),
        winston.format.simple()
      )
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
  jwksRequestsPerMinute: 5
});

// Express app setup
const app = express();
const server = http.createServer(app);

// Security middleware
app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ['\'self\''],
      connectSrc: ['\'self\'', 'wss:', 'https:'],
      scriptSrc: ['\'self\'', '\'unsafe-inline\''],
      styleSrc: ['\'self\'', '\'unsafe-inline\''],
      imgSrc: ['\'self\'', 'data:', 'https:']
    }
  }
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
  legacyHeaders: false
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

// Initialize streaming proxy manager
const proxyManager = new StreamingProxyManager();

// WebSocket server for bridge connections
const wss = new WebSocketServer({
  server,
  path: '/ws/bridge',
  verifyClient: async(info) => {
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
  const userId = req.user?.sub;

  if (!userId) {
    logger.error('WebSocket connection established but no user ID found');
    ws.close(1008, 'Authentication failed');
    return;
  }

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

    // Clean up any pending requests for this bridge
    cleanupPendingRequestsForBridge(bridgeId);
  });

  // Handle errors
  ws.on('error', (error) => {
    logger.error(`Bridge ${bridgeId} error:`, error);
    bridgeConnections.delete(bridgeId);

    // Clean up any pending requests for this bridge
    cleanupPendingRequestsForBridge(bridgeId);
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

// Store for pending requests (requestId -> response handler)
const pendingRequests = new Map();

// Clean up pending requests for a disconnected bridge
function cleanupPendingRequestsForBridge(bridgeId) {
  const requestsToCleanup = [];

  for (const [requestId, handler] of pendingRequests.entries()) {
    if (handler.bridgeId === bridgeId) {
      requestsToCleanup.push(requestId);
    }
  }

  requestsToCleanup.forEach(requestId => {
    const handler = pendingRequests.get(requestId);
    if (handler) {
      clearTimeout(handler.timeout);
      pendingRequests.delete(requestId);

      // Send error response to client
      handler.res.status(503).json({
        error: 'Bridge disconnected',
        message: 'The bridge connection was lost while processing your request.'
      });

      logger.warn(`Cleaned up pending request ${requestId} due to bridge ${bridgeId} disconnect`);
    }
  });
}

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
    logger.debug(`Received pong from bridge ${bridgeId}`);
    break;

  case 'response':
    // Handle Ollama response from bridge
    const requestId = message.id;
    const responseHandler = pendingRequests.get(requestId);

    if (responseHandler) {
      logger.debug(`Received Ollama response from bridge ${bridgeId} for request ${requestId}`);

      // Clear timeout and remove from pending requests
      clearTimeout(responseHandler.timeout);
      pendingRequests.delete(requestId);

      // Send response to original HTTP client
      const { res } = responseHandler;
      const responseData = message.data;

      // Set response headers
      if (responseData.headers) {
        Object.entries(responseData.headers).forEach(([key, value]) => {
          res.setHeader(key, value);
        });
      }

      // Send response with status code and body
      res.status(responseData.statusCode || 200);

      if (responseData.body) {
        // Try to parse as JSON first, fallback to plain text
        try {
          const jsonBody = JSON.parse(responseData.body);
          res.json(jsonBody);
        } catch {
          res.send(responseData.body);
        }
      } else {
        res.end();
      }
    } else {
      logger.warn(`Received response for unknown request: ${requestId}`);
    }
    break;

  default:
    logger.warn(`Unknown message type from bridge ${bridgeId}: ${message.type}`);
  }
}

// API Routes

// Zrok tunnel management routes
app.use('/api/zrok', zrokRoutes);

// Administrative routes
app.use('/api/admin', adminRoutes);

// Health check
app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    bridges: bridgeConnections.size
  });
});

// Bridge status
app.get('/ollama/bridge/status', authenticateToken, (req, res) => {
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
app.post('/ollama/bridge/register', authenticateToken, (req, res) => {
  const { bridge_id, version, platform } = req.body;

  logger.info(`Bridge registration: ${bridge_id} v${version} on ${platform} for user ${req.user.sub}`);

  res.json({
    success: true,
    message: 'Bridge registered successfully',
    bridgeId: bridge_id
  });
});

// Streaming Proxy Management Endpoints

// Start streaming proxy for user
app.post('/api/proxy/start', authenticateToken, async(req, res) => {
  try {
    const userId = req.user.sub;
    const userToken = req.headers.authorization;

    logger.info(`Starting streaming proxy for user: ${userId}`);

    const proxyMetadata = await proxyManager.provisionProxy(userId, userToken);

    res.json({
      success: true,
      message: 'Streaming proxy started successfully',
      proxy: {
        proxyId: proxyMetadata.proxyId,
        status: proxyMetadata.status,
        createdAt: proxyMetadata.createdAt
      }
    });
  } catch (error) {
    logger.error(`Failed to start proxy for user ${req.user.sub}:`, error);
    res.status(500).json({
      error: 'Failed to start streaming proxy',
      message: error.message
    });
  }
});

// Stop streaming proxy for user
app.post('/api/proxy/stop', authenticateToken, async(req, res) => {
  try {
    const userId = req.user.sub;

    logger.info(`Stopping streaming proxy for user: ${userId}`);

    const success = await proxyManager.terminateProxy(userId);

    if (success) {
      res.json({
        success: true,
        message: 'Streaming proxy stopped successfully'
      });
    } else {
      res.status(404).json({
        error: 'No active proxy found',
        message: 'No streaming proxy is currently running for this user'
      });
    }
  } catch (error) {
    logger.error(`Failed to stop proxy for user ${req.user.sub}:`, error);
    res.status(500).json({
      error: 'Failed to stop streaming proxy',
      message: error.message
    });
  }
});

// Provision streaming proxy for user (with test mode support)
app.post('/api/streaming-proxy/provision', authenticateToken, async(req, res) => {
  try {
    const userId = req.user.sub;
    const userToken = req.headers.authorization;
    const { testMode = false, zrokDiscoveryEnabled = false } = req.body;

    logger.info(`Provisioning streaming proxy for user: ${userId}, testMode: ${testMode}`);

    if (testMode) {
      // In test mode, simulate successful provisioning without creating actual containers
      logger.info(`Test mode: Simulating proxy provisioning for user ${userId}`);

      res.json({
        success: true,
        message: 'Streaming proxy provisioned successfully (test mode)',
        testMode: true,
        zrokDiscoveryEnabled: zrokDiscoveryEnabled,
        proxy: {
          proxyId: `test-proxy-${userId}`,
          status: 'simulated',
          createdAt: new Date().toISOString()
        }
      });
      return;
    }

    // Normal mode - provision actual proxy
    const proxyMetadata = await proxyManager.provisionProxy(userId, userToken);

    res.json({
      success: true,
      message: 'Streaming proxy provisioned successfully',
      testMode: false,
      zrokDiscoveryEnabled: zrokDiscoveryEnabled,
      proxy: {
        proxyId: proxyMetadata.proxyId,
        status: proxyMetadata.status,
        createdAt: proxyMetadata.createdAt
      }
    });
  } catch (error) {
    logger.error(`Failed to provision proxy for user ${req.user.sub}:`, error);
    res.status(500).json({
      error: 'Failed to provision streaming proxy',
      message: error.message,
      testMode: req.body.testMode || false
    });
  }
});

// Get streaming proxy status
app.get('/api/proxy/status', authenticateToken, async(req, res) => {
  try {
    const userId = req.user.sub;
    const status = await proxyManager.getProxyStatus(userId);

    // Update activity if proxy is running
    if (status.status === 'running') {
      proxyManager.updateProxyActivity(userId);
    }

    res.json(status);
  } catch (error) {
    logger.error(`Failed to get proxy status for user ${req.user.sub}:`, error);
    res.status(500).json({
      error: 'Failed to get proxy status',
      message: error.message
    });
  }
});

// Ollama proxy endpoints
app.all('/ollama/*', authenticateToken, async(req, res) => {
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

  // Set up timeout for the request (30 seconds)
  const timeout = setTimeout(() => {
    const responseHandler = pendingRequests.get(requestId);
    if (responseHandler) {
      pendingRequests.delete(requestId);
      logger.warn(`Request timeout for ${requestId}`);
      res.status(504).json({
        error: 'Gateway timeout',
        message: 'The bridge did not respond within the timeout period.'
      });
    }
  }, 30000);

  // Store response handler for correlation
  pendingRequests.set(requestId, {
    res,
    timeout,
    bridgeId: bridge.bridgeId,
    startTime: new Date()
  });

  // Forward request to bridge
  const bridgeMessage = {
    type: 'request',
    id: requestId,
    data: {
      method: req.method,
      path: req.path.replace('/ollama', ''),
      headers: req.headers,
      body: req.body ? JSON.stringify(req.body) : undefined
    },
    timestamp: new Date().toISOString()
  };

  try {
    bridge.ws.send(JSON.stringify(bridgeMessage));
    logger.debug(`Forwarded request ${requestId} to bridge ${bridge.bridgeId}`);
  } catch (error) {
    // Clean up on send failure
    clearTimeout(timeout);
    pendingRequests.delete(requestId);

    logger.error(`Failed to forward request to bridge ${bridge.bridgeId}:`, error);
    res.status(500).json({ error: 'Failed to communicate with bridge' });
  }
});

// Error handling middleware
app.use((error, req, res, _next) => {
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
