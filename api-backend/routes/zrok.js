/**
 * Zrok API Routes - REST endpoints for zrok tunnel management
 * 
 * Provides HTTP endpoints for:
 * - Desktop client tunnel registration
 * - Container tunnel discovery
 * - Health monitoring and heartbeat updates
 * - Registry statistics and management
 */

import express from 'express';
import { zrokRegistry } from '../zrok-registry.js';
import { authenticateJWT, extractUserId } from '../middleware/auth.js';
import logger from '../logger.js';

const router = express.Router();

/**
 * POST /api/zrok/register
 * Register a zrok tunnel from desktop client
 */
router.post('/register', authenticateJWT, async (req, res) => {
  try {
    const userId = extractUserId(req);
    const { tunnelInfo } = req.body;
    const authToken = req.headers.authorization;

    if (!tunnelInfo) {
      return res.status(400).json({
        error: 'Missing tunnel information',
        code: 'MISSING_TUNNEL_INFO'
      });
    }

    const result = await zrokRegistry.registerTunnel(userId, tunnelInfo, authToken);

    res.status(201).json({
      success: true,
      data: result,
      message: 'Zrok tunnel registered successfully'
    });

    logger.info(`🌐 [ZrokAPI] Tunnel registered for user ${userId}`, {
      tunnelId: result.tunnelId,
      publicUrl: tunnelInfo.publicUrl
    });

  } catch (error) {
    logger.error('🌐 [ZrokAPI] Tunnel registration failed', error);
    
    res.status(500).json({
      error: 'Failed to register tunnel',
      code: 'REGISTRATION_FAILED',
      details: error.message
    });
  }
});

/**
 * GET /api/zrok/discover
 * Discover available zrok tunnels for authenticated user
 */
router.get('/discover', authenticateJWT, async (req, res) => {
  try {
    const userId = extractUserId(req);
    const result = await zrokRegistry.discoverTunnels(userId);

    res.json({
      success: true,
      data: result,
      timestamp: new Date().toISOString()
    });

    logger.debug(`🌐 [ZrokAPI] Tunnel discovery for user ${userId}`, {
      available: result.available
    });

  } catch (error) {
    logger.error('🌐 [ZrokAPI] Tunnel discovery failed', error);
    
    res.status(500).json({
      error: 'Failed to discover tunnels',
      code: 'DISCOVERY_FAILED',
      details: error.message
    });
  }
});

/**
 * GET /api/zrok/discover/:userId
 * Container-specific tunnel discovery (with container authentication)
 */
router.get('/discover/:userId', async (req, res) => {
  try {
    const { userId } = req.params;
    const containerToken = req.headers['x-container-token'];
    const containerId = req.headers['x-container-id'];

    // Validate container authentication
    if (!containerToken || !containerId) {
      return res.status(401).json({
        error: 'Container authentication required',
        code: 'CONTAINER_AUTH_REQUIRED'
      });
    }

    // TODO: Implement container token validation
    // For now, we'll use a simple validation
    if (!this.validateContainerToken(containerToken, containerId)) {
      return res.status(403).json({
        error: 'Invalid container credentials',
        code: 'INVALID_CONTAINER_CREDENTIALS'
      });
    }

    // Associate container with user
    await zrokRegistry.associateContainer(containerId, userId);

    const result = await zrokRegistry.discoverTunnels(userId);

    res.json({
      success: true,
      data: result,
      containerId,
      timestamp: new Date().toISOString()
    });

    logger.info(`🌐 [ZrokAPI] Container ${containerId} discovered tunnels for user ${userId}`, {
      available: result.available
    });

  } catch (error) {
    logger.error('🌐 [ZrokAPI] Container tunnel discovery failed', error);
    
    res.status(500).json({
      error: 'Failed to discover tunnels',
      code: 'CONTAINER_DISCOVERY_FAILED',
      details: error.message
    });
  }
});

/**
 * POST /api/zrok/heartbeat
 * Update tunnel heartbeat from desktop client
 */
router.post('/heartbeat', authenticateJWT, async (req, res) => {
  try {
    const userId = extractUserId(req);
    const { tunnelId } = req.body;

    if (!tunnelId) {
      return res.status(400).json({
        error: 'Missing tunnel ID',
        code: 'MISSING_TUNNEL_ID'
      });
    }

    const result = await zrokRegistry.updateHeartbeat(userId, tunnelId);

    res.json({
      success: true,
      data: result,
      timestamp: new Date().toISOString()
    });

    logger.debug(`🌐 [ZrokAPI] Heartbeat updated for tunnel ${tunnelId}`);

  } catch (error) {
    logger.error('🌐 [ZrokAPI] Heartbeat update failed', error);
    
    res.status(500).json({
      error: 'Failed to update heartbeat',
      code: 'HEARTBEAT_FAILED',
      details: error.message
    });
  }
});

/**
 * DELETE /api/zrok/unregister
 * Unregister a zrok tunnel
 */
router.delete('/unregister', authenticateJWT, async (req, res) => {
  try {
    const userId = extractUserId(req);
    const { tunnelId } = req.body;

    if (!tunnelId) {
      return res.status(400).json({
        error: 'Missing tunnel ID',
        code: 'MISSING_TUNNEL_ID'
      });
    }

    const result = await zrokRegistry.unregisterTunnel(userId, tunnelId);

    res.json({
      success: true,
      data: result,
      message: 'Tunnel unregistered successfully'
    });

    logger.info(`🌐 [ZrokAPI] Tunnel ${tunnelId} unregistered for user ${userId}`);

  } catch (error) {
    logger.error('🌐 [ZrokAPI] Tunnel unregistration failed', error);
    
    res.status(500).json({
      error: 'Failed to unregister tunnel',
      code: 'UNREGISTRATION_FAILED',
      details: error.message
    });
  }
});

/**
 * GET /api/zrok/health/:tunnelId
 * Get health status for a specific tunnel
 */
router.get('/health/:tunnelId', authenticateJWT, async (req, res) => {
  try {
    const { tunnelId } = req.params;
    const userId = extractUserId(req);

    // Verify tunnel belongs to user
    const userTunnel = zrokRegistry.userTunnels.get(userId);
    if (!userTunnel || userTunnel.tunnelId !== tunnelId) {
      return res.status(404).json({
        error: 'Tunnel not found',
        code: 'TUNNEL_NOT_FOUND'
      });
    }

    const healthStatus = zrokRegistry.tunnelHealth.get(tunnelId);

    res.json({
      success: true,
      data: {
        tunnelId,
        health: healthStatus || { isHealthy: false, lastCheck: null },
        tunnel: {
          isActive: userTunnel.isActive,
          publicUrl: userTunnel.publicUrl,
          lastHeartbeat: userTunnel.lastHeartbeat
        }
      },
      timestamp: new Date().toISOString()
    });

  } catch (error) {
    logger.error('🌐 [ZrokAPI] Health check failed', error);
    
    res.status(500).json({
      error: 'Failed to get tunnel health',
      code: 'HEALTH_CHECK_FAILED',
      details: error.message
    });
  }
});

/**
 * GET /api/zrok/stats
 * Get registry statistics (admin endpoint)
 */
router.get('/stats', async (req, res) => {
  try {
    // TODO: Add admin authentication
    const stats = zrokRegistry.getRegistryStats();

    res.json({
      success: true,
      data: stats,
      timestamp: new Date().toISOString()
    });

  } catch (error) {
    logger.error('🌐 [ZrokAPI] Stats retrieval failed', error);
    
    res.status(500).json({
      error: 'Failed to get registry stats',
      code: 'STATS_FAILED',
      details: error.message
    });
  }
});

/**
 * POST /api/zrok/container/associate
 * Associate container with user (internal endpoint)
 */
router.post('/container/associate', async (req, res) => {
  try {
    const { containerId, userId } = req.body;
    const containerToken = req.headers['x-container-token'];

    if (!containerId || !userId || !containerToken) {
      return res.status(400).json({
        error: 'Missing required parameters',
        code: 'MISSING_PARAMETERS'
      });
    }

    // TODO: Validate container token
    if (!this.validateContainerToken(containerToken, containerId)) {
      return res.status(403).json({
        error: 'Invalid container credentials',
        code: 'INVALID_CONTAINER_CREDENTIALS'
      });
    }

    const result = await zrokRegistry.associateContainer(containerId, userId);

    res.json({
      success: true,
      data: result,
      message: 'Container associated successfully'
    });

    logger.info(`🌐 [ZrokAPI] Container ${containerId} associated with user ${userId}`);

  } catch (error) {
    logger.error('🌐 [ZrokAPI] Container association failed', error);
    
    res.status(500).json({
      error: 'Failed to associate container',
      code: 'ASSOCIATION_FAILED',
      details: error.message
    });
  }
});

/**
 * Validate container token (placeholder implementation)
 * TODO: Implement proper container authentication
 */
function validateContainerToken(token, containerId) {
  // For now, accept any token that matches a simple pattern
  // In production, this should validate against a secure token store
  return token && token.startsWith('container-') && containerId;
}

// Error handling middleware
router.use((error, req, res, next) => {
  logger.error('🌐 [ZrokAPI] Unhandled error', error);
  
  res.status(500).json({
    error: 'Internal server error',
    code: 'INTERNAL_ERROR',
    message: 'An unexpected error occurred'
  });
});

export default router;
