/**
 * Encrypted Tunnel API Routes
 * 
 * Provides secure key exchange endpoints for zero-knowledge encrypted tunneling.
 * The server acts as a relay for encrypted data and cannot decrypt tunnel traffic.
 */

import express from 'express';
import { authenticateJWT, extractUserId } from '../middleware/auth.js';
import logger from '../logger.js';

const router = express.Router();

// In-memory storage for encrypted public keys (temporary, per-session)
// Note: Server cannot decrypt these - they're encrypted with user's JWT
const encryptedPublicKeys = new Map();
const activeSessions = new Map();

/**
 * POST /api/encrypted-tunnel/register-key
 * Register encrypted public key for secure key exchange
 */
router.post('/register-key', authenticateJWT, async (req, res) => {
  try {
    const userId = extractUserId(req);
    const { encryptedPublicKey, keyFingerprint } = req.body;

    if (!encryptedPublicKey || !keyFingerprint) {
      return res.status(400).json({
        error: 'Missing encrypted public key or fingerprint',
        code: 'MISSING_KEY_DATA'
      });
    }

    // Store encrypted public key (server cannot decrypt this)
    encryptedPublicKeys.set(userId, {
      encryptedPublicKey,
      keyFingerprint,
      registeredAt: new Date(),
      expiresAt: new Date(Date.now() + 24 * 60 * 60 * 1000), // 24 hours
    });

    logger.info(`🔐 [EncryptedTunnel] Public key registered for user ${userId}`, {
      keyFingerprint,
      userId
    });

    res.json({
      success: true,
      message: 'Public key registered successfully',
      keyFingerprint,
      expiresAt: encryptedPublicKeys.get(userId).expiresAt
    });

  } catch (error) {
    logger.error('🔐 [EncryptedTunnel] Key registration failed', error);
    
    res.status(500).json({
      error: 'Failed to register public key',
      code: 'KEY_REGISTRATION_FAILED',
      details: error.message
    });
  }
});

/**
 * GET /api/encrypted-tunnel/get-key/:userId
 * Retrieve encrypted public key for key exchange
 */
router.get('/get-key/:userId', authenticateJWT, async (req, res) => {
  try {
    const requestingUserId = extractUserId(req);
    const { userId } = req.params;

    // Only allow users to get their own keys or keys they're authorized to access
    if (requestingUserId !== userId) {
      return res.status(403).json({
        error: 'Unauthorized to access this user\'s key',
        code: 'UNAUTHORIZED_KEY_ACCESS'
      });
    }

    const keyData = encryptedPublicKeys.get(userId);
    
    if (!keyData) {
      return res.status(404).json({
        error: 'No public key found for user',
        code: 'KEY_NOT_FOUND'
      });
    }

    // Check if key has expired
    if (new Date() > keyData.expiresAt) {
      encryptedPublicKeys.delete(userId);
      return res.status(410).json({
        error: 'Public key has expired',
        code: 'KEY_EXPIRED'
      });
    }

    logger.debug(`🔐 [EncryptedTunnel] Public key retrieved for user ${userId}`, {
      keyFingerprint: keyData.keyFingerprint,
      requestingUserId
    });

    res.json({
      success: true,
      encryptedPublicKey: keyData.encryptedPublicKey,
      keyFingerprint: keyData.keyFingerprint,
      registeredAt: keyData.registeredAt,
      expiresAt: keyData.expiresAt
    });

  } catch (error) {
    logger.error('🔐 [EncryptedTunnel] Key retrieval failed', error);
    
    res.status(500).json({
      error: 'Failed to retrieve public key',
      code: 'KEY_RETRIEVAL_FAILED',
      details: error.message
    });
  }
});

/**
 * POST /api/encrypted-tunnel/establish-session
 * Establish encrypted tunnel session
 */
router.post('/establish-session', authenticateJWT, async (req, res) => {
  try {
    const userId = extractUserId(req);
    const { sessionId, encryptedSessionData } = req.body;

    if (!sessionId || !encryptedSessionData) {
      return res.status(400).json({
        error: 'Missing session ID or encrypted session data',
        code: 'MISSING_SESSION_DATA'
      });
    }

    // Store session info (server cannot decrypt session data)
    activeSessions.set(sessionId, {
      userId,
      encryptedSessionData,
      establishedAt: new Date(),
      lastActivity: new Date(),
      expiresAt: new Date(Date.now() + 2 * 60 * 60 * 1000), // 2 hours
    });

    logger.info(`🔐 [EncryptedTunnel] Session established for user ${userId}`, {
      sessionId,
      userId
    });

    res.json({
      success: true,
      message: 'Encrypted session established',
      sessionId,
      expiresAt: activeSessions.get(sessionId).expiresAt
    });

  } catch (error) {
    logger.error('🔐 [EncryptedTunnel] Session establishment failed', error);
    
    res.status(500).json({
      error: 'Failed to establish session',
      code: 'SESSION_ESTABLISHMENT_FAILED',
      details: error.message
    });
  }
});

/**
 * GET /api/encrypted-tunnel/session/:sessionId
 * Get session info (for validation)
 */
router.get('/session/:sessionId', authenticateJWT, async (req, res) => {
  try {
    const userId = extractUserId(req);
    const { sessionId } = req.params;

    const sessionData = activeSessions.get(sessionId);
    
    if (!sessionData) {
      return res.status(404).json({
        error: 'Session not found',
        code: 'SESSION_NOT_FOUND'
      });
    }

    // Only allow session owner to access session info
    if (sessionData.userId !== userId) {
      return res.status(403).json({
        error: 'Unauthorized to access this session',
        code: 'UNAUTHORIZED_SESSION_ACCESS'
      });
    }

    // Check if session has expired
    if (new Date() > sessionData.expiresAt) {
      activeSessions.delete(sessionId);
      return res.status(410).json({
        error: 'Session has expired',
        code: 'SESSION_EXPIRED'
      });
    }

    // Update last activity
    sessionData.lastActivity = new Date();

    res.json({
      success: true,
      sessionId,
      userId: sessionData.userId,
      establishedAt: sessionData.establishedAt,
      lastActivity: sessionData.lastActivity,
      expiresAt: sessionData.expiresAt,
      isActive: true
    });

  } catch (error) {
    logger.error('🔐 [EncryptedTunnel] Session info retrieval failed', error);
    
    res.status(500).json({
      error: 'Failed to retrieve session info',
      code: 'SESSION_INFO_FAILED',
      details: error.message
    });
  }
});

/**
 * DELETE /api/encrypted-tunnel/session/:sessionId
 * Terminate encrypted session
 */
router.delete('/session/:sessionId', authenticateJWT, async (req, res) => {
  try {
    const userId = extractUserId(req);
    const { sessionId } = req.params;

    const sessionData = activeSessions.get(sessionId);
    
    if (!sessionData) {
      return res.status(404).json({
        error: 'Session not found',
        code: 'SESSION_NOT_FOUND'
      });
    }

    // Only allow session owner to terminate session
    if (sessionData.userId !== userId) {
      return res.status(403).json({
        error: 'Unauthorized to terminate this session',
        code: 'UNAUTHORIZED_SESSION_TERMINATION'
      });
    }

    // Remove session
    activeSessions.delete(sessionId);

    logger.info(`🔐 [EncryptedTunnel] Session terminated for user ${userId}`, {
      sessionId,
      userId
    });

    res.json({
      success: true,
      message: 'Session terminated successfully',
      sessionId
    });

  } catch (error) {
    logger.error('🔐 [EncryptedTunnel] Session termination failed', error);
    
    res.status(500).json({
      error: 'Failed to terminate session',
      code: 'SESSION_TERMINATION_FAILED',
      details: error.message
    });
  }
});

/**
 * GET /api/encrypted-tunnel/health
 * Health check endpoint
 */
router.get('/health', (req, res) => {
  const now = new Date();
  
  // Clean up expired keys and sessions
  for (const [userId, keyData] of encryptedPublicKeys.entries()) {
    if (now > keyData.expiresAt) {
      encryptedPublicKeys.delete(userId);
    }
  }
  
  for (const [sessionId, sessionData] of activeSessions.entries()) {
    if (now > sessionData.expiresAt) {
      activeSessions.delete(sessionId);
    }
  }

  res.json({
    success: true,
    service: 'encrypted-tunnel',
    timestamp: now.toISOString(),
    stats: {
      activeKeys: encryptedPublicKeys.size,
      activeSessions: activeSessions.size,
    }
  });
});

// Cleanup expired data every 5 minutes
setInterval(() => {
  const now = new Date();
  let cleanedKeys = 0;
  let cleanedSessions = 0;
  
  // Clean expired keys
  for (const [userId, keyData] of encryptedPublicKeys.entries()) {
    if (now > keyData.expiresAt) {
      encryptedPublicKeys.delete(userId);
      cleanedKeys++;
    }
  }
  
  // Clean expired sessions
  for (const [sessionId, sessionData] of activeSessions.entries()) {
    if (now > sessionData.expiresAt) {
      activeSessions.delete(sessionId);
      cleanedSessions++;
    }
  }
  
  if (cleanedKeys > 0 || cleanedSessions > 0) {
    logger.info('🔐 [EncryptedTunnel] Cleaned up expired data', {
      cleanedKeys,
      cleanedSessions
    });
  }
}, 5 * 60 * 1000);

export default router;
