import 'dart:async';
import 'package:flutter/foundation.dart';
import 'local_ollama_connection_service.dart';
import 'tunnel_manager_service.dart';
import 'streaming_service.dart';
import 'ollama_service.dart';
import 'cloud_streaming_service.dart';
import 'auth_service.dart';

/// Connection manager service that coordinates between local and cloud connections
///
/// Implements the fallback hierarchy:
/// 1. Primary: Local Ollama (direct connection, no tunnel needed)
/// 2. Secondary: Cloud proxy via tunnel connection
///
/// Note: Zrok tunnel functionality is now handled as a standalone service
/// separate from Ollama connections.
///
/// Ensures provider isolation - each connection can fail independently.
class ConnectionManagerService extends ChangeNotifier {
  final LocalOllamaConnectionService _localOllama;
  final TunnelManagerService _tunnelManager;
  final AuthService _authService;

  // Connection preferences
  bool _preferLocalOllama = true;
  String? _selectedModel;

  // Cloud streaming service (lazy initialized)
  CloudStreamingService? _cloudStreamingService;

  ConnectionManagerService({
    required LocalOllamaConnectionService localOllama,
    required TunnelManagerService tunnelManager,
    required AuthService authService,
  }) : _localOllama = localOllama,
       _tunnelManager = tunnelManager,
       _authService = authService {
    // Listen to connection changes
    _localOllama.addListener(_onConnectionChanged);
    _tunnelManager.addListener(_onConnectionChanged);

    if (kIsWeb) {
      debugPrint(
        '🔗 [ConnectionManager] Web platform detected - will use cloud proxy only',
      );
      debugPrint(
        '🔗 [ConnectionManager] Local Ollama connections disabled to prevent CORS errors',
      );
    } else {
      debugPrint(
        '🔗 [ConnectionManager] Desktop platform detected - full connection hierarchy available',
      );
    }

    debugPrint('🔗 [ConnectionManager] Service initialized');
  }

  // Getters
  bool get hasLocalConnection => _localOllama.isConnected;
  bool get hasCloudConnection => _tunnelManager.isConnected;
  bool get hasAnyConnection => hasLocalConnection || hasCloudConnection;
  String? get selectedModel => _selectedModel;
  List<String> get availableModels => _getAvailableModels();

  /// Get the best available connection type
  /// Fallback hierarchy:
  /// 1. Local Ollama (if preferred and available) - DESKTOP ONLY
  /// 2. Cloud proxy (WebSocket bridge) - WEB AND DESKTOP
  /// 3. Local Ollama (fallback if not preferred initially) - DESKTOP ONLY
  ///
  /// Platform-aware: Web platform NEVER uses local connections to prevent CORS errors.
  /// Note: Zrok is now handled as a standalone service and not part of
  /// the Ollama connection fallback hierarchy.
  ConnectionType getBestConnectionType() {
    if (kIsWeb) {
      // Web platform: Only use cloud proxy to prevent CORS errors
      debugPrint(
        '🔗 [ConnectionManager] Web platform detected - forcing cloud proxy connection',
      );
      if (hasCloudConnection) {
        return ConnectionType.cloud;
      } else {
        debugPrint(
          '🔗 [ConnectionManager] No cloud connection available on web platform',
        );
        return ConnectionType.none;
      }
    }

    // Desktop platform: Use normal fallback hierarchy
    if (_preferLocalOllama && hasLocalConnection) {
      debugPrint(
        '🔗 [ConnectionManager] Using preferred local Ollama connection',
      );
      return ConnectionType.local;
    } else if (hasCloudConnection) {
      debugPrint('🔗 [ConnectionManager] Using cloud proxy connection');
      return ConnectionType.cloud;
    } else if (hasLocalConnection) {
      debugPrint(
        '🔗 [ConnectionManager] Using fallback local Ollama connection',
      );
      return ConnectionType.local;
    } else {
      debugPrint('🔗 [ConnectionManager] No connections available');
      return ConnectionType.none;
    }
  }

  /// Get streaming service for the best available connection
  StreamingService? getStreamingService() {
    final connectionType = getBestConnectionType();

    switch (connectionType) {
      case ConnectionType.local:
        final streamingService = _localOllama.streamingService;
        if (streamingService != null && streamingService.connection.isActive) {
          debugPrint('🔗 [ConnectionManager] Using local Ollama streaming');
          return streamingService;
        }
        break;

      case ConnectionType.cloud:
        // Initialize cloud streaming service if needed
        _cloudStreamingService ??= CloudStreamingService(
          authService: _authService,
        );

        if (_cloudStreamingService!.connection.isActive) {
          debugPrint('🔗 [ConnectionManager] Using cloud streaming');
          return _cloudStreamingService;
        } else {
          // Try to establish connection
          _cloudStreamingService!.establishConnection().catchError((e) {
            debugPrint(
              '🔗 [ConnectionManager] Cloud streaming connection failed: $e',
            );
          });
          return _cloudStreamingService;
        }

      case ConnectionType.none:
        debugPrint('🔗 [ConnectionManager] No streaming service available');
        break;
    }

    return null;
  }

  /// Get chat service for the best available connection
  Future<String?> sendChatMessage({
    required String model,
    required String message,
    List<Map<String, String>>? history,
  }) async {
    final connectionType = getBestConnectionType();

    switch (connectionType) {
      case ConnectionType.local:
        debugPrint('🔗 [ConnectionManager] Using local Ollama for chat');
        return await _localOllama.chat(
          model: model,
          message: message,
          history: history,
        );

      case ConnectionType.cloud:
        debugPrint('🔗 [ConnectionManager] Using cloud proxy for chat');
        // Create OllamaService configured for cloud proxy
        final ollamaService = OllamaService();
        return await ollamaService.chat(
          model: model,
          message: message,
          history: history,
        );

      case ConnectionType.none:
        throw StateError('No connection available for chat');
    }
  }

  /// Initialize all connections
  Future<void> initialize() async {
    debugPrint('🔗 [ConnectionManager] Initializing connections...');

    // Initialize local Ollama (independent of tunnel)
    try {
      await _localOllama.initialize();
    } catch (e) {
      debugPrint(
        '🔗 [ConnectionManager] Local Ollama initialization failed: $e',
      );
      // Don't fail overall initialization if local Ollama fails
    }

    // Initialize tunnel manager (cloud proxy only)
    try {
      await _tunnelManager.initialize();
    } catch (e) {
      debugPrint(
        '🔗 [ConnectionManager] Tunnel manager initialization failed: $e',
      );
      // Don't fail overall initialization if tunnel fails
    }

    // Auto-select first available model
    _autoSelectModel();

    debugPrint('🔗 [ConnectionManager] Initialization complete');
    notifyListeners();
  }

  /// Set the selected model
  void setSelectedModel(String model) {
    _selectedModel = model;
    debugPrint('🔗 [ConnectionManager] Selected model: $model');
    notifyListeners();
  }

  /// Set connection preference
  void setPreferLocalOllama(bool prefer) {
    _preferLocalOllama = prefer;
    debugPrint('🔗 [ConnectionManager] Prefer local Ollama: $prefer');
    notifyListeners();
  }

  /// Force reconnection of all services
  Future<void> reconnectAll() async {
    debugPrint('🔗 [ConnectionManager] Reconnecting all services...');

    // Reconnect local Ollama
    try {
      await _localOllama.reconnect();
    } catch (e) {
      debugPrint('🔗 [ConnectionManager] Local Ollama reconnect failed: $e');
    }

    // Reconnect tunnel manager
    try {
      await _tunnelManager.reconnect();
    } catch (e) {
      debugPrint('🔗 [ConnectionManager] Tunnel manager reconnect failed: $e');
    }

    notifyListeners();
  }

  /// Get connection status summary
  /// Note: Zrok status is now handled separately as a standalone service
  Map<String, dynamic> getConnectionStatus() {
    return {
      'local': {
        'connected': hasLocalConnection,
        'version': _localOllama.version,
        'models': _localOllama.models,
        'error': _localOllama.error,
        'lastCheck': _localOllama.lastCheck?.toIso8601String(),
      },
      'cloud': {
        'connected': hasCloudConnection,
        'error': _tunnelManager.error,
        'status': _tunnelManager.connectionStatus,
      },
      'active': getBestConnectionType().name,
      'selectedModel': _selectedModel,
    };
  }

  /// Get all available models from all connections
  List<String> _getAvailableModels() {
    final models = <String>[];

    // Add local models
    if (hasLocalConnection) {
      models.addAll(_localOllama.models);
    }

    // Add cloud models (if available)
    if (hasCloudConnection) {
      final cloudStatus = _tunnelManager.connectionStatus['cloud'];
      if (cloudStatus?.models != null) {
        models.addAll(cloudStatus!.models);
      }
    }

    // Remove duplicates and sort
    return models.toSet().toList()..sort();
  }

  /// Auto-select the first available model
  void _autoSelectModel() {
    if (_selectedModel != null) return;

    final models = availableModels;
    if (models.isNotEmpty) {
      setSelectedModel(models.first);
    }
  }

  /// Handle connection changes
  void _onConnectionChanged() {
    // Auto-select model if none selected
    _autoSelectModel();

    // Notify listeners of connection changes
    notifyListeners();

    // Log connection status
    final status = getConnectionStatus();
    debugPrint('🔗 [ConnectionManager] Connection status: $status');
  }

  @override
  void dispose() {
    debugPrint('🔗 [ConnectionManager] Disposing service');
    _localOllama.removeListener(_onConnectionChanged);
    _tunnelManager.removeListener(_onConnectionChanged);
    _cloudStreamingService?.dispose();
    super.dispose();
  }
}

/// Connection type enumeration
/// Note: Zrok is now handled as a standalone service
enum ConnectionType { local, cloud, none }
