/**
 * Zrok Discovery Service for Streaming Proxy Containers
 * 
 * Discovers and manages connections to user-specific zrok tunnels
 * created by desktop clients, enabling container-to-desktop tunnel integration.
 */

import winston from 'winston';

/**
 * ZrokDiscoveryService - Discovers and manages zrok tunnel connections
 */
export class ZrokDiscoveryService {
  constructor(userId, apiBaseUrl = 'http://api-backend:8080') {
    this.userId = userId;
    this.apiBaseUrl = apiBaseUrl;
    this.discoveredTunnels = new Map();
    this.healthCheckInterval = null;
    this.discoveryInterval = null;
    
    // Configuration
    this.discoveryIntervalMs = 30000; // 30 seconds
    this.healthCheckIntervalMs = 15000; // 15 seconds
    this.tunnelTimeout = 5 * 60 * 1000; // 5 minutes
    
    this.logger = winston.createLogger({
      level: process.env.LOG_LEVEL || 'info',
      format: winston.format.combine(
        winston.format.timestamp(),
        winston.format.errors({ stack: true }),
        winston.format.json()
      ),
      defaultMeta: {
        service: 'zrok-discovery',
        userId: this.userId
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
    
    this.logger.info('🌐 [ZrokDiscovery] Service initialized', {
      userId: this.userId,
      apiBaseUrl: this.apiBaseUrl
    });
  }

  /**
   * Start the discovery service
   */
  async start() {
    try {
      this.logger.info('🌐 [ZrokDiscovery] Starting discovery service');
      
      // Initial discovery
      await this.discoverTunnels();
      
      // Start periodic discovery
      this.discoveryInterval = setInterval(async () => {
        await this.discoverTunnels();
      }, this.discoveryIntervalMs);
      
      // Start health monitoring
      this.healthCheckInterval = setInterval(async () => {
        await this.performHealthChecks();
      }, this.healthCheckIntervalMs);
      
      this.logger.info('🌐 [ZrokDiscovery] Discovery service started successfully');
      
    } catch (error) {
      this.logger.error('🌐 [ZrokDiscovery] Failed to start discovery service', error);
      throw error;
    }
  }

  /**
   * Stop the discovery service
   */
  stop() {
    this.logger.info('🌐 [ZrokDiscovery] Stopping discovery service');
    
    if (this.discoveryInterval) {
      clearInterval(this.discoveryInterval);
      this.discoveryInterval = null;
    }
    
    if (this.healthCheckInterval) {
      clearInterval(this.healthCheckInterval);
      this.healthCheckInterval = null;
    }
    
    this.discoveredTunnels.clear();
    this.logger.info('🌐 [ZrokDiscovery] Discovery service stopped');
  }

  /**
   * Discover available zrok tunnels for the user
   */
  async discoverTunnels() {
    try {
      const containerId = process.env.HOSTNAME || 'unknown';
      const containerToken = this.generateContainerToken(containerId);
      
      const response = await fetch(`${this.apiBaseUrl}/api/zrok/discover/${this.userId}`, {
        method: 'GET',
        headers: {
          'Content-Type': 'application/json',
          'X-Container-Token': containerToken,
          'X-Container-Id': containerId
        },
        timeout: 10000
      });

      if (!response.ok) {
        if (response.status === 404) {
          this.logger.debug('🌐 [ZrokDiscovery] No tunnels found for user');
          return null;
        }
        throw new Error(`Discovery failed: ${response.status} ${response.statusText}`);
      }

      const result = await response.json();
      
      if (result.success && result.data.available) {
        const tunnelInfo = result.data.tunnelInfo;
        
        // Update discovered tunnels
        this.discoveredTunnels.set(tunnelInfo.tunnelId, {
          ...tunnelInfo,
          discoveredAt: new Date(),
          lastHealthCheck: new Date(),
          isHealthy: tunnelInfo.isHealthy,
          consecutiveFailures: 0
        });
        
        this.logger.info('🌐 [ZrokDiscovery] Tunnel discovered', {
          tunnelId: tunnelInfo.tunnelId,
          publicUrl: tunnelInfo.publicUrl,
          isHealthy: tunnelInfo.isHealthy
        });
        
        return tunnelInfo;
      } else {
        this.logger.debug('🌐 [ZrokDiscovery] No active tunnels available');
        return null;
      }

    } catch (error) {
      this.logger.error('🌐 [ZrokDiscovery] Tunnel discovery failed', error);
      return null;
    }
  }

  /**
   * Get the best available zrok tunnel
   */
  getBestTunnel() {
    const healthyTunnels = Array.from(this.discoveredTunnels.values())
      .filter(tunnel => tunnel.isHealthy && tunnel.consecutiveFailures < 3);
    
    if (healthyTunnels.length === 0) {
      return null;
    }
    
    // Return the tunnel with the lowest response time
    return healthyTunnels.reduce((best, current) => {
      if (!best || (current.responseTime || 0) < (best.responseTime || Infinity)) {
        return current;
      }
      return best;
    });
  }

  /**
   * Check if any zrok tunnels are available
   */
  hasAvailableTunnels() {
    return this.getBestTunnel() !== null;
  }

  /**
   * Get all discovered tunnels
   */
  getAllTunnels() {
    return Array.from(this.discoveredTunnels.values());
  }

  /**
   * Perform health checks on discovered tunnels
   */
  async performHealthChecks() {
    const tunnels = Array.from(this.discoveredTunnels.values());
    
    for (const tunnel of tunnels) {
      try {
        const startTime = Date.now();
        const response = await fetch(tunnel.publicUrl, {
          method: 'HEAD',
          timeout: 5000
        });
        
        const responseTime = Date.now() - startTime;
        const isHealthy = response.ok;
        
        // Update tunnel health
        tunnel.isHealthy = isHealthy;
        tunnel.lastHealthCheck = new Date();
        tunnel.responseTime = responseTime;
        tunnel.consecutiveFailures = isHealthy ? 0 : (tunnel.consecutiveFailures || 0) + 1;
        
        this.discoveredTunnels.set(tunnel.tunnelId, tunnel);
        
        if (!isHealthy) {
          this.logger.warn('🌐 [ZrokDiscovery] Tunnel health check failed', {
            tunnelId: tunnel.tunnelId,
            publicUrl: tunnel.publicUrl,
            consecutiveFailures: tunnel.consecutiveFailures
          });
        } else {
          this.logger.debug('🌐 [ZrokDiscovery] Tunnel health check passed', {
            tunnelId: tunnel.tunnelId,
            responseTime
          });
        }
        
        // Remove tunnel after too many failures
        if (tunnel.consecutiveFailures >= 5) {
          this.logger.warn('🌐 [ZrokDiscovery] Removing unhealthy tunnel', {
            tunnelId: tunnel.tunnelId
          });
          this.discoveredTunnels.delete(tunnel.tunnelId);
        }
        
      } catch (error) {
        this.logger.debug('🌐 [ZrokDiscovery] Health check error for tunnel', {
          tunnelId: tunnel.tunnelId,
          error: error.message
        });
        
        tunnel.isHealthy = false;
        tunnel.consecutiveFailures = (tunnel.consecutiveFailures || 0) + 1;
        this.discoveredTunnels.set(tunnel.tunnelId, tunnel);
      }
    }
    
    // Clean up stale tunnels
    this.cleanupStaleTunnels();
  }

  /**
   * Clean up stale tunnels that haven't been updated recently
   */
  cleanupStaleTunnels() {
    const now = Date.now();
    const staleTunnels = [];
    
    for (const [tunnelId, tunnel] of this.discoveredTunnels.entries()) {
      const timeSinceDiscovery = now - tunnel.discoveredAt.getTime();
      
      if (timeSinceDiscovery > this.tunnelTimeout) {
        staleTunnels.push(tunnelId);
      }
    }
    
    for (const tunnelId of staleTunnels) {
      this.logger.info('🌐 [ZrokDiscovery] Cleaning up stale tunnel', { tunnelId });
      this.discoveredTunnels.delete(tunnelId);
    }
  }

  /**
   * Generate container authentication token
   * TODO: Implement proper container authentication
   */
  generateContainerToken(containerId) {
    // For now, use a simple token format
    // In production, this should be a proper JWT or secure token
    return `container-${containerId}-${Date.now()}`;
  }

  /**
   * Get discovery statistics
   */
  getStats() {
    const tunnels = Array.from(this.discoveredTunnels.values());
    const healthyTunnels = tunnels.filter(t => t.isHealthy);
    
    return {
      totalTunnels: tunnels.length,
      healthyTunnels: healthyTunnels.length,
      bestTunnel: this.getBestTunnel(),
      lastDiscovery: tunnels.length > 0 ? Math.max(...tunnels.map(t => t.discoveredAt.getTime())) : null
    };
  }
}

/**
 * Container Connection Manager - Manages connection fallback hierarchy
 */
export class ContainerConnectionManager {
  constructor(userId, zrokDiscovery) {
    this.userId = userId;
    this.zrokDiscovery = zrokDiscovery;
    this.connectionMode = 'auto'; // auto, zrok-only, cloud-only
    this.currentEndpoint = null;
    
    this.logger = winston.createLogger({
      level: process.env.LOG_LEVEL || 'info',
      format: winston.format.combine(
        winston.format.timestamp(),
        winston.format.errors({ stack: true }),
        winston.format.json()
      ),
      defaultMeta: {
        service: 'connection-manager',
        userId: this.userId
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
  }

  /**
   * Get the best available connection endpoint
   */
  getBestEndpoint() {
    if (this.connectionMode === 'cloud-only') {
      return this.getCloudEndpoint();
    }
    
    if (this.connectionMode === 'zrok-only') {
      const tunnel = this.zrokDiscovery.getBestTunnel();
      return tunnel ? tunnel.publicUrl : null;
    }
    
    // Auto mode: prefer zrok, fallback to cloud
    const tunnel = this.zrokDiscovery.getBestTunnel();
    if (tunnel) {
      this.currentEndpoint = tunnel.publicUrl;
      return tunnel.publicUrl;
    }
    
    // Fallback to cloud proxy mode
    this.currentEndpoint = this.getCloudEndpoint();
    return this.currentEndpoint;
  }

  /**
   * Get cloud proxy endpoint (fallback)
   */
  getCloudEndpoint() {
    // This would be the direct cloud proxy endpoint
    // For now, return a placeholder
    return 'http://localhost:11434'; // Placeholder
  }

  /**
   * Handle connection failure and attempt recovery
   */
  async handleConnectionFailure() {
    this.logger.warn('🌐 [ConnectionManager] Connection failure detected');
    
    // Force rediscovery of tunnels
    await this.zrokDiscovery.discoverTunnels();
    
    // Update current endpoint
    const newEndpoint = this.getBestEndpoint();
    
    if (newEndpoint !== this.currentEndpoint) {
      this.logger.info('🌐 [ConnectionManager] Switching to new endpoint', {
        oldEndpoint: this.currentEndpoint,
        newEndpoint
      });
      this.currentEndpoint = newEndpoint;
      return true; // Endpoint changed
    }
    
    return false; // No change
  }

  /**
   * Set connection mode
   */
  setConnectionMode(mode) {
    if (['auto', 'zrok-only', 'cloud-only'].includes(mode)) {
      this.connectionMode = mode;
      this.logger.info('🌐 [ConnectionManager] Connection mode changed', { mode });
    } else {
      throw new Error(`Invalid connection mode: ${mode}`);
    }
  }

  /**
   * Get connection status
   */
  getStatus() {
    const tunnel = this.zrokDiscovery.getBestTunnel();
    
    return {
      connectionMode: this.connectionMode,
      currentEndpoint: this.currentEndpoint,
      zrokAvailable: tunnel !== null,
      zrokTunnel: tunnel,
      discoveryStats: this.zrokDiscovery.getStats()
    };
  }
}
