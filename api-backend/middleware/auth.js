/**
 * Authentication Middleware for CloudToLocalLLM API Backend
 * 
 * Provides JWT authentication and authorization for API endpoints
 * with Auth0 integration and user ID extraction utilities.
 */

import jwt from 'jsonwebtoken';
import jwksClient from 'jwks-client';
import logger from '../logger.js';

// Configuration
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

/**
 * JWT Authentication Middleware
 * Validates Auth0 JWT tokens and attaches user info to request
 */
export async function authenticateJWT(req, res, next) {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];

  if (!token) {
    return res.status(401).json({ 
      error: 'Access token required',
      code: 'MISSING_TOKEN'
    });
  }

  try {
    // Get the signing key
    const decoded = jwt.decode(token, { complete: true });
    if (!decoded || !decoded.header.kid) {
      return res.status(401).json({ 
        error: 'Invalid token format',
        code: 'INVALID_TOKEN_FORMAT'
      });
    }

    const key = await jwksClientInstance.getSigningKey(decoded.header.kid);
    const signingKey = key.getPublicKey();

    // Verify the token
    const verified = jwt.verify(token, signingKey, {
      audience: AUTH0_AUDIENCE,
      issuer: `https://${AUTH0_DOMAIN}/`,
      algorithms: ['RS256']
    });

    // Attach user info to request
    req.user = verified;
    req.userId = verified.sub;
    
    logger.debug(`🔐 [Auth] User authenticated: ${verified.sub}`);
    next();

  } catch (error) {
    logger.error('🔐 [Auth] Token verification failed:', error);
    
    let errorCode = 'TOKEN_VERIFICATION_FAILED';
    let errorMessage = 'Invalid or expired token';
    
    if (error.name === 'TokenExpiredError') {
      errorCode = 'TOKEN_EXPIRED';
      errorMessage = 'Token has expired';
    } else if (error.name === 'JsonWebTokenError') {
      errorCode = 'INVALID_TOKEN';
      errorMessage = 'Invalid token';
    } else if (error.name === 'NotBeforeError') {
      errorCode = 'TOKEN_NOT_ACTIVE';
      errorMessage = 'Token not active';
    }
    
    return res.status(403).json({ 
      error: errorMessage,
      code: errorCode
    });
  }
}

/**
 * Extract user ID from authenticated request
 * @param {Object} req - Express request object
 * @returns {string} User ID from JWT token
 */
export function extractUserId(req) {
  if (!req.user || !req.user.sub) {
    throw new Error('User not authenticated or user ID not available');
  }
  return req.user.sub;
}

/**
 * Extract user email from authenticated request
 * @param {Object} req - Express request object
 * @returns {string|null} User email from JWT token
 */
export function extractUserEmail(req) {
  return req.user?.email || null;
}

/**
 * Check if user has specific permission/scope
 * @param {string} requiredScope - Required scope/permission
 * @returns {Function} Express middleware function
 */
export function requireScope(requiredScope) {
  return (req, res, next) => {
    if (!req.user) {
      return res.status(401).json({
        error: 'Authentication required',
        code: 'AUTHENTICATION_REQUIRED'
      });
    }

    const userScopes = req.user.scope ? req.user.scope.split(' ') : [];
    
    if (!userScopes.includes(requiredScope)) {
      logger.warn(`🔐 [Auth] User ${req.user.sub} missing required scope: ${requiredScope}`);
      return res.status(403).json({
        error: 'Insufficient permissions',
        code: 'INSUFFICIENT_PERMISSIONS',
        requiredScope
      });
    }

    next();
  };
}

/**
 * Optional authentication middleware
 * Attaches user info if token is present and valid, but doesn't require it
 */
export async function optionalAuth(req, res, next) {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];

  if (!token) {
    // No token provided, continue without authentication
    return next();
  }

  try {
    // Try to verify token
    const decoded = jwt.decode(token, { complete: true });
    if (decoded && decoded.header.kid) {
      const key = await jwksClientInstance.getSigningKey(decoded.header.kid);
      const signingKey = key.getPublicKey();

      const verified = jwt.verify(token, signingKey, {
        audience: AUTH0_AUDIENCE,
        issuer: `https://${AUTH0_DOMAIN}/`,
        algorithms: ['RS256']
      });

      req.user = verified;
      req.userId = verified.sub;
      logger.debug(`🔐 [Auth] Optional auth successful: ${verified.sub}`);
    }
  } catch (error) {
    // Token verification failed, but that's okay for optional auth
    logger.debug('🔐 [Auth] Optional auth failed, continuing without authentication:', error.message);
  }

  next();
}

/**
 * Container authentication middleware
 * Validates container tokens for internal API calls
 */
export function authenticateContainer(req, res, next) {
  const containerToken = req.headers['x-container-token'];
  const containerId = req.headers['x-container-id'];

  if (!containerToken || !containerId) {
    return res.status(401).json({
      error: 'Container authentication required',
      code: 'CONTAINER_AUTH_REQUIRED'
    });
  }

  // TODO: Implement proper container token validation
  // For now, use a simple validation pattern
  if (!validateContainerToken(containerToken, containerId)) {
    return res.status(403).json({
      error: 'Invalid container credentials',
      code: 'INVALID_CONTAINER_CREDENTIALS'
    });
  }

  req.containerId = containerId;
  req.containerToken = containerToken;
  
  logger.debug(`🔐 [Auth] Container authenticated: ${containerId}`);
  next();
}

/**
 * Validate container token (placeholder implementation)
 * TODO: Implement proper container authentication
 */
function validateContainerToken(token, containerId) {
  // For now, accept any token that matches a simple pattern
  // In production, this should validate against a secure token store
  return token && token.startsWith('container-') && containerId;
}

/**
 * Admin authentication middleware
 * Requires admin role/scope for access with comprehensive role checking
 */
export function requireAdmin(req, res, next) {
  try {
    if (!req.user) {
      return res.status(401).json({
        error: 'Authentication required',
        code: 'AUTH_REQUIRED'
      });
    }

    // Check for admin role in multiple possible locations
    const userMetadata = req.user['https://cloudtolocalllm.com/user_metadata'] || {};
    const appMetadata = req.user['https://cloudtolocalllm.com/app_metadata'] || {};
    const userRoles = req.user['https://cloudtolocalllm.online/roles'] || [];
    const userScopes = req.user.scope ? req.user.scope.split(' ') : [];

    // Check various places where admin role might be stored
    const hasAdminRole =
      userMetadata.role === 'admin' ||
      appMetadata.role === 'admin' ||
      userRoles.includes('admin') ||
      userScopes.includes('admin') ||
      (req.user.permissions && req.user.permissions.includes('admin')) ||
      req.user.role === 'admin';

    if (!hasAdminRole) {
      logger.warn('🔥 [AdminAuth] Admin access denied', {
        userId: req.user.sub,
        userMetadata,
        appMetadata,
        userRoles,
        userScopes,
        permissions: req.user.permissions,
        userAgent: req.get('User-Agent'),
        ipAddress: req.ip
      });

      return res.status(403).json({
        error: 'Admin access required',
        code: 'ADMIN_ACCESS_REQUIRED',
        message: 'This operation requires administrative privileges'
      });
    }

    logger.info('🔥 [AdminAuth] Admin access granted', {
      userId: req.user.sub,
      role: userMetadata.role || appMetadata.role || 'admin',
      userAgent: req.get('User-Agent')
    });

    next();
  } catch (error) {
    logger.error('🔥 [AdminAuth] Admin role check failed', {
      error: error.message,
      userId: req.user?.sub
    });

    res.status(500).json({
      error: 'Admin role verification failed',
      code: 'ADMIN_CHECK_FAILED'
    });
  }
}

/**
 * Rate limiting by user ID
 * @param {Object} options - Rate limiting options
 * @returns {Function} Express middleware function
 */
export function rateLimitByUser(options = {}) {
  const { windowMs = 15 * 60 * 1000, max = 100 } = options;
  const userRequests = new Map();

  return (req, res, next) => {
    const userId = req.userId || req.ip; // Fallback to IP if no user ID
    const now = Date.now();
    
    // Clean up old entries
    for (const [key, data] of userRequests.entries()) {
      if (now - data.windowStart > windowMs) {
        userRequests.delete(key);
      }
    }
    
    // Get or create user request data
    let userData = userRequests.get(userId);
    if (!userData || now - userData.windowStart > windowMs) {
      userData = { count: 0, windowStart: now };
      userRequests.set(userId, userData);
    }
    
    userData.count++;
    
    if (userData.count > max) {
      return res.status(429).json({
        error: 'Too many requests',
        code: 'RATE_LIMIT_EXCEEDED',
        retryAfter: Math.ceil((windowMs - (now - userData.windowStart)) / 1000)
      });
    }
    
    next();
  };
}
