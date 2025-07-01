import { WebSocketServer } from 'ws';
import http from 'http';
import jwt from 'jsonwebtoken';
import winston from 'winston';
import { ZrokDiscoveryService, ContainerConnectionManager } from './zrok-discovery.js';

// Configuration from environment variables
const PORT = process.env.PROXY_PORT || 8080;
const LOG_LEVEL = process.env.LOG_LEVEL || 'info';
const USER_ID = process.env.USER_ID; // Injected by container orchestrator
const PROXY_ID = process.env.PROXY_ID; // Unique proxy identifier
const API_BASE_URL = process.env.API_BASE_URL || 'http://api-backend:8080';
const ZROK_DISCOVERY_ENABLED = process.env.ZROK_DISCOVERY_ENABLED === 'true';

// Initialize logger for streaming proxy
const logger = winston.createLogger({
  level: LOG_LEVEL,
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.errors({ stack: true }),
    winston.format.json()
  ),
  defaultMeta: {
    service: 'streaming-proxy',
    userId: USER_ID,
    proxyId: PROXY_ID
  },
  transports: [
    new winston.transports.Console({
      format: winston.format.combine(
        winston.format.timestamp(),
        winston.format.simple()
      )
    })
  ]
});

// Connection tracking for streaming sessions
const connections = new Map();
let connectionCount = 0;

// Initialize zrok discovery service if enabled
let zrokDiscovery = null;
let connectionManager = null;

if (ZROK_DISCOVERY_ENABLED && USER_ID) {
  zrokDiscovery = new ZrokDiscoveryService(USER_ID, API_BASE_URL);
  connectionManager = new ContainerConnectionManager(USER_ID, zrokDiscovery);

  logger.info('🌐 [Proxy] Zrok discovery enabled for user', { userId: USER_ID });
} else {
  logger.info('🌐 [Proxy] Zrok discovery disabled or no user ID provided');
}

// HTTP server for health checks and basic endpoints
const server = http.createServer((req, res) => {
  const url = new URL(req.url, `http://${req.headers.host}`);

  switch (url.pathname) {
  case '/health':
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({
      status: 'healthy',
      userId: USER_ID,
      proxyId: PROXY_ID,
      connections: connectionCount,
      uptime: process.uptime(),
      timestamp: new Date().toISOString(),
      zrok: connectionManager ? connectionManager.getStatus() : { enabled: false }
    }));
    break;

  case '/metrics':
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({
      connections: connectionCount,
      activeStreams: connections.size,
      memoryUsage: process.memoryUsage(),
      uptime: process.uptime(),
      zrok: connectionManager ? connectionManager.getStatus() : { enabled: false }
    }));
    break;

  case '/zrok/status':
    res.writeHead(200, { 'Content-Type': 'application/json' });
    if (connectionManager) {
      res.end(JSON.stringify({
        success: true,
        data: connectionManager.getStatus(),
        timestamp: new Date().toISOString()
      }));
    } else {
      res.end(JSON.stringify({
        success: false,
        error: 'Zrok discovery not enabled',
        timestamp: new Date().toISOString()
      }));
    }
    break;

  default:
    res.writeHead(404, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ error: 'Not found' }));
  }
});

// WebSocket server for streaming proxy
const wss = new WebSocketServer({
  server,
  path: '/ws/stream',
  verifyClient: (info) => {
    try {
      const url = new URL(info.req.url, `http://${info.req.headers.host}`);
      const token = url.searchParams.get('token');

      if (!token) {
        logger.warn('WebSocket connection rejected: No token provided');
        return false;
      }

      // Basic JWT validation (signature verification handled by main API)
      const decoded = jwt.decode(token);
      if (!decoded || decoded.sub !== USER_ID) {
        logger.warn('WebSocket connection rejected: Invalid user token');
        return false;
      }

      return true;
    } catch (error) {
      logger.error('WebSocket token validation failed:', error);
      return false;
    }
  }
});

// Handle WebSocket connections for streaming
wss.on('connection', (ws, req) => {
  const connectionId = `conn_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
  connectionCount++;

  logger.info(`New streaming connection: ${connectionId}`, {
    connectionId,
    userAgent: req.headers['user-agent'],
    origin: req.headers.origin
  });

  // Store connection metadata
  connections.set(connectionId, {
    ws,
    connectedAt: new Date(),
    lastActivity: new Date(),
    bytesTransferred: 0
  });

  // Handle incoming messages (streaming data)
  ws.on('message', (data) => {
    const connection = connections.get(connectionId);
    if (connection) {
      connection.lastActivity = new Date();
      connection.bytesTransferred += data.length;

      // Forward streaming data to other connections (if needed)
      // This is where streaming relay logic would be implemented
      logger.debug(`Received ${data.length} bytes from ${connectionId}`);
    }
  });

  // Handle connection close
  ws.on('close', (code, reason) => {
    connectionCount--;
    const connection = connections.get(connectionId);

    if (connection) {
      const duration = Date.now() - connection.connectedAt.getTime();
      logger.info(`Streaming connection closed: ${connectionId}`, {
        connectionId,
        code,
        reason: reason.toString(),
        duration,
        bytesTransferred: connection.bytesTransferred
      });

      connections.delete(connectionId);
    }
  });

  // Handle connection errors
  ws.on('error', (error) => {
    logger.error(`Streaming connection error: ${connectionId}`, error);
    connections.delete(connectionId);
    connectionCount--;
  });

  // Send welcome message
  ws.send(JSON.stringify({
    type: 'welcome',
    connectionId,
    proxyId: PROXY_ID,
    timestamp: new Date().toISOString()
  }));
});

// Graceful shutdown handling
process.on('SIGTERM', () => {
  logger.info('Received SIGTERM, shutting down gracefully');

  // Stop zrok discovery service
  if (zrokDiscovery) {
    zrokDiscovery.stop();
  }

  // Close all WebSocket connections
  connections.forEach((connection, _connectionId) => {
    connection.ws.close(1001, 'Server shutting down');
  });

  // Close server
  server.close(() => {
    logger.info('Streaming proxy server closed');
    process.exit(0);
  });
});

process.on('SIGINT', () => {
  logger.info('Received SIGINT, shutting down gracefully');
  process.emit('SIGTERM');
});

// Initialize zrok discovery service
async function initializeZrokDiscovery() {
  if (zrokDiscovery) {
    try {
      await zrokDiscovery.start();
      logger.info('🌐 [Proxy] Zrok discovery service started successfully');
    } catch (error) {
      logger.error('🌐 [Proxy] Failed to start zrok discovery service', error);
      // Continue without zrok discovery
    }
  }
}

// Start the streaming proxy server
server.listen(PORT, async () => {
  logger.info(`Streaming proxy server listening on port ${PORT}`, {
    userId: USER_ID,
    proxyId: PROXY_ID,
    port: PORT,
    nodeVersion: process.version,
    zrokEnabled: ZROK_DISCOVERY_ENABLED
  });

  // Initialize zrok discovery after server starts
  await initializeZrokDiscovery();
});

// Periodic connection cleanup (remove stale connections)
setInterval(() => {
  const now = Date.now();
  const staleThreshold = 5 * 60 * 1000; // 5 minutes

  connections.forEach((connection, connectionId) => {
    if (now - connection.lastActivity.getTime() > staleThreshold) {
      logger.warn(`Closing stale connection: ${connectionId}`);
      connection.ws.close(1001, 'Connection stale');
      connections.delete(connectionId);
      connectionCount--;
    }
  });
}, 60000); // Check every minute
