/**
 * Administrative API Routes for CloudToLocalLLM
 * 
 * Provides secure administrative endpoints for:
 * - Data flush operations with multi-step confirmation
 * - System statistics and monitoring
 * - Audit trail access
 * - Emergency data clearing
 * 
 * Security Features:
 * - Admin role/scope validation
 * - Multi-step confirmation process
 * - Comprehensive audit logging
 * - Rate limiting for sensitive operations
 */

import express from 'express';
import rateLimit from 'express-rate-limit';
import { authenticateJWT, requireAdmin } from '../middleware/auth.js';
import { adminDataFlushService } from '../admin-data-flush-service.js';
import logger from '../logger.js';

const router = express.Router();

// Rate limiting for admin operations
const adminRateLimit = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 10, // Limit each admin to 10 requests per windowMs
  message: {
    error: 'Too many admin requests',
    code: 'ADMIN_RATE_LIMIT_EXCEEDED'
  },
  standardHeaders: true,
  legacyHeaders: false,
});

// Strict rate limiting for flush operations
const flushRateLimit = rateLimit({
  windowMs: 60 * 60 * 1000, // 1 hour
  max: 3, // Maximum 3 flush operations per hour
  message: {
    error: 'Flush operation rate limit exceeded',
    code: 'FLUSH_RATE_LIMIT_EXCEEDED'
  },
  standardHeaders: true,
  legacyHeaders: false,
});

/**
 * GET /api/admin/system/stats
 * Get system statistics for admin dashboard
 */
router.get('/system/stats', authenticateJWT, requireAdmin, adminRateLimit, async (req, res) => {
  try {
    logger.info('🔥 [AdminAPI] System statistics requested', {
      adminUserId: req.user.sub,
      userAgent: req.get('User-Agent')
    });

    const stats = await adminDataFlushService.getSystemStatistics();

    res.json({
      success: true,
      data: stats,
      timestamp: new Date().toISOString()
    });

  } catch (error) {
    logger.error('🔥 [AdminAPI] Failed to get system statistics', {
      adminUserId: req.user.sub,
      error: error.message
    });

    res.status(500).json({
      error: 'Failed to retrieve system statistics',
      code: 'STATS_RETRIEVAL_FAILED',
      details: error.message
    });
  }
});

/**
 * POST /api/admin/flush/prepare
 * Prepare data flush operation and generate confirmation token
 */
router.post('/flush/prepare', authenticateJWT, requireAdmin, adminRateLimit, async (req, res) => {
  try {
    const { targetUserId, scope } = req.body;
    const adminUserId = req.user.sub;

    logger.info('🔥 [AdminAPI] Data flush preparation requested', {
      adminUserId,
      targetUserId: targetUserId || 'ALL_USERS',
      scope: scope || 'FULL_FLUSH',
      userAgent: req.get('User-Agent')
    });

    // Validate scope
    const validScopes = ['FULL_FLUSH', 'USER_SPECIFIC', 'CONTAINERS_ONLY', 'AUTH_ONLY'];
    const flushScope = scope || 'FULL_FLUSH';
    
    if (!validScopes.includes(flushScope)) {
      return res.status(400).json({
        error: 'Invalid flush scope',
        code: 'INVALID_FLUSH_SCOPE',
        validScopes
      });
    }

    // Generate confirmation token
    const confirmationData = adminDataFlushService.generateConfirmationToken(
      adminUserId,
      targetUserId || 'ALL_USERS'
    );

    // Log the preparation (but not the token)
    logger.info('🔥 [AdminAPI] Flush confirmation token generated', {
      adminUserId,
      targetUserId: targetUserId || 'ALL_USERS',
      scope: flushScope,
      expiresAt: confirmationData.expiresAt
    });

    res.json({
      success: true,
      message: 'Flush operation prepared. Use the confirmation token to execute.',
      confirmationToken: confirmationData.token,
      expiresAt: confirmationData.expiresAt,
      scope: flushScope,
      targetUserId: targetUserId || 'ALL_USERS',
      warning: 'This operation will permanently delete user data. Ensure you have proper authorization.'
    });

  } catch (error) {
    logger.error('🔥 [AdminAPI] Failed to prepare flush operation', {
      adminUserId: req.user.sub,
      error: error.message
    });

    res.status(500).json({
      error: 'Failed to prepare flush operation',
      code: 'FLUSH_PREPARATION_FAILED',
      details: error.message
    });
  }
});

/**
 * POST /api/admin/flush/execute
 * Execute data flush operation with confirmation token
 */
router.post('/flush/execute', authenticateJWT, requireAdmin, flushRateLimit, async (req, res) => {
  try {
    const { confirmationToken, targetUserId, options = {} } = req.body;
    const adminUserId = req.user.sub;

    if (!confirmationToken) {
      return res.status(400).json({
        error: 'Confirmation token required',
        code: 'CONFIRMATION_TOKEN_REQUIRED'
      });
    }

    logger.warn('🔥 [AdminAPI] CRITICAL: Data flush execution requested', {
      adminUserId,
      targetUserId: targetUserId || 'ALL_USERS',
      options,
      userAgent: req.get('User-Agent'),
      ipAddress: req.ip
    });

    // Execute the flush operation
    const result = await adminDataFlushService.executeDataFlush(
      adminUserId,
      confirmationToken,
      targetUserId,
      options
    );

    // Log successful completion
    logger.warn('🔥 [AdminAPI] CRITICAL: Data flush executed successfully', {
      adminUserId,
      operationId: result.operationId,
      targetUserId: targetUserId || 'ALL_USERS',
      duration: result.duration,
      results: result.results
    });

    res.json({
      success: true,
      message: 'Data flush operation completed successfully',
      operationId: result.operationId,
      results: result.results,
      duration: result.duration,
      timestamp: new Date().toISOString()
    });

  } catch (error) {
    logger.error('🔥 [AdminAPI] CRITICAL: Data flush execution failed', {
      adminUserId: req.user.sub,
      targetUserId: req.body.targetUserId || 'ALL_USERS',
      error: error.message
    });

    res.status(500).json({
      error: 'Data flush operation failed',
      code: 'FLUSH_EXECUTION_FAILED',
      details: error.message
    });
  }
});

/**
 * GET /api/admin/flush/status/:operationId
 * Get status of a flush operation
 */
router.get('/flush/status/:operationId', authenticateJWT, requireAdmin, adminRateLimit, async (req, res) => {
  try {
    const { operationId } = req.params;
    const adminUserId = req.user.sub;

    const status = adminDataFlushService.getFlushOperationStatus(operationId);

    if (!status) {
      return res.status(404).json({
        error: 'Flush operation not found',
        code: 'OPERATION_NOT_FOUND'
      });
    }

    logger.info('🔥 [AdminAPI] Flush operation status requested', {
      adminUserId,
      operationId,
      status: status.status
    });

    res.json({
      success: true,
      data: status
    });

  } catch (error) {
    logger.error('🔥 [AdminAPI] Failed to get flush operation status', {
      adminUserId: req.user.sub,
      operationId: req.params.operationId,
      error: error.message
    });

    res.status(500).json({
      error: 'Failed to get operation status',
      code: 'STATUS_RETRIEVAL_FAILED',
      details: error.message
    });
  }
});

/**
 * GET /api/admin/flush/history
 * Get flush operation history for audit purposes
 */
router.get('/flush/history', authenticateJWT, requireAdmin, adminRateLimit, async (req, res) => {
  try {
    const { limit = 50 } = req.query;
    const adminUserId = req.user.sub;

    logger.info('🔥 [AdminAPI] Flush history requested', {
      adminUserId,
      limit: parseInt(limit)
    });

    const history = adminDataFlushService.getFlushHistory(parseInt(limit));

    res.json({
      success: true,
      data: history,
      count: history.length,
      timestamp: new Date().toISOString()
    });

  } catch (error) {
    logger.error('🔥 [AdminAPI] Failed to get flush history', {
      adminUserId: req.user.sub,
      error: error.message
    });

    res.status(500).json({
      error: 'Failed to retrieve flush history',
      code: 'HISTORY_RETRIEVAL_FAILED',
      details: error.message
    });
  }
});

/**
 * POST /api/admin/containers/cleanup
 * Emergency cleanup of orphaned containers and networks
 */
router.post('/containers/cleanup', authenticateJWT, requireAdmin, adminRateLimit, async (req, res) => {
  try {
    const adminUserId = req.user.sub;

    logger.warn('🔥 [AdminAPI] Emergency container cleanup requested', {
      adminUserId,
      userAgent: req.get('User-Agent')
    });

    // Execute container cleanup only
    const result = await adminDataFlushService.clearUserContainersAndNetworks();

    logger.info('🔥 [AdminAPI] Emergency container cleanup completed', {
      adminUserId,
      results: result
    });

    res.json({
      success: true,
      message: 'Container cleanup completed',
      results: result,
      timestamp: new Date().toISOString()
    });

  } catch (error) {
    logger.error('🔥 [AdminAPI] Emergency container cleanup failed', {
      adminUserId: req.user.sub,
      error: error.message
    });

    res.status(500).json({
      error: 'Container cleanup failed',
      code: 'CLEANUP_FAILED',
      details: error.message
    });
  }
});

/**
 * GET /api/admin/health
 * Admin health check endpoint
 */
router.get('/health', authenticateJWT, requireAdmin, (req, res) => {
  logger.info('🔥 [AdminAPI] Admin health check', {
    adminUserId: req.user.sub
  });

  res.json({
    status: 'healthy',
    service: 'cloudtolocalllm-admin',
    timestamp: new Date().toISOString(),
    adminUserId: req.user.sub
  });
});

export default router;
