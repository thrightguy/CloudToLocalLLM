import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/container_status.dart';
import '../config/app_config.dart';
import 'local_auth_service.dart';

/// Service that handles backend container orchestration
class BackendService {
  final http.Client _client;
  final LocalAuthService _authService;
  final String _baseUrl;

  BackendService({
    http.Client? client,
    required LocalAuthService authService,
    String? baseUrl,
  })  : _client = client ?? http.Client(),
        _authService = authService,
        _baseUrl = baseUrl ?? AppConfig.cloudBaseUrl;

  /// Creates a container for a user
  Future<ContainerStatus> createContainer(String userId) async {
    try {
      final token = _authService.getToken();
      if (token == null) {
        throw Exception('Not authenticated');
      }

      final response = await _client.post(
        Uri.parse('$_baseUrl/api/containers'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'userId': userId,
        }),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        return ContainerStatus.fromJson(
          jsonDecode(response.body),
        );
      } else {
        throw Exception(
          'Failed to create container: ${response.statusCode}',
        );
      }
    } catch (e) {
      debugPrint('Error creating container: $e');

      // In development, return a simulated result
      if (kDebugMode) {
        return ContainerStatus(
          id: 'simulated-id-${DateTime.now().millisecondsSinceEpoch}',
          userId: userId,
          status: 'creating',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
      }

      rethrow;
    }
  }

  /// Gets the status of a container for a user
  Future<ContainerStatus?> getContainerStatus(String userId) async {
    try {
      final token = _authService.getToken();
      if (token == null) {
        throw Exception('Not authenticated');
      }

      final response = await _client.get(
        Uri.parse('$_baseUrl/api/containers/$userId'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return ContainerStatus.fromJson(
          jsonDecode(response.body),
        );
      } else if (response.statusCode == 404) {
        // Container not found
        return null;
      } else {
        throw Exception(
          'Failed to get container status: ${response.statusCode}',
        );
      }
    } catch (e) {
      debugPrint('Error getting container status: $e');

      // In development, return a simulated result
      if (kDebugMode) {
        return ContainerStatus(
          id: 'simulated-id',
          userId: userId,
          status: 'running',
          createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
          updatedAt: DateTime.now(),
        );
      }

      rethrow;
    }
  }

  /// Deletes a container for a user
  Future<void> deleteContainer(String userId) async {
    try {
      final token = _authService.getToken();
      if (token == null) {
        throw Exception('Not authenticated');
      }

      final response = await _client.delete(
        Uri.parse('$_baseUrl/api/containers/$userId'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception(
          'Failed to delete container: ${response.statusCode}',
        );
      }
    } catch (e) {
      debugPrint('Error deleting container: $e');
      rethrow;
    }
  }

  /// Associates a key hash with a user's container
  Future<void> associateKeyHash(String userId, String keyHash) async {
    try {
      final token = _authService.getToken();
      if (token == null) {
        throw Exception('Not authenticated');
      }

      final response = await _client.post(
        Uri.parse('$_baseUrl/api/containers/$userId/key'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'keyHash': keyHash,
        }),
      );

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception(
          'Failed to associate key hash: ${response.statusCode}',
        );
      }
    } catch (e) {
      debugPrint('Error associating key hash: $e');
      rethrow;
    }
  }
}
