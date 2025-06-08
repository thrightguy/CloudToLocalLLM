import 'package:flutter/foundation.dart';
import 'tunnel_manager_service.dart';

/// Unified connection service that provides a consistent API for connections
///
/// This service integrates with the tunnel manager service to provide
/// a unified interface for both local Ollama and cloud connections.
class UnifiedConnectionService extends ChangeNotifier {
  TunnelManagerService? _tunnelManager;

  bool _isConnected = false;
  String? _version;
  List<OllamaModel> _models = [];
  bool _isLoading = false;
  String? _error;
  String _connectionType = 'none';

  // Connection status from tunnel manager
  Map<String, ConnectionStatus>? _connectionStatus;

  UnifiedConnectionService() {
    // Will be initialized when tunnel manager is available
  }

  /// Set the tunnel manager service reference
  void setTunnelManager(TunnelManagerService tunnelManager) {
    _tunnelManager = tunnelManager;
    
    // Listen to connection status changes
    _tunnelManager!.addListener(_handleConnectionStatusChange);
    
    // Update initial status
    _handleConnectionStatusChange();
  }

  // Getters
  bool get isConnected => _isConnected;
  String? get version => _version;
  List<OllamaModel> get models => _models;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get connectionType => _connectionType;
  Map<String, ConnectionStatus>? get connectionStatus => _connectionStatus;

  /// Initialize the connection service
  Future<bool> initialize() async {
    if (_tunnelManager == null) {
      debugPrint("🔗 [UnifiedConnection] Tunnel manager not available, cannot initialize connection service");
      return false;
    }

    // Get initial connection status
    await refreshConnectionStatus();
    return true;
  }

  /// Refresh connection status from tunnel manager
  Future<void> refreshConnectionStatus() async {
    if (_tunnelManager == null) return;
    
    try {
      _setLoading(true);
      _clearError();

      _connectionStatus = _tunnelManager!.connectionStatus;
      _updateConnectionState();
    } catch (e) {
      _setError('Error refreshing connection status: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Handle connection status changes from tunnel manager
  void _handleConnectionStatusChange() {
    if (_tunnelManager == null) return;
    
    _connectionStatus = _tunnelManager!.connectionStatus;
    _updateConnectionState();
  }

  /// Update connection state based on tunnel manager status
  void _updateConnectionState() {
    if (_connectionStatus == null) {
      _isConnected = false;
      _connectionType = 'none';
      _version = null;
      _models = [];
      _setError('No connection status available');
      return;
    }

    // Find the best available connection
    String? bestConnection;
    ConnectionStatus? bestStatus;

    // Prefer local Ollama if connected
    final ollamaStatus = _connectionStatus!['ollama'];
    final cloudStatus = _connectionStatus!['cloud'];

    if (ollamaStatus?.isConnected == true) {
      bestConnection = 'ollama';
      bestStatus = ollamaStatus;
    } else if (cloudStatus?.isConnected == true) {
      bestConnection = 'cloud';
      bestStatus = cloudStatus;
    }

    if (bestConnection != null && bestStatus != null) {
      _isConnected = true;
      _connectionType = bestConnection;
      _version = bestStatus.version ?? 'Unknown';
      _models = bestStatus.models
          .map((model) => OllamaModel(name: model))
          .toList();
      _clearError();
    } else {
      _isConnected = false;
      _connectionType = 'none';
      _version = null;
      _models = [];

      // Set error message based on available statuses
      final errors = <String>[];
      _connectionStatus!.forEach((type, status) {
        if (!status.isConnected && status.error != null) {
          errors.add('$type: ${status.error}');
        }
      });

      if (errors.isNotEmpty) {
        _setError('Connection errors: ${errors.join(', ')}');
      } else {
        _setError('No connections available');
      }
    }

    notifyListeners();
  }

  /// Test connection by refreshing status
  Future<bool> testConnection() async {
    try {
      _setLoading(true);
      _clearError();

      if (_tunnelManager != null) {
        await _tunnelManager!.reconnect();
        await refreshConnectionStatus();
        return _isConnected;
      } else {
        _setError('Tunnel manager not available');
        return false;
      }
    } catch (e) {
      _setError('Connection test failed: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Get available models (simplified - returns cached models)
  Future<List<OllamaModel>> getModels() async {
    try {
      _setLoading(true);
      _clearError();

      // For now, return cached models from connection status
      // In the future, this could make direct API calls through tunnel manager
      await refreshConnectionStatus();
      return _models;
    } catch (e) {
      _setError('Error loading models: $e');
      return [];
    } finally {
      _setLoading(false);
    }
  }

  /// Get best available connection type
  String? getBestConnection() {
    return _tunnelManager?.getBestConnection();
  }

  // Helper methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _error = error;
    debugPrint('🔗 [UnifiedConnection] Error: $error');
    notifyListeners();
  }

  void _clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _tunnelManager?.removeListener(_handleConnectionStatusChange);
    super.dispose();
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
