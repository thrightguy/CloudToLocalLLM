/**
 * Container-side Encrypted Tunnel Proxy
 * 
 * This runs inside user containers and provides:
 * - HTTP proxy that encrypts requests before sending to desktop
 * - WebSocket connection to encrypted tunnel bridge
 * - Zero-knowledge encryption (container cannot decrypt desktop responses)
 */

import WebSocket from 'ws';
import express from 'express';
import { createProxyMiddleware } from 'http-proxy-middleware';
import crypto from 'crypto';

class EncryptedTunnelProxy {
  constructor(options = {}) {
    this.bridgeUrl = options.bridgeUrl || 'wss://app.cloudtolocalllm.online/ws/encrypted-tunnel';
    this.authToken = options.authToken;
    this.userId = options.userId;
    this.localPort = options.localPort || 3001;
    
    // WebSocket connection to bridge
    this.ws = null;
    this.isConnected = false;
    
    // Encryption state
    this.sessionKey = null;
    this.sessionId = null;
    this.devicePublicKey = null;
    
    // HTTP proxy server
    this.app = express();
    this.server = null;
    
    // Pending requests
    this.pendingRequests = new Map();
    
    this.setupHttpProxy();
  }
  
  /**
   * Setup HTTP proxy server
   */
  setupHttpProxy() {
    // Health check endpoint
    this.app.get('/health', (req, res) => {
      res.json({
        status: 'ok',
        connected: this.isConnected,
        sessionId: this.sessionId,
        timestamp: new Date().toISOString()
      });
    });
    
    // Proxy all other requests through encrypted tunnel
    this.app.use('*', async (req, res) => {
      try {
        await this.proxyRequest(req, res);
      } catch (error) {
        console.error('🔐 [TunnelProxy] Proxy error:', error);
        res.status(500).json({
          error: 'Tunnel proxy error',
          details: error.message
        });
      }
    });
  }
  
  /**
   * Start the encrypted tunnel proxy
   */
  async start() {
    try {
      console.log('🔐 [TunnelProxy] Starting encrypted tunnel proxy...');
      
      // Connect to WebSocket bridge
      await this.connectToBridge();
      
      // Start HTTP proxy server
      this.server = this.app.listen(this.localPort, () => {
        console.log(`🔐 [TunnelProxy] HTTP proxy listening on port ${this.localPort}`);
      });
      
      console.log('🔐 [TunnelProxy] Encrypted tunnel proxy started successfully');
      
    } catch (error) {
      console.error('🔐 [TunnelProxy] Failed to start proxy:', error);
      throw error;
    }
  }
  
  /**
   * Stop the proxy
   */
  async stop() {
    console.log('🔐 [TunnelProxy] Stopping encrypted tunnel proxy...');
    
    if (this.ws) {
      this.ws.close();
    }
    
    if (this.server) {
      this.server.close();
    }
    
    console.log('🔐 [TunnelProxy] Proxy stopped');
  }
  
  /**
   * Connect to WebSocket bridge
   */
  async connectToBridge() {
    return new Promise((resolve, reject) => {
      const wsUrl = `${this.bridgeUrl}?token=${this.authToken}`;
      
      console.log('🔐 [TunnelProxy] Connecting to bridge:', wsUrl);
      
      this.ws = new WebSocket(wsUrl);
      
      this.ws.on('open', () => {
        console.log('🔐 [TunnelProxy] Connected to bridge');
        this.isConnected = true;
        this.sendKeyExchange();
        resolve();
      });
      
      this.ws.on('message', (data) => {
        this.handleMessage(data);
      });
      
      this.ws.on('error', (error) => {
        console.error('🔐 [TunnelProxy] WebSocket error:', error);
        this.isConnected = false;
        reject(error);
      });
      
      this.ws.on('close', () => {
        console.log('🔐 [TunnelProxy] WebSocket connection closed');
        this.isConnected = false;
      });
    });
  }
  
  /**
   * Send key exchange message
   */
  sendKeyExchange() {
    // Generate container-side key pair
    const keyPair = crypto.generateKeyPairSync('x25519', {
      publicKeyEncoding: { type: 'spki', format: 'der' },
      privateKeyEncoding: { type: 'pkcs8', format: 'der' }
    });
    
    this.containerKeyPair = keyPair;
    
    const message = {
      type: 'keyExchange',
      id: this.generateId(),
      publicKey: keyPair.publicKey.toString('base64'),
      userId: this.userId,
      timestamp: new Date().toISOString()
    };
    
    this.sendMessage(message);
    console.log('🔐 [TunnelProxy] Key exchange sent');
  }
  
  /**
   * Handle incoming WebSocket messages
   */
  handleMessage(data) {
    try {
      const message = JSON.parse(data.toString());
      
      if (message.encryptedData) {
        this.handleEncryptedMessage(message);
      } else {
        this.handleControlMessage(message);
      }
    } catch (error) {
      console.error('🔐 [TunnelProxy] Error parsing message:', error);
    }
  }
  
  /**
   * Handle control messages (unencrypted)
   */
  handleControlMessage(message) {
    switch (message.type) {
      case 'sessionEstablished':
        this.handleSessionEstablished(message);
        break;
      case 'error':
        console.error('🔐 [TunnelProxy] Bridge error:', message.error);
        break;
      default:
        console.log('🔐 [TunnelProxy] Unknown control message:', message.type);
    }
  }
  
  /**
   * Handle session established message
   */
  handleSessionEstablished(message) {
    try {
      // Derive shared secret using ECDH
      const remotePublicKey = crypto.createPublicKey({
        key: Buffer.from(message.publicKey, 'base64'),
        type: 'spki',
        format: 'der'
      });
      
      this.sessionKey = crypto.diffieHellman({
        privateKey: this.containerKeyPair.privateKey,
        publicKey: remotePublicKey
      });
      
      this.sessionId = message.sessionId;
      this.devicePublicKey = message.publicKey;
      
      console.log('🔐 [TunnelProxy] Encrypted session established:', this.sessionId);
    } catch (error) {
      console.error('🔐 [TunnelProxy] Failed to establish session:', error);
    }
  }
  
  /**
   * Handle encrypted messages
   */
  async handleEncryptedMessage(encryptedMessage) {
    try {
      if (!this.sessionKey) {
        throw new Error('No session key available');
      }
      
      // Decrypt message
      const decryptedData = this.decryptData(encryptedMessage.encryptedData);
      const message = JSON.parse(decryptedData);
      
      switch (message.type) {
        case 'httpResponse':
          this.handleHttpResponse(message);
          break;
        case 'pong':
          console.log('🔐 [TunnelProxy] Pong received');
          break;
        default:
          console.log('🔐 [TunnelProxy] Unknown encrypted message:', message.type);
      }
    } catch (error) {
      console.error('🔐 [TunnelProxy] Error handling encrypted message:', error);
    }
  }
  
  /**
   * Handle HTTP response from desktop
   */
  handleHttpResponse(response) {
    const pendingRequest = this.pendingRequests.get(response.correlationId);
    
    if (pendingRequest) {
      const { res } = pendingRequest;
      
      // Set response headers
      Object.entries(response.headers || {}).forEach(([key, value]) => {
        res.setHeader(key, value);
      });
      
      // Send response
      res.status(response.statusCode).send(response.body);
      
      // Clean up
      this.pendingRequests.delete(response.correlationId);
    } else {
      console.warn('🔐 [TunnelProxy] No pending request for correlation ID:', response.correlationId);
    }
  }
  
  /**
   * Proxy HTTP request through encrypted tunnel
   */
  async proxyRequest(req, res) {
    if (!this.isConnected || !this.sessionKey) {
      throw new Error('Tunnel not connected or session not established');
    }
    
    const requestId = this.generateId();
    
    // Store pending request
    this.pendingRequests.set(requestId, { req, res });
    
    // Create HTTP request message
    const httpRequest = {
      type: 'httpRequest',
      id: this.generateId(),
      method: req.method,
      path: req.originalUrl,
      headers: req.headers,
      body: req.body ? JSON.stringify(req.body) : undefined,
      correlationId: requestId,
      timestamp: new Date().toISOString()
    };
    
    // Send encrypted request
    await this.sendEncryptedMessage(httpRequest);
    
    // Set timeout for request
    setTimeout(() => {
      if (this.pendingRequests.has(requestId)) {
        this.pendingRequests.delete(requestId);
        if (!res.headersSent) {
          res.status(504).json({ error: 'Tunnel request timeout' });
        }
      }
    }, 30000); // 30 second timeout
  }
  
  /**
   * Send encrypted message
   */
  async sendEncryptedMessage(message) {
    if (!this.sessionKey) {
      throw new Error('No session key available');
    }
    
    const messageJson = JSON.stringify(message);
    const encryptedData = this.encryptData(messageJson);
    
    const encryptedMessage = {
      encryptedData,
      sessionId: this.sessionId,
      timestamp: new Date().toISOString()
    };
    
    this.sendMessage(encryptedMessage);
  }
  
  /**
   * Send unencrypted message
   */
  sendMessage(message) {
    if (this.ws && this.ws.readyState === WebSocket.OPEN) {
      this.ws.send(JSON.stringify(message));
    } else {
      throw new Error('WebSocket not connected');
    }
  }
  
  /**
   * Encrypt data using session key
   */
  encryptData(data) {
    const nonce = crypto.randomBytes(12);
    const cipher = crypto.createCipheriv('chacha20-poly1305', this.sessionKey, nonce);

    let encrypted = cipher.update(data, 'utf8');
    cipher.final();

    const authTag = cipher.getAuthTag();

    // Combine nonce + encrypted + authTag
    const combined = Buffer.concat([
      nonce,
      encrypted,
      authTag
    ]);

    return combined.toString('base64');
  }

  /**
   * Decrypt data using session key
   */
  decryptData(encryptedData) {
    const combined = Buffer.from(encryptedData, 'base64');

    // Extract components
    const nonce = combined.subarray(0, 12);
    const authTag = combined.subarray(combined.length - 16);
    const encrypted = combined.subarray(12, combined.length - 16);

    const decipher = crypto.createDecipheriv('chacha20-poly1305', this.sessionKey, nonce);
    decipher.setAuthTag(authTag);

    let decrypted = decipher.update(encrypted, 'utf8');
    decrypted += decipher.final('utf8');

    return decrypted;
  }
  
  /**
   * Generate unique ID
   */
  generateId() {
    return crypto.randomBytes(16).toString('base64').replace(/[/+=]/g, '');
  }
}

// Export for use in containers
export default EncryptedTunnelProxy;

// CLI usage
if (import.meta.url === `file://${process.argv[1]}`) {
  const proxy = new EncryptedTunnelProxy({
    bridgeUrl: process.env.BRIDGE_URL,
    authToken: process.env.AUTH_TOKEN,
    userId: process.env.USER_ID,
    localPort: parseInt(process.env.LOCAL_PORT) || 3001
  });
  
  proxy.start().catch(console.error);
  
  // Graceful shutdown
  process.on('SIGTERM', () => proxy.stop());
  process.on('SIGINT', () => proxy.stop());
}
