/**
 * Security Manager for CloudToLocalLLM CI/CD Agent
 * Handles authentication, authorization, and security features
 */

const crypto = require('crypto');
const jwt = require('jsonwebtoken');
const rateLimit = require('express-rate-limit');

class SecurityManager {
  constructor(config, logger) {
    this.config = config;
    this.logger = logger;
    this.apiKeys = new Set();
    this.sessions = new Map();
    
    this.initializeSecurity();
  }

  /**
   * Initialize security features
   */
  initializeSecurity() {
    // Load API keys from environment
    const apiKeysEnv = process.env.CICD_API_KEYS;
    if (apiKeysEnv) {
      apiKeysEnv.split(',').forEach(key => {
        this.apiKeys.add(key.trim());
      });
    }

    // Generate default API key if none configured
    if (this.apiKeys.size === 0) {
      const defaultKey = this.generateAPIKey();
      this.apiKeys.add(defaultKey);
      this.logger.warn(`No API keys configured. Generated default key: ${defaultKey}`);
    }

    this.logger.info(`Security manager initialized with ${this.apiKeys.size} API keys`);
  }

  /**
   * Generate a new API key
   */
  generateAPIKey() {
    return crypto.randomBytes(32).toString('hex');
  }

  /**
   * Middleware for API authentication
   */
  authenticate = (req, res, next) => {
    try {
      const authHeader = req.headers.authorization;
      const apiKey = req.headers['x-api-key'];

      // Check API key authentication
      if (apiKey && this.apiKeys.has(apiKey)) {
        req.user = { type: 'api_key', authenticated: true };
        return next();
      }

      // Check Bearer token authentication
      if (authHeader && authHeader.startsWith('Bearer ')) {
        const token = authHeader.substring(7);
        
        try {
          const decoded = jwt.verify(token, process.env.JWT_SECRET || 'default-secret');
          req.user = { ...decoded, type: 'jwt', authenticated: true };
          return next();
        } catch (jwtError) {
          this.logger.warn('Invalid JWT token:', jwtError.message);
        }
      }

      // Check session authentication
      const sessionId = req.headers['x-session-id'];
      if (sessionId && this.sessions.has(sessionId)) {
        const session = this.sessions.get(sessionId);
        if (session.expiresAt > new Date()) {
          req.user = { ...session.user, type: 'session', authenticated: true };
          return next();
        } else {
          this.sessions.delete(sessionId);
        }
      }

      // No valid authentication found
      res.status(401).json({ 
        error: 'Authentication required',
        message: 'Provide API key via X-API-Key header or Bearer token'
      });
    } catch (error) {
      this.logger.error('Authentication error:', error);
      res.status(500).json({ error: 'Authentication error' });
    }
  };

  /**
   * Rate limiting middleware
   */
  createRateLimit(options = {}) {
    return rateLimit({
      windowMs: options.windowMs || 15 * 60 * 1000, // 15 minutes
      max: options.max || 100, // limit each IP to 100 requests per windowMs
      message: {
        error: 'Too many requests',
        message: 'Rate limit exceeded. Please try again later.'
      },
      standardHeaders: true,
      legacyHeaders: false,
      ...options
    });
  }

  /**
   * Webhook signature verification
   */
  verifyWebhookSignature(payload, signature, secret) {
    if (!secret) {
      this.logger.warn('Webhook secret not configured');
      return true; // Allow in development
    }

    const hmac = crypto.createHmac('sha256', secret);
    const digest = 'sha256=' + hmac.update(payload).digest('hex');
    
    return crypto.timingSafeEqual(
      Buffer.from(signature, 'utf8'),
      Buffer.from(digest, 'utf8')
    );
  }

  /**
   * Create a new session
   */
  createSession(user, expiresInMs = 24 * 60 * 60 * 1000) { // 24 hours default
    const sessionId = crypto.randomBytes(32).toString('hex');
    const expiresAt = new Date(Date.now() + expiresInMs);

    this.sessions.set(sessionId, {
      user,
      createdAt: new Date(),
      expiresAt,
      lastAccess: new Date()
    });

    // Clean up expired sessions
    this.cleanupExpiredSessions();

    return sessionId;
  }

  /**
   * Revoke a session
   */
  revokeSession(sessionId) {
    return this.sessions.delete(sessionId);
  }

  /**
   * Clean up expired sessions
   */
  cleanupExpiredSessions() {
    const now = new Date();
    for (const [sessionId, session] of this.sessions.entries()) {
      if (session.expiresAt <= now) {
        this.sessions.delete(sessionId);
      }
    }
  }

  /**
   * Generate JWT token
   */
  generateJWT(payload, expiresIn = '24h') {
    const secret = process.env.JWT_SECRET || 'default-secret';
    return jwt.sign(payload, secret, { expiresIn });
  }

  /**
   * Verify JWT token
   */
  verifyJWT(token) {
    const secret = process.env.JWT_SECRET || 'default-secret';
    return jwt.verify(token, secret);
  }

  /**
   * Hash password (for future user management)
   */
  hashPassword(password) {
    const salt = crypto.randomBytes(16).toString('hex');
    const hash = crypto.pbkdf2Sync(password, salt, 10000, 64, 'sha512').toString('hex');
    return { salt, hash };
  }

  /**
   * Verify password
   */
  verifyPassword(password, salt, hash) {
    const verifyHash = crypto.pbkdf2Sync(password, salt, 10000, 64, 'sha512').toString('hex');
    return hash === verifyHash;
  }

  /**
   * Sanitize input to prevent injection attacks
   */
  sanitizeInput(input) {
    if (typeof input !== 'string') {
      return input;
    }

    // Remove potentially dangerous characters
    return input
      .replace(/[<>]/g, '') // Remove HTML tags
      .replace(/[;&|`$]/g, '') // Remove shell injection characters
      .trim();
  }

  /**
   * Validate build configuration for security
   */
  validateBuildConfig(buildConfig) {
    const errors = [];

    // Validate repository
    if (!buildConfig.repository || !buildConfig.repository.match(/^[a-zA-Z0-9_.-]+\/[a-zA-Z0-9_.-]+$/)) {
      errors.push('Invalid repository format');
    }

    // Validate branch name
    if (!buildConfig.branch || !buildConfig.branch.match(/^[a-zA-Z0-9_.-\/]+$/)) {
      errors.push('Invalid branch name');
    }

    // Validate platforms
    const allowedPlatforms = ['web', 'windows', 'linux'];
    if (buildConfig.platforms && !buildConfig.platforms.every(p => allowedPlatforms.includes(p))) {
      errors.push('Invalid platform specified');
    }

    // Validate commit SHA
    if (buildConfig.commitSha && buildConfig.commitSha !== 'HEAD' && !buildConfig.commitSha.match(/^[a-f0-9]{40}$/)) {
      errors.push('Invalid commit SHA format');
    }

    return {
      valid: errors.length === 0,
      errors
    };
  }

  /**
   * Log security events
   */
  logSecurityEvent(event, details = {}) {
    this.logger.warn(`Security event: ${event}`, {
      timestamp: new Date().toISOString(),
      event,
      ...details
    });
  }

  /**
   * Check if IP is allowed (basic IP filtering)
   */
  isIPAllowed(ip) {
    const allowedIPs = process.env.ALLOWED_IPS?.split(',') || [];
    const blockedIPs = process.env.BLOCKED_IPS?.split(',') || [];

    // Check blocked IPs first
    if (blockedIPs.includes(ip)) {
      return false;
    }

    // If no allowed IPs configured, allow all (except blocked)
    if (allowedIPs.length === 0) {
      return true;
    }

    // Check if IP is in allowed list
    return allowedIPs.includes(ip);
  }

  /**
   * Middleware for IP filtering
   */
  ipFilter = (req, res, next) => {
    const clientIP = req.ip || req.connection.remoteAddress;
    
    if (!this.isIPAllowed(clientIP)) {
      this.logSecurityEvent('blocked_ip_access', { ip: clientIP });
      return res.status(403).json({ 
        error: 'Access denied',
        message: 'Your IP address is not allowed to access this service'
      });
    }

    next();
  };

  /**
   * Get security status
   */
  getSecurityStatus() {
    return {
      apiKeysConfigured: this.apiKeys.size,
      activeSessions: this.sessions.size,
      jwtConfigured: !!process.env.JWT_SECRET,
      ipFilteringEnabled: !!(process.env.ALLOWED_IPS || process.env.BLOCKED_IPS),
      webhookSecretConfigured: !!process.env.GITHUB_WEBHOOK_SECRET
    };
  }

  /**
   * Rotate API keys
   */
  rotateAPIKeys() {
    const newKey = this.generateAPIKey();
    this.apiKeys.clear();
    this.apiKeys.add(newKey);
    
    this.logger.info('API keys rotated');
    return newKey;
  }
}

module.exports = SecurityManager;
