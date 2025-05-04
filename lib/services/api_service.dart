import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import 'auth_service.dart';
import 'backend_service.dart';

/// Service that handles API calls to the backend for container management.
class ApiService {
  final http.Client _client;
  final AuthService _authService;
  final BackendService _backendService;

  ApiService({
    http.Client? client,
    required AuthService authService,
    BackendService? backendService,
  })  : _client = client ?? http.Client(),
        _authService = authService,
        _backendService =
            backendService ?? BackendService(authService: authService);

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

      if (status == null) {
        return 'not_created';
      }

      return status.status;
    } catch (e) {
      debugPrint('Error getting container status: $e');

      // During development, simulate a container status
      // TODO: Remove this in production
      if (kDebugMode) {
        await Future.delayed(const Duration(seconds: 1));
        return 'running';
      }

      rethrow;
    }
  }

  /// Create a container for a user
  Future<void> createContainer(String userId) async {
    try {
      await _backendService.createContainer(userId);
    } catch (e) {
      debugPrint('Error creating container: $e');

      // During development, simulate container creation
      // TODO: Remove this in production
      if (kDebugMode) {
        await Future.delayed(const Duration(seconds: 2));
        return;
      }

      rethrow;
    }
  }

  /// Reset a user's container
  Future<void> resetUserContainer(String userId) async {
    try {
      await _backendService.deleteContainer(userId);
    } catch (e) {
      debugPrint('Error resetting container: $e');

      // During development, simulate container reset
      // TODO: Remove this in production
      if (kDebugMode) {
        await Future.delayed(const Duration(seconds: 2));
        return;
      }

      rethrow;
    }
  }
}
