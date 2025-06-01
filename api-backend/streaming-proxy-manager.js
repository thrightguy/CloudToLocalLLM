import Docker from 'dockerode';
import crypto from 'crypto';
import winston from 'winston';

// Initialize Docker client
const docker = new Docker();

// Logger for proxy management
const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.errors({ stack: true }),
    winston.format.json()
  ),
  defaultMeta: { service: 'proxy-manager' },
  transports: [
    new winston.transports.Console({
      format: winston.format.combine(
        winston.format.timestamp(),
        winston.format.simple()
      )
    })
  ]
});

/**
 * StreamingProxyManager - Manages ephemeral streaming proxy containers
 * Implements zero-storage, multi-tenant architecture with complete user isolation
 */
export class StreamingProxyManager {
  constructor() {
    this.activeProxies = new Map(); // userId -> proxy metadata
    this.proxyNetworks = new Map(); // userId -> network info
    this.cleanupInterval = null;
    
    // Start periodic cleanup
    this.startCleanupProcess();
  }

  /**
   * Generate secure, collision-free proxy identifier
   */
  generateProxyId(userId) {
    const hash = crypto.createHash('sha256').update(userId).digest('hex');
    return `cloudtolocalllm-proxy-${hash.substring(0, 12)}`;
  }

  /**
   * Generate isolated network name for user
   */
  generateNetworkName(userId) {
    const hash = crypto.createHash('sha256').update(userId).digest('hex');
    return `cloudtolocalllm-user-${hash.substring(0, 12)}-net`;
  }

  /**
   * Create isolated Docker network for user
   */
  async createUserNetwork(userId) {
    const networkName = this.generateNetworkName(userId);
    
    try {
      // Check if network already exists
      const networks = await docker.listNetworks({
        filters: { name: [networkName] }
      });
      
      if (networks.length > 0) {
        logger.info(`User network already exists: ${networkName}`);
        return networks[0];
      }

      // Create isolated network
      const network = await docker.createNetwork({
        Name: networkName,
        Driver: 'bridge',
        Internal: false, // Allow external access for API communication
        IPAM: {
          Driver: 'default',
          Config: [{
            Subnet: `172.${20 + Math.floor(Math.random() * 200)}.0.0/24`
          }]
        },
        Labels: {
          'cloudtolocalllm.user': userId,
          'cloudtolocalllm.type': 'user-network',
          'cloudtolocalllm.created': new Date().toISOString()
        }
      });

      logger.info(`Created isolated network for user: ${networkName}`);
      return network;
    } catch (error) {
      logger.error(`Failed to create user network: ${networkName}`, error);
      throw error;
    }
  }

  /**
   * Provision streaming proxy container for user
   */
  async provisionProxy(userId, userToken) {
    const proxyId = this.generateProxyId(userId);
    
    try {
      // Check if proxy already exists
      if (this.activeProxies.has(userId)) {
        const existingProxy = this.activeProxies.get(userId);
        logger.info(`Proxy already exists for user: ${userId}`);
        return existingProxy;
      }

      // Create isolated network
      const network = await this.createUserNetwork(userId);
      const networkName = this.generateNetworkName(userId);

      // Container configuration for streaming proxy
      const containerConfig = {
        Image: 'cloudtolocalllm-streaming-proxy:latest',
        name: proxyId,
        Env: [
          `USER_ID=${userId}`,
          `PROXY_ID=${proxyId}`,
          `NODE_ENV=production`,
          `LOG_LEVEL=info`
        ],
        Labels: {
          'cloudtolocalllm.user': userId,
          'cloudtolocalllm.type': 'streaming-proxy',
          'cloudtolocalllm.created': new Date().toISOString()
        },
        HostConfig: {
          Memory: 512 * 1024 * 1024, // 512MB RAM limit
          CpuShares: 512, // 0.5 CPU core limit
          NetworkMode: networkName,
          RestartPolicy: { Name: 'no' }, // No restart - ephemeral by design
          AutoRemove: true // Auto-remove when stopped
        },
        NetworkingConfig: {
          EndpointsConfig: {
            [networkName]: {},
            'cloudtolocalllm-network': {} // Connect to main network for API access
          }
        }
      };

      // Create and start container
      const container = await docker.createContainer(containerConfig);
      await container.start();

      // Get container info
      const containerInfo = await container.inspect();
      const proxyPort = 8080; // Internal port
      
      // Store proxy metadata
      const proxyMetadata = {
        userId,
        proxyId,
        containerId: container.id,
        containerName: proxyId,
        networkName,
        port: proxyPort,
        createdAt: new Date(),
        lastActivity: new Date(),
        status: 'running'
      };

      this.activeProxies.set(userId, proxyMetadata);
      this.proxyNetworks.set(userId, { network, networkName });

      logger.info(`Provisioned streaming proxy for user: ${userId}`, {
        proxyId,
        containerId: container.id,
        networkName
      });

      return proxyMetadata;
    } catch (error) {
      logger.error(`Failed to provision proxy for user: ${userId}`, error);
      throw error;
    }
  }

  /**
   * Terminate streaming proxy for user
   */
  async terminateProxy(userId) {
    try {
      const proxyMetadata = this.activeProxies.get(userId);
      if (!proxyMetadata) {
        logger.warn(`No active proxy found for user: ${userId}`);
        return false;
      }

      // Stop and remove container
      const container = docker.getContainer(proxyMetadata.containerId);
      await container.stop({ t: 10 }); // 10 second grace period
      
      // Container will auto-remove due to AutoRemove: true

      // Clean up network
      const networkInfo = this.proxyNetworks.get(userId);
      if (networkInfo) {
        try {
          await networkInfo.network.remove();
          logger.info(`Removed user network: ${networkInfo.networkName}`);
        } catch (networkError) {
          logger.warn(`Failed to remove network: ${networkInfo.networkName}`, networkError);
        }
      }

      // Remove from tracking
      this.activeProxies.delete(userId);
      this.proxyNetworks.delete(userId);

      logger.info(`Terminated streaming proxy for user: ${userId}`, {
        proxyId: proxyMetadata.proxyId,
        duration: Date.now() - proxyMetadata.createdAt.getTime()
      });

      return true;
    } catch (error) {
      logger.error(`Failed to terminate proxy for user: ${userId}`, error);
      return false;
    }
  }

  /**
   * Get proxy status for user
   */
  async getProxyStatus(userId) {
    const proxyMetadata = this.activeProxies.get(userId);
    if (!proxyMetadata) {
      return { status: 'not-found', userId };
    }

    try {
      // Check container health
      const container = docker.getContainer(proxyMetadata.containerId);
      const containerInfo = await container.inspect();
      
      return {
        status: containerInfo.State.Running ? 'running' : 'stopped',
        userId,
        proxyId: proxyMetadata.proxyId,
        createdAt: proxyMetadata.createdAt,
        lastActivity: proxyMetadata.lastActivity,
        health: containerInfo.State.Health?.Status || 'unknown'
      };
    } catch (error) {
      logger.error(`Failed to get proxy status for user: ${userId}`, error);
      return { status: 'error', userId, error: error.message };
    }
  }

  /**
   * Update last activity for proxy
   */
  updateProxyActivity(userId) {
    const proxyMetadata = this.activeProxies.get(userId);
    if (proxyMetadata) {
      proxyMetadata.lastActivity = new Date();
    }
  }

  /**
   * Start periodic cleanup process
   */
  startCleanupProcess() {
    this.cleanupInterval = setInterval(async () => {
      await this.cleanupStaleProxies();
    }, 60000); // Check every minute

    logger.info('Started proxy cleanup process');
  }

  /**
   * Clean up stale or orphaned proxies
   */
  async cleanupStaleProxies() {
    const now = Date.now();
    const staleThreshold = 10 * 60 * 1000; // 10 minutes of inactivity

    for (const [userId, proxyMetadata] of this.activeProxies.entries()) {
      const inactiveTime = now - proxyMetadata.lastActivity.getTime();
      
      if (inactiveTime > staleThreshold) {
        logger.info(`Cleaning up stale proxy for user: ${userId}`, {
          proxyId: proxyMetadata.proxyId,
          inactiveTime: Math.floor(inactiveTime / 1000) + 's'
        });
        
        await this.terminateProxy(userId);
      }
    }
  }

  /**
   * Get all active proxies (for monitoring)
   */
  getAllActiveProxies() {
    return Array.from(this.activeProxies.entries()).map(([userId, metadata]) => ({
      userId,
      ...metadata
    }));
  }

  /**
   * Shutdown proxy manager
   */
  async shutdown() {
    if (this.cleanupInterval) {
      clearInterval(this.cleanupInterval);
    }

    // Terminate all active proxies
    const terminationPromises = Array.from(this.activeProxies.keys()).map(
      userId => this.terminateProxy(userId)
    );

    await Promise.allSettled(terminationPromises);
    logger.info('Streaming proxy manager shutdown complete');
  }
}

export default StreamingProxyManager;
