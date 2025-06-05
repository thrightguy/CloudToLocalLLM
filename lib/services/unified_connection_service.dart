import 'package:flutter/foundation.dart';
import 'enhanced_tray_service.dart';

/// Unified connection service that routes ALL connections through the tray daemon
///
/// This service provides a consistent API for both local Ollama and cloud connections,
/// with all actual connections managed by the independent tray daemon's connection broker.
class UnifiedConnectionService extends ChangeNotifier {
  final EnhancedTrayService _trayService = EnhancedTrayService();

  bool _isConnected = false;
  String? _version;
  List<OllamaModel> _models = [];
  bool _isLoading = false;
  String? _error;
  String _connectionType = 'none';

  // Connection status from daemon
  Map<String, dynamic>? _connectionStatus;

  UnifiedConnectionService() {
    // Listen to connection status changes from daemon
    _trayService.messageStream.listen((message) {
      if (message['command'] == 'CONNECTION_STATUS_CHANGED') {
        _handleConnectionStatusChange(message);
      }
    });
  }

  // Getters
  bool get isConnected => _isConnected;
  String? get version => _version;
  List<OllamaModel> get models => _models;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get connectionType => _connectionType;
  Map<String, dynamic>? get connectionStatus => _connectionStatus;

  /// Initialize the connection service
  Future<bool> initialize() async {
    if (!_trayService.isInitialized) {
      debugPrint(
          "Tray service not initialized, cannot initialize connection service");
      return false;
    }

    // Get initial connection status
    await refreshConnectionStatus();
    return true;
  }

  /// Refresh connection status from daemon
  Future<void> refreshConnectionStatus() async {
    try {
      _setLoading(true);
      _clearError();

      final status = await _trayService.getConnectionStatus();
      if (status != null) {
        _connectionStatus = status;
        _updateConnectionState(status);
      } else {
        _setError('Failed to get connection status from daemon');
      }
    } catch (e) {
      _setError('Error refreshing connection status: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Handle connection status changes from daemon
  void _handleConnectionStatusChange(Map<String, dynamic> message) {
    final connectionType = message['connection_type'] as String?;
    final status = message['status'] as Map<String, dynamic>?;

    if (status != null) {
      debugPrint(
          'Connection status changed for $connectionType: ${status['state']}');

      // Update our cached status
      if (_connectionStatus != null) {
        _connectionStatus![connectionType!] = status;
      }

      // Update overall connection state
      _updateConnectionState(_connectionStatus ?? {});
    }
  }

  /// Update connection state based on daemon status
  void _updateConnectionState(Map<String, dynamic> status) {
    // Find the best available connection
    String? bestConnection;
    Map<String, dynamic>? bestStatus;

    // Prefer local_ollama if connected
    if (status['local_ollama']?['state'] == 'connected') {
      bestConnection = 'local_ollama';
      bestStatus = status['local_ollama'];
    } else if (status['cloud_proxy']?['state'] == 'connected') {
      bestConnection = 'cloud_proxy';
      bestStatus = status['cloud_proxy'];
    }

    if (bestConnection != null && bestStatus != null) {
      _isConnected = true;
      _connectionType = bestConnection;
      _version = bestStatus['version'] ?? 'Unknown';
      _models = (bestStatus['models'] as List<dynamic>?)
              ?.map((model) => OllamaModel(name: model.toString()))
              .toList() ??
          [];
      _clearError();
    } else {
      _isConnected = false;
      _connectionType = 'none';
      _version = null;
      _models = [];

      // Set error message based on available statuses
      final errors = <String>[];
      status.forEach((type, typeStatus) {
        if (typeStatus['error_message']?.isNotEmpty == true) {
          errors.add('$type: ${typeStatus['error_message']}');
        }
      });

      if (errors.isNotEmpty) {
        _setError('Connection errors: ${errors.join(', ')}');
      } else {
        _setError('No connections available');
      }
    }

    notifyListeners();

    // Send status update to tray daemon
    _sendStatusUpdateToTray();
  }

  /// Send connection status update to tray daemon
  void _sendStatusUpdateToTray() {
    if (_trayService.isConnected) {
      if (_isConnected) {
        if (_connectionType == 'local_ollama') {
          _trayService.updateOllamaStatus(
            connected: true,
            version: _version,
            models: _models.map((m) => m.name).toList(),
          );
        } else if (_connectionType == 'cloud_proxy') {
          _trayService.updateCloudStatus(
            connected: true,
            endpoint: 'app.cloudtolocalllm.online',
          );
        }
      } else {
        // Send disconnected status
        _trayService.updateOllamaStatus(
          connected: false,
          error: _error ?? 'Connection failed',
        );
      }
    }
  }

  /// Test connection by getting version info
  Future<bool> testConnection() async {
    try {
      _setLoading(true);
      _clearError();

      final result = await _trayService.proxyRequest(
        method: 'GET',
        path: '/api/version',
      );

      if (result != null) {
        debugPrint('Connection test successful: $result');
        await refreshConnectionStatus();
        return _isConnected;
      } else {
        _setError('Connection test failed: no response');
        return false;
      }
    } catch (e) {
      _setError('Connection test failed: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Get available models
  Future<List<OllamaModel>> getModels() async {
    try {
      _setLoading(true);
      _clearError();

      final result = await _trayService.proxyRequest(
        method: 'GET',
        path: '/api/tags',
      );

      if (result != null) {
        final modelsData = result['models'] as List<dynamic>? ?? [];
        _models = modelsData
            .map((model) => OllamaModel.fromJson(model as Map<String, dynamic>))
            .toList();

        debugPrint('Loaded ${_models.length} models');
        notifyListeners();
        return _models;
      } else {
        _setError('Failed to load models');
        return [];
      }
    } catch (e) {
      _setError('Error loading models: $e');
      return [];
    } finally {
      _setLoading(false);
    }
  }

  /// Send a chat message
  Future<String?> chat({
    required String model,
    required String message,
    List<Map<String, String>>? history,
  }) async {
    try {
      _setLoading(true);
      _clearError();

      final messages = [
        if (history != null) ...history,
        {'role': 'user', 'content': message},
      ];

      final result = await _trayService.proxyRequest(
        method: 'POST',
        path: '/api/chat',
        data: {
          'model': model,
          'messages': messages,
          'stream': false,
        },
      );

      if (result != null) {
        final responseMessage = result['message'];
        if (responseMessage != null && responseMessage['content'] != null) {
          return responseMessage['content'] as String;
        } else {
          _setError('Invalid response format');
          return null;
        }
      } else {
        _setError('No response from chat API');
        return null;
      }
    } catch (e) {
      _setError('Chat error: $e');
      return null;
    } finally {
      _setLoading(false);
    }
  }

  /// Pull a model from registry
  Future<bool> pullModel(String modelName) async {
    try {
      _setLoading(true);
      _clearError();

      final result = await _trayService.proxyRequest(
        method: 'POST',
        path: '/api/pull',
        data: {'name': modelName},
      );

      if (result != null) {
        debugPrint('Model pull successful: $result');
        // Refresh models list
        await getModels();
        return true;
      } else {
        _setError('Model pull failed');
        return false;
      }
    } catch (e) {
      _setError('Model pull error: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Update authentication token
  Future<void> updateAuthToken(String token) async {
    await _trayService.updateAuthToken(token);
    // Refresh connection status after token update
    await Future.delayed(const Duration(milliseconds: 500));
    await refreshConnectionStatus();
  }

  /// Clear authentication token
  Future<void> clearAuthToken() async {
    await updateAuthToken('');
  }

  // Helper methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _error = error;
    debugPrint('[UnifiedConnectionService] Error: $error');
    notifyListeners();
  }

  void _clearError() {
    _error = null;
    notifyListeners();
  }
}

/// Model class for Ollama models
class OllamaModel {
  final String name;
  final String? tag;
  final int? size;
  final DateTime? modifiedAt;

  OllamaModel({
    required this.name,
    this.tag,
    this.size,
    this.modifiedAt,
  });

  factory OllamaModel.fromJson(Map<String, dynamic> json) {
    return OllamaModel(
      name: json['name'] as String,
      tag: json['tag'] as String?,
      size: json['size'] as int?,
      modifiedAt: json['modified_at'] != null
          ? DateTime.tryParse(json['modified_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'tag': tag,
      'size': size,
      'modified_at': modifiedAt?.toIso8601String(),
    };
  }

  @override
  String toString() => name;
}
