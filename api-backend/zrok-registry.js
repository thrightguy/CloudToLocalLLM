/**
 * Zrok Tunnel Registry - Core API Backend Component
 * 
 * Manages registration, discovery, and health monitoring of zrok tunnels
 * for the multi-tenant Docker environment integration.
 * 
 * Features:
 * - User-specific tunnel registration from desktop clients
 * - Container discovery of available zrok tunnels
 * - Health monitoring and automatic cleanup
 * - JWT-based authentication and authorization
 */

import crypto from 'crypto';
import { EventEmitter } from 'events';
import logger from './logger.js';

/**
 * ZrokTunnelRegistry - Manages zrok tunnel lifecycle and discovery
 */
export class ZrokTunnelRegistry extends EventEmitter {
  constructor() {
    super();
    
    // Core data structures
    this.userTunnels = new Map();     // userId -> tunnelInfo
    this.tunnelHealth = new Map();    // tunnelId -> healthStatus
    this.containerAssociations = new Map(); // containerId -> userId
    
    // Configuration
    this.tunnelTimeout = 10 * 60 * 1000; // 10 minutes
    this.healthCheckInterval = 30 * 1000; // 30 seconds
    this.cleanupInterval = 60 * 1000;     // 1 minute
    
    // Start background processes
    this.startHealthMonitoring();
    this.startCleanupProcess();
    
    logger.info('🌐 [ZrokRegistry] Zrok tunnel registry initialized');
  }

  /**
   * Register a zrok tunnel from desktop client
   */
  async registerTunnel(userId, tunnelInfo, authToken) {
    try {
      // Validate tunnel info
      if (!this.validateTunnelInfo(tunnelInfo)) {
        throw new Error('Invalid tunnel information provided');
      }

      const tunnelId = this.generateTunnelId(userId, tunnelInfo.publicUrl);
      const registrationTime = new Date();

      const tunnelRecord = {
        tunnelId,
        userId,
        publicUrl: tunnelInfo.publicUrl,
        localUrl: tunnelInfo.localUrl,
        shareToken: tunnelInfo.shareToken,
        protocol: tunnelInfo.protocol || 'http',
        isActive: true,
        registeredAt: registrationTime,
        lastHeartbeat: registrationTime,
        lastHealthCheck: registrationTime,
        authToken: authToken,
        metadata: {
          userAgent: tunnelInfo.userAgent || 'CloudToLocalLLM-Desktop',
          version: tunnelInfo.version || 'unknown',
          platform: tunnelInfo.platform || 'unknown'
        }
      };

      // Store tunnel registration
      this.userTunnels.set(userId, tunnelRecord);
      this.tunnelHealth.set(tunnelId, {
        isHealthy: true,
        lastCheck: registrationTime,
        consecutiveFailures: 0,
        responseTime: 0
      });

      // Emit registration event
      this.emit('tunnelRegistered', { userId, tunnelId, tunnelRecord });

      logger.info(`🌐 [ZrokRegistry] Tunnel registered for user ${userId}`, {
        tunnelId,
        publicUrl: tunnelInfo.publicUrl,
        localUrl: tunnelInfo.localUrl
      });

      return {
        success: true,
        tunnelId,
        message: 'Tunnel registered successfully'
      };

    } catch (error) {
      logger.error(`🌐 [ZrokRegistry] Failed to register tunnel for user ${userId}`, error);
      throw error;
    }
  }

  /**
   * Discover available zrok tunnels for a user
   */
  async discoverTunnels(userId) {
    try {
      const userTunnel = this.userTunnels.get(userId);
      
      if (!userTunnel || !userTunnel.isActive) {
        return {
          available: false,
          message: 'No active zrok tunnels found for user'
        };
      }

      // Check tunnel health
      const healthStatus = this.tunnelHealth.get(userTunnel.tunnelId);
      const isHealthy = healthStatus?.isHealthy ?? false;

      const discoveryResult = {
        available: true,
        tunnelInfo: {
          tunnelId: userTunnel.tunnelId,
          publicUrl: userTunnel.publicUrl,
          localUrl: userTunnel.localUrl,
          protocol: userTunnel.protocol,
          isHealthy,
          lastHealthCheck: healthStatus?.lastCheck,
          responseTime: healthStatus?.responseTime
        },
        metadata: {
          registeredAt: userTunnel.registeredAt,
          lastHeartbeat: userTunnel.lastHeartbeat,
          platform: userTunnel.metadata.platform
        }
      };

      logger.info(`🌐 [ZrokRegistry] Tunnel discovery for user ${userId}`, {
        available: true,
        tunnelId: userTunnel.tunnelId,
        isHealthy
      });

      return discoveryResult;

    } catch (error) {
      logger.error(`🌐 [ZrokRegistry] Failed to discover tunnels for user ${userId}`, error);
      throw error;
    }
  }

  /**
   * Update tunnel heartbeat from desktop client
   */
  async updateHeartbeat(userId, tunnelId) {
    try {
      const userTunnel = this.userTunnels.get(userId);
      
      if (!userTunnel || userTunnel.tunnelId !== tunnelId) {
        throw new Error('Tunnel not found or mismatch');
      }

      userTunnel.lastHeartbeat = new Date();
      this.userTunnels.set(userId, userTunnel);

      logger.debug(`🌐 [ZrokRegistry] Heartbeat updated for tunnel ${tunnelId}`);

      return { success: true };

    } catch (error) {
      logger.error(`🌐 [ZrokRegistry] Failed to update heartbeat for tunnel ${tunnelId}`, error);
      throw error;
    }
  }

  /**
   * Associate container with user for zrok discovery
   */
  async associateContainer(containerId, userId) {
    try {
      this.containerAssociations.set(containerId, userId);
      
      logger.info(`🌐 [ZrokRegistry] Container ${containerId} associated with user ${userId}`);
      
      return { success: true };

    } catch (error) {
      logger.error(`🌐 [ZrokRegistry] Failed to associate container ${containerId}`, error);
      throw error;
    }
  }

  /**
   * Remove tunnel registration
   */
  async unregisterTunnel(userId, tunnelId) {
    try {
      const userTunnel = this.userTunnels.get(userId);
      
      if (userTunnel && userTunnel.tunnelId === tunnelId) {
        this.userTunnels.delete(userId);
        this.tunnelHealth.delete(tunnelId);
        
        // Emit unregistration event
        this.emit('tunnelUnregistered', { userId, tunnelId });
        
        logger.info(`🌐 [ZrokRegistry] Tunnel ${tunnelId} unregistered for user ${userId}`);
      }

      return { success: true };

    } catch (error) {
      logger.error(`🌐 [ZrokRegistry] Failed to unregister tunnel ${tunnelId}`, error);
      throw error;
    }
  }

  /**
   * Get registry statistics
   */
  getRegistryStats() {
    const activeTunnels = Array.from(this.userTunnels.values()).filter(t => t.isActive);
    const healthyTunnels = Array.from(this.tunnelHealth.values()).filter(h => h.isHealthy);
    
    return {
      totalUsers: this.userTunnels.size,
      activeTunnels: activeTunnels.length,
      healthyTunnels: healthyTunnels.length,
      associatedContainers: this.containerAssociations.size,
      uptime: process.uptime()
    };
  }

  /**
   * Validate tunnel information
   */
  validateTunnelInfo(tunnelInfo) {
    if (!tunnelInfo) return false;
    if (!tunnelInfo.publicUrl || !tunnelInfo.localUrl) return false;
    if (!tunnelInfo.shareToken) return false;
    
    // Validate URL formats
    try {
      new URL(tunnelInfo.publicUrl);
      // Local URL validation (should be localhost or 127.0.0.1)
      const localUrl = new URL(tunnelInfo.localUrl);
      if (!['localhost', '127.0.0.1'].includes(localUrl.hostname)) {
        return false;
      }
    } catch {
      return false;
    }
    
    return true;
  }

  /**
   * Generate unique tunnel ID
   */
  generateTunnelId(userId, publicUrl) {
    const data = `${userId}-${publicUrl}-${Date.now()}`;
    return crypto.createHash('sha256').update(data).digest('hex').substring(0, 16);
  }

  /**
   * Start health monitoring process
   */
  startHealthMonitoring() {
    setInterval(async () => {
      await this.performHealthChecks();
    }, this.healthCheckInterval);
    
    logger.info('🌐 [ZrokRegistry] Health monitoring started');
  }

  /**
   * Perform health checks on all registered tunnels
   */
  async performHealthChecks() {
    const tunnels = Array.from(this.userTunnels.values());
    
    for (const tunnel of tunnels) {
      if (!tunnel.isActive) continue;
      
      try {
        const startTime = Date.now();
        const response = await fetch(tunnel.publicUrl, {
          method: 'HEAD',
          timeout: 5000
        });
        
        const responseTime = Date.now() - startTime;
        const isHealthy = response.ok;
        
        const healthStatus = this.tunnelHealth.get(tunnel.tunnelId) || {};
        healthStatus.isHealthy = isHealthy;
        healthStatus.lastCheck = new Date();
        healthStatus.responseTime = responseTime;
        healthStatus.consecutiveFailures = isHealthy ? 0 : (healthStatus.consecutiveFailures || 0) + 1;
        
        this.tunnelHealth.set(tunnel.tunnelId, healthStatus);
        
        // Mark tunnel as inactive after 3 consecutive failures
        if (healthStatus.consecutiveFailures >= 3) {
          tunnel.isActive = false;
          this.userTunnels.set(tunnel.userId, tunnel);
          
          logger.warn(`🌐 [ZrokRegistry] Tunnel ${tunnel.tunnelId} marked inactive due to health failures`);
          this.emit('tunnelUnhealthy', { tunnel, healthStatus });
        }
        
      } catch (error) {
        logger.debug(`🌐 [ZrokRegistry] Health check failed for tunnel ${tunnel.tunnelId}: ${error.message}`);
      }
    }
  }

  /**
   * Start cleanup process for stale tunnels
   */
  startCleanupProcess() {
    setInterval(async () => {
      await this.cleanupStaleTunnels();
    }, this.cleanupInterval);
    
    logger.info('🌐 [ZrokRegistry] Cleanup process started');
  }

  /**
   * Clean up stale tunnels based on heartbeat timeout
   */
  async cleanupStaleTunnels() {
    const now = new Date();
    const staleTunnels = [];
    
    for (const [userId, tunnel] of this.userTunnels.entries()) {
      const timeSinceHeartbeat = now - tunnel.lastHeartbeat;
      
      if (timeSinceHeartbeat > this.tunnelTimeout) {
        staleTunnels.push({ userId, tunnel });
      }
    }
    
    for (const { userId, tunnel } of staleTunnels) {
      await this.unregisterTunnel(userId, tunnel.tunnelId);
      logger.info(`🌐 [ZrokRegistry] Cleaned up stale tunnel ${tunnel.tunnelId} for user ${userId}`);
    }
    
    if (staleTunnels.length > 0) {
      logger.info(`🌐 [ZrokRegistry] Cleanup completed: ${staleTunnels.length} stale tunnels removed`);
    }
  }
}

// Export singleton instance
export const zrokRegistry = new ZrokTunnelRegistry();
