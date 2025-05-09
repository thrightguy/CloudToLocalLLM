import 'package:flutter/foundation.dart';
import 'backend_service.dart';

/// Service that handles API calls to the backend for container management.
class ApiService {
  final BackendService _backendService;

  ApiService({
    required BackendService backendService,
  }) : _backendService = backendService;

  /// Associate a key hash with a user's container
  Future<void> associateKeyHash(String userId, String keyHash) async {
    try {
      await _backendService.associateKeyHash(userId, keyHash);
    } catch (e) {
      debugPrint('Error associating key hash: $e');
      // In a real app, we would have proper error handling here
      // For now, during development, just rethrow
      rethrow;
    }
  }

  /// Get a user's container status
  Future<String> getContainerStatus(String userId) async {
    try {
      final status = await _backendService.getContainerStatus(userId);
      return status?.status ?? 'not_created';
    } catch (e) {
      debugPrint('Error getting container status: $e');
      rethrow;
    }
  }

  /// Create a container for a user
  Future<void> createContainer(String userId) async {
    try {
      await _backendService.createContainer(userId);
    } catch (e) {
      debugPrint('Error creating container: $e');
      rethrow;
    }
  }

  /// Reset a user's container
  Future<void> resetUserContainer(String userId) async {
    try {
      await _backendService.deleteContainer(userId);
    } catch (e) {
      debugPrint('Error resetting container: $e');
      rethrow;
    }
  }
}
