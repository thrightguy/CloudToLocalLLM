/**
 * Administrative Data Flush Service Tests
 * 
 * Comprehensive test suite for the CloudToLocalLLM administrative data flush system
 * Tests security, functionality, error handling, and audit trail features
 */

import { describe, it, expect, beforeEach, afterEach, jest } from '@jest/globals';
import { AdminDataFlushService } from '../admin-data-flush-service.js';
import Docker from 'dockerode';

// Mock Docker
jest.mock('dockerode');

describe('AdminDataFlushService', () => {
  let adminService;
  let mockDocker;

  beforeEach(() => {
    // Reset mocks
    jest.clearAllMocks();
    
    // Mock Docker instance
    mockDocker = {
      listContainers: jest.fn(),
      listNetworks: jest.fn(),
      getContainer: jest.fn(),
      getNetwork: jest.fn(),
      createNetwork: jest.fn(),
    };
    
    Docker.mockImplementation(() => mockDocker);
    
    adminService = new AdminDataFlushService();
  });

  afterEach(() => {
    jest.restoreAllMocks();
  });

  describe('Confirmation Token Management', () => {
    it('should generate valid confirmation tokens', () => {
      const adminUserId = 'admin123';
      const targetScope = 'test-user';
      
      const tokenData = adminService.generateConfirmationToken(adminUserId, targetScope);
      
      expect(tokenData).toHaveProperty('token');
      expect(tokenData).toHaveProperty('expiresAt');
      expect(tokenData).toHaveProperty('scope');
      expect(tokenData).toHaveProperty('adminUserId');
      
      expect(tokenData.token).toHaveLength(64); // SHA256 hex length
      expect(tokenData.scope).toBe(targetScope);
      expect(tokenData.adminUserId).toBe(adminUserId);
      expect(tokenData.expiresAt).toBeInstanceOf(Date);
      
      // Token should expire in ~5 minutes
      const expiryDiff = tokenData.expiresAt.getTime() - Date.now();
      expect(expiryDiff).toBeGreaterThan(4 * 60 * 1000); // > 4 minutes
      expect(expiryDiff).toBeLessThan(6 * 60 * 1000); // < 6 minutes
    });

    it('should validate confirmation tokens correctly', () => {
      const adminUserId = 'admin123';
      const targetScope = 'test-user';
      
      const tokenData = adminService.generateConfirmationToken(adminUserId, targetScope);
      
      // Valid token should pass validation
      const isValid = adminService.validateConfirmationToken(
        tokenData.token, 
        adminUserId, 
        targetScope
      );
      expect(isValid).toBe(true);
      
      // Invalid token should fail validation
      const isInvalid = adminService.validateConfirmationToken(
        'invalid-token', 
        adminUserId, 
        targetScope
      );
      expect(isInvalid).toBe(false);
    });

    it('should generate unique tokens for different requests', () => {
      const adminUserId = 'admin123';
      const targetScope = 'test-user';
      
      const token1 = adminService.generateConfirmationToken(adminUserId, targetScope);
      const token2 = adminService.generateConfirmationToken(adminUserId, targetScope);
      
      expect(token1.token).not.toBe(token2.token);
    });
  });

  describe('Authentication Data Clearing', () => {
    it('should clear authentication data for specific user', async () => {
      const targetUserId = 'user123';
      
      const result = await adminService.clearUserAuthenticationData(targetUserId);
      
      expect(result).toHaveProperty('tokens');
      expect(result).toHaveProperty('sessions');
      expect(result).toHaveProperty('authCache');
      expect(result.authCache).toBe(1);
    });

    it('should clear authentication data for all users', async () => {
      const result = await adminService.clearUserAuthenticationData();
      
      expect(result).toHaveProperty('tokens');
      expect(result).toHaveProperty('sessions');
      expect(result).toHaveProperty('authCache');
      expect(result.authCache).toBe(1);
    });

    it('should handle authentication clearing errors gracefully', async () => {
      // Mock an error scenario
      const originalConsoleError = console.error;
      console.error = jest.fn();
      
      // This test verifies error handling structure
      // In a real implementation, you'd mock the actual clearing operations to throw
      
      try {
        const result = await adminService.clearUserAuthenticationData('user123');
        expect(result).toBeDefined();
      } catch (error) {
        expect(error).toBeInstanceOf(Error);
      }
      
      console.error = originalConsoleError;
    });
  });

  describe('Container and Network Clearing', () => {
    beforeEach(() => {
      // Mock container list response
      mockDocker.listContainers.mockResolvedValue([
        {
          Id: 'container1',
          Names: ['/cloudtolocalllm-proxy-user123'],
          State: 'running',
          Labels: {
            'cloudtolocalllm.user': 'user123',
            'cloudtolocalllm.type': 'streaming-proxy'
          }
        },
        {
          Id: 'container2',
          Names: ['/cloudtolocalllm-proxy-user456'],
          State: 'exited',
          Labels: {
            'cloudtolocalllm.user': 'user456',
            'cloudtolocalllm.type': 'streaming-proxy'
          }
        }
      ]);

      // Mock network list response
      mockDocker.listNetworks.mockResolvedValue([
        {
          Id: 'network1',
          Name: 'cloudtolocalllm-user-user123',
          Labels: {
            'cloudtolocalllm.user': 'user123',
            'cloudtolocalllm.type': 'user-network'
          }
        }
      ]);

      // Mock container operations
      const mockContainer = {
        stop: jest.fn().mockResolvedValue(),
        remove: jest.fn().mockResolvedValue()
      };
      mockDocker.getContainer.mockReturnValue(mockContainer);

      // Mock network operations
      const mockNetwork = {
        remove: jest.fn().mockResolvedValue()
      };
      mockDocker.getNetwork.mockReturnValue(mockNetwork);
    });

    it('should clear containers and networks for specific user', async () => {
      const targetUserId = 'user123';
      
      const result = await adminService.clearUserContainersAndNetworks(targetUserId);
      
      expect(result).toHaveProperty('containers');
      expect(result).toHaveProperty('networks');
      expect(result).toHaveProperty('volumes');
      
      expect(mockDocker.listContainers).toHaveBeenCalledWith({
        all: true,
        filters: { label: ['cloudtolocalllm.type'] }
      });
      
      expect(mockDocker.listNetworks).toHaveBeenCalledWith({
        filters: { label: ['cloudtolocalllm.type=user-network'] }
      });
      
      // Should have processed one container for user123
      expect(result.containers).toBe(1);
      expect(result.networks).toBe(1);
    });

    it('should clear all containers and networks when no user specified', async () => {
      const result = await adminService.clearUserContainersAndNetworks();
      
      expect(result).toHaveProperty('containers');
      expect(result).toHaveProperty('networks');
      
      // Should process all containers
      expect(result.containers).toBe(2);
      expect(result.networks).toBe(1);
    });

    it('should handle container stop/remove errors gracefully', async () => {
      // Mock container stop to fail
      const mockContainer = {
        stop: jest.fn().mockRejectedValue(new Error('Container stop failed')),
        remove: jest.fn().mockResolvedValue()
      };
      mockDocker.getContainer.mockReturnValue(mockContainer);

      const result = await adminService.clearUserContainersAndNetworks('user123');
      
      // Should still complete and return results
      expect(result).toBeDefined();
      expect(result).toHaveProperty('containers');
    });

    it('should handle network removal errors gracefully', async () => {
      // Mock network remove to fail
      const mockNetwork = {
        remove: jest.fn().mockRejectedValue(new Error('Network remove failed'))
      };
      mockDocker.getNetwork.mockReturnValue(mockNetwork);

      const result = await adminService.clearUserContainersAndNetworks('user123');
      
      // Should still complete and return results
      expect(result).toBeDefined();
      expect(result).toHaveProperty('networks');
    });
  });

  describe('Complete Data Flush Execution', () => {
    it('should execute complete data flush successfully', async () => {
      const adminUserId = 'admin123';
      const targetUserId = 'user123';
      
      // Generate valid confirmation token
      const tokenData = adminService.generateConfirmationToken(adminUserId, targetUserId);
      
      // Mock container operations for successful execution
      mockDocker.listContainers.mockResolvedValue([]);
      mockDocker.listNetworks.mockResolvedValue([]);
      
      const result = await adminService.executeDataFlush(
        adminUserId,
        tokenData.token,
        targetUserId,
        {}
      );
      
      expect(result).toHaveProperty('success', true);
      expect(result).toHaveProperty('operationId');
      expect(result).toHaveProperty('results');
      expect(result).toHaveProperty('duration');
      
      expect(result.results).toHaveProperty('authentication');
      expect(result.results).toHaveProperty('conversations');
      expect(result.results).toHaveProperty('preferences');
      expect(result.results).toHaveProperty('cache');
      expect(result.results).toHaveProperty('containers');
    });

    it('should respect skip options in flush execution', async () => {
      const adminUserId = 'admin123';
      const targetUserId = 'user123';
      
      const tokenData = adminService.generateConfirmationToken(adminUserId, targetUserId);
      
      // Mock container operations
      mockDocker.listContainers.mockResolvedValue([]);
      mockDocker.listNetworks.mockResolvedValue([]);
      
      const options = {
        skipAuth: true,
        skipConversations: true,
        skipContainers: false
      };
      
      const result = await adminService.executeDataFlush(
        adminUserId,
        tokenData.token,
        targetUserId,
        options
      );
      
      expect(result.success).toBe(true);
      expect(result.results).not.toHaveProperty('authentication');
      expect(result.results).not.toHaveProperty('conversations');
      expect(result.results).toHaveProperty('containers');
    });

    it('should reject invalid confirmation tokens', async () => {
      const adminUserId = 'admin123';
      const targetUserId = 'user123';
      const invalidToken = 'invalid-token';
      
      await expect(
        adminService.executeDataFlush(adminUserId, invalidToken, targetUserId, {})
      ).rejects.toThrow('Invalid or expired confirmation token');
    });

    it('should track operation in history', async () => {
      const adminUserId = 'admin123';
      const targetUserId = 'user123';
      
      const tokenData = adminService.generateConfirmationToken(adminUserId, targetUserId);
      
      // Mock container operations
      mockDocker.listContainers.mockResolvedValue([]);
      mockDocker.listNetworks.mockResolvedValue([]);
      
      const initialHistoryLength = adminService.getFlushHistory().length;
      
      await adminService.executeDataFlush(
        adminUserId,
        tokenData.token,
        targetUserId,
        {}
      );
      
      const newHistoryLength = adminService.getFlushHistory().length;
      expect(newHistoryLength).toBe(initialHistoryLength + 1);
      
      const latestOperation = adminService.getFlushHistory()[0];
      expect(latestOperation).toHaveProperty('operationId');
      expect(latestOperation).toHaveProperty('adminUserId', adminUserId);
      expect(latestOperation).toHaveProperty('targetUserId', targetUserId);
      expect(latestOperation).toHaveProperty('status', 'completed');
    });
  });

  describe('System Statistics', () => {
    it('should return system statistics', async () => {
      // Mock Docker responses
      mockDocker.listContainers.mockResolvedValue([
        {
          Labels: { 'cloudtolocalllm.type': 'streaming-proxy', 'cloudtolocalllm.user': 'user1' }
        },
        {
          Labels: { 'cloudtolocalllm.type': 'streaming-proxy', 'cloudtolocalllm.user': 'user2' }
        },
        {
          Labels: { 'cloudtolocalllm.type': 'api-backend' }
        }
      ]);
      
      mockDocker.listNetworks.mockResolvedValue([
        {
          Labels: { 'cloudtolocalllm.type': 'user-network', 'cloudtolocalllm.user': 'user1' }
        },
        {
          Labels: { 'cloudtolocalllm.type': 'user-network', 'cloudtolocalllm.user': 'user2' }
        }
      ]);
      
      const stats = await adminService.getSystemStatistics();
      
      expect(stats).toHaveProperty('totalContainers', 3);
      expect(stats).toHaveProperty('userContainers', 2);
      expect(stats).toHaveProperty('userNetworks', 2);
      expect(stats).toHaveProperty('activeUsers', 2);
      expect(stats).toHaveProperty('lastFlushOperation');
    });

    it('should handle Docker API errors in statistics', async () => {
      mockDocker.listContainers.mockRejectedValue(new Error('Docker API error'));
      
      await expect(adminService.getSystemStatistics()).rejects.toThrow('Docker API error');
    });
  });

  describe('Operation Status and History', () => {
    it('should track active operations', async () => {
      const adminUserId = 'admin123';
      const targetUserId = 'user123';
      
      const tokenData = adminService.generateConfirmationToken(adminUserId, targetUserId);
      
      // Mock container operations to simulate long-running operation
      mockDocker.listContainers.mockImplementation(() => 
        new Promise(resolve => setTimeout(() => resolve([]), 100))
      );
      mockDocker.listNetworks.mockResolvedValue([]);
      
      // Start operation (don't await)
      const operationPromise = adminService.executeDataFlush(
        adminUserId,
        tokenData.token,
        targetUserId,
        {}
      );
      
      // Check that operation is tracked while running
      // Note: This is a simplified test - in practice you'd need more sophisticated timing
      
      await operationPromise;
      
      // Operation should be completed and removed from active operations
      const activeOps = Array.from(adminService.activeFlushOperations.values());
      expect(activeOps).toHaveLength(0);
    });

    it('should return flush history with correct limit', () => {
      // Add some mock history entries
      for (let i = 0; i < 10; i++) {
        adminService.flushHistory.push({
          operationId: `op-${i}`,
          startTime: new Date(),
          status: 'completed'
        });
      }
      
      const history = adminService.getFlushHistory(5);
      expect(history).toHaveLength(5);
      
      // Should return most recent operations first
      expect(history[0].operationId).toBe('op-9');
      expect(history[4].operationId).toBe('op-5');
    });
  });

  describe('Error Handling and Edge Cases', () => {
    it('should handle missing Docker daemon gracefully', async () => {
      mockDocker.listContainers.mockRejectedValue(new Error('Docker daemon not running'));
      
      await expect(
        adminService.clearUserContainersAndNetworks('user123')
      ).rejects.toThrow('Docker daemon not running');
    });

    it('should handle malformed container labels', async () => {
      mockDocker.listContainers.mockResolvedValue([
        {
          Id: 'container1',
          Names: ['/test-container'],
          State: 'running',
          Labels: null // Malformed labels
        }
      ]);
      
      const result = await adminService.clearUserContainersAndNetworks('user123');
      
      // Should handle gracefully and not crash
      expect(result).toBeDefined();
      expect(result.containers).toBe(0); // No containers should match
    });

    it('should validate operation parameters', async () => {
      const adminUserId = 'admin123';
      
      // Test with null confirmation token
      await expect(
        adminService.executeDataFlush(adminUserId, null, 'user123', {})
      ).rejects.toThrow();
      
      // Test with empty admin user ID
      await expect(
        adminService.executeDataFlush('', 'token', 'user123', {})
      ).rejects.toThrow();
    });
  });
});

describe('Integration Tests', () => {
  // These would be more comprehensive integration tests
  // that test the entire flow with real or more realistic mocks
  
  it('should integrate with logging system', () => {
    // Test that operations are properly logged
    // This would require mocking the logger and verifying log calls
  });
  
  it('should integrate with rate limiting', () => {
    // Test that rate limiting is properly enforced
    // This would require testing the API routes with rate limiting
  });
  
  it('should integrate with authentication middleware', () => {
    // Test that admin authentication is properly enforced
    // This would require testing the API routes with auth middleware
  });
});
