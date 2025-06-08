import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Integrated tunnel manager service for CloudToLocalLLM v3.3.1+
///
/// Consolidates tunnel management functionality from the separate tunnel_manager app
/// into the main application for unified architecture.
class TunnelManagerService extends ChangeNotifier {
  static const String _authTokenKey = 'cloudtolocalllm_auth_token';

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  // Connection state
  bool _isConnected = false;
  bool _isConnecting = false;
  String? _error;

  // Connection status for different endpoints
  final Map<String, ConnectionStatus> _connectionStatus = {};

  // HTTP client for connections
  late http.Client _httpClient;

  // Timers for health checks
  Timer? _healthCheckTimer;

  // WebSocket connections for real-time updates
  WebSocket? _cloudWebSocket;

  // Configuration
  TunnelConfig _config = TunnelConfig.defaultConfig();

  // Getters
  bool get isConnected => _isConnected;
  bool get isConnecting => _isConnecting;
  String? get error => _error;
  TunnelConfig get config => _config;
  Map<String, ConnectionStatus> get connectionStatus =>
      Map.unmodifiable(_connectionStatus);

  /// Initialize the tunnel manager service
  Future<void> initialize() async {
    _httpClient = http.Client();

    debugPrint('🚇 [TunnelManager] Initializing tunnel manager service...');

    // Load configuration
    await _loadConfiguration();

    // Start initial connection attempts
    await _initializeConnections();

    // Start health monitoring
    _startHealthChecks();

    notifyListeners();
  }

  /// Load configuration from storage
  Future<void> _loadConfiguration() async {
    try {
      // For now, use default configuration
      // In the future, this could load from secure storage or config files
      _config = TunnelConfig.defaultConfig();
      debugPrint('🚇 [TunnelManager] Configuration loaded');
    } catch (e) {
      debugPrint('🚇 [TunnelManager] Failed to load configuration: $e');
      _config = TunnelConfig.defaultConfig();
    }
  }

  /// Initialize all configured connections
  Future<void> _initializeConnections() async {
    _isConnecting = true;
    _error = null;
    notifyListeners();

    try {
      // Initialize local Ollama connection
      if (_config.enableLocalOllama) {
        await _initializeOllamaConnection();
      }

      // Initialize cloud proxy connection
      if (_config.enableCloudProxy) {
        await _initializeCloudConnection();
      }

      // Update overall connection status
      _updateOverallStatus();
    } catch (e) {
      _error = 'Failed to initialize connections: $e';
      debugPrint('🚇 [TunnelManager] Connection initialization error: $e');
    } finally {
      _isConnecting = false;
      notifyListeners();
    }
  }

  /// Initialize local Ollama connection
  Future<void> _initializeOllamaConnection() async {
    final ollamaUrl = 'http://${_config.ollamaHost}:${_config.ollamaPort}';

    try {
      debugPrint('🚇 [TunnelManager] Testing Ollama connection to $ollamaUrl');

      final response = await _httpClient
          .get(
            Uri.parse('$ollamaUrl/api/version'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(Duration(seconds: _config.connectionTimeout));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final version = data['version'] ?? 'Unknown';

        // Get available models
        final modelsResponse = await _httpClient
            .get(
              Uri.parse('$ollamaUrl/api/tags'),
              headers: {'Content-Type': 'application/json'},
            )
            .timeout(Duration(seconds: _config.connectionTimeout));

        List<String> models = [];
        if (modelsResponse.statusCode == 200) {
          final modelsData = json.decode(modelsResponse.body);
          models =
              (modelsData['models'] as List?)
                  ?.map((model) => model['name']?.toString() ?? '')
                  .where((name) => name.isNotEmpty)
                  .toList() ??
              [];
        }

        _connectionStatus['ollama'] = ConnectionStatus(
          type: 'ollama',
          isConnected: true,
          endpoint: ollamaUrl,
          version: version,
          models: models,
          lastCheck: DateTime.now(),
          latency: 0,
        );

        debugPrint(
          '🚇 [TunnelManager] Ollama connection successful: $version, ${models.length} models',
        );
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      _connectionStatus['ollama'] = ConnectionStatus(
        type: 'ollama',
        isConnected: false,
        endpoint: ollamaUrl,
        error: e.toString(),
        lastCheck: DateTime.now(),
      );
      debugPrint('🚇 [TunnelManager] Ollama connection failed: $e');
    }
  }

  /// Initialize cloud proxy connection
  Future<void> _initializeCloudConnection() async {
    try {
      debugPrint(
        '🚇 [TunnelManager] Testing cloud proxy connection to ${_config.cloudProxyUrl}',
      );

      // Get authentication token
      final authToken = await _getAuthToken();
      if (authToken == null) {
        throw Exception('No authentication token available');
      }

      final response = await _httpClient
          .get(
            Uri.parse('${_config.cloudProxyUrl}/api/health'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $authToken',
            },
          )
          .timeout(Duration(seconds: _config.connectionTimeout));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final version = data['version'] ?? 'Unknown';

        _connectionStatus['cloud'] = ConnectionStatus(
          type: 'cloud',
          isConnected: true,
          endpoint: _config.cloudProxyUrl,
          version: version,
          lastCheck: DateTime.now(),
          latency: 0,
        );

        debugPrint(
          '🚇 [TunnelManager] Cloud proxy connection successful: $version',
        );

        // Establish WebSocket connection for real-time updates
        await _establishCloudWebSocket(authToken);
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      _connectionStatus['cloud'] = ConnectionStatus(
        type: 'cloud',
        isConnected: false,
        endpoint: _config.cloudProxyUrl,
        error: e.toString(),
        lastCheck: DateTime.now(),
      );
      debugPrint('🚇 [TunnelManager] Cloud proxy connection failed: $e');
    }
  }

  /// Establish WebSocket connection to cloud proxy
  Future<void> _establishCloudWebSocket(String authToken) async {
    try {
      final wsUrl = '${_config.cloudProxyUrl.replaceFirst('http', 'ws')}/ws';
      _cloudWebSocket = await WebSocket.connect(
        wsUrl,
        headers: {'Authorization': 'Bearer $authToken'},
      );

      _cloudWebSocket!.listen(
        (data) {
          try {
            final message = json.decode(data);
            _handleCloudWebSocketMessage(message);
          } catch (e) {
            debugPrint(
              '🚇 [TunnelManager] Error parsing WebSocket message: $e',
            );
          }
        },
        onError: (error) {
          debugPrint('🚇 [TunnelManager] Cloud WebSocket error: $error');
          _cloudWebSocket = null;
        },
        onDone: () {
          debugPrint('🚇 [TunnelManager] Cloud WebSocket connection closed');
          _cloudWebSocket = null;
        },
      );

      debugPrint('🚇 [TunnelManager] Cloud WebSocket connection established');
    } catch (e) {
      debugPrint('🚇 [TunnelManager] Failed to establish cloud WebSocket: $e');
    }
  }

  /// Handle incoming WebSocket messages from cloud proxy
  void _handleCloudWebSocketMessage(Map<String, dynamic> message) {
    final type = message['type'];

    switch (type) {
      case 'status_update':
        final status = _connectionStatus['cloud'];
        if (status != null) {
          _connectionStatus['cloud'] = status.copyWith(
            lastCheck: DateTime.now(),
            latency: message['latency']?.toDouble() ?? status.latency,
          );
          notifyListeners();
        }
        break;

      case 'model_update':
        final status = _connectionStatus['cloud'];
        if (status != null) {
          final models =
              (message['models'] as List?)
                  ?.map((model) => model.toString())
                  .toList() ??
              [];
          _connectionStatus['cloud'] = status.copyWith(models: models);
          notifyListeners();
        }
        break;

      default:
        debugPrint('🚇 [TunnelManager] Unknown WebSocket message type: $type');
    }
  }

  /// Get authentication token from secure storage
  Future<String?> _getAuthToken() async {
    return await _secureStorage.read(key: _authTokenKey);
  }

  /// Update overall connection status
  void _updateOverallStatus() {
    final hasConnectedEndpoint = _connectionStatus.values.any(
      (status) => status.isConnected,
    );
    _isConnected = hasConnectedEndpoint;

    if (!_isConnected && _connectionStatus.isNotEmpty) {
      final errors = _connectionStatus.values
          .where((status) => !status.isConnected && status.error != null)
          .map((status) => '${status.type}: ${status.error}')
          .join(', ');
      _error = errors.isNotEmpty
          ? 'Connection errors: $errors'
          : 'No connections available';
    } else {
      _error = null;
    }
  }

  /// Start periodic health checks
  void _startHealthChecks() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = Timer.periodic(
      Duration(seconds: _config.healthCheckInterval),
      (_) => _performHealthChecks(),
    );
  }

  /// Perform health checks on all connections
  Future<void> _performHealthChecks() async {
    for (final entry in _connectionStatus.entries) {
      final type = entry.key;
      final status = entry.value;

      if (!status.isConnected) continue;

      try {
        final stopwatch = Stopwatch()..start();

        if (type == 'ollama') {
          await _checkOllamaHealth(status);
        } else if (type == 'cloud') {
          await _checkCloudHealth(status);
        }

        stopwatch.stop();

        // Update latency
        _connectionStatus[type] = status.copyWith(
          lastCheck: DateTime.now(),
          latency: stopwatch.elapsedMilliseconds.toDouble(),
        );
      } catch (e) {
        // Mark connection as failed
        _connectionStatus[type] = status.copyWith(
          isConnected: false,
          error: e.toString(),
          lastCheck: DateTime.now(),
        );

        debugPrint('🚇 [TunnelManager] Health check failed for $type: $e');
      }
    }

    _updateOverallStatus();
    notifyListeners();
  }

  /// Check Ollama health
  Future<void> _checkOllamaHealth(ConnectionStatus status) async {
    final response = await _httpClient
        .get(
          Uri.parse('${status.endpoint}/api/version'),
          headers: {'Content-Type': 'application/json'},
        )
        .timeout(Duration(seconds: 5));

    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}');
    }
  }

  /// Check cloud proxy health
  Future<void> _checkCloudHealth(ConnectionStatus status) async {
    final authToken = await _getAuthToken();
    if (authToken == null) {
      throw Exception('No authentication token');
    }

    final response = await _httpClient
        .get(
          Uri.parse('${status.endpoint}/api/health'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $authToken',
          },
        )
        .timeout(Duration(seconds: 5));

    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}');
    }
  }

  /// Graceful shutdown
  Future<void> shutdown() async {
    debugPrint('🚇 [TunnelManager] Shutting down tunnel manager service...');

    _healthCheckTimer?.cancel();
    _cloudWebSocket?.close();
    _httpClient.close();

    _isConnected = false;
    _connectionStatus.clear();

    notifyListeners();
  }

  /// Force reconnection to all endpoints
  Future<void> reconnect() async {
    debugPrint('🚇 [TunnelManager] Forcing reconnection to all endpoints...');

    _connectionStatus.clear();
    await _initializeConnections();
  }

  /// Get best available connection for routing requests
  String? getBestConnection() {
    // Prioritize local Ollama if available
    final ollamaStatus = _connectionStatus['ollama'];
    if (ollamaStatus?.isConnected == true) {
      return 'ollama';
    }

    // Fallback to cloud proxy
    final cloudStatus = _connectionStatus['cloud'];
    if (cloudStatus?.isConnected == true) {
      return 'cloud';
    }

    return null;
  }

  /// Get connection status for system tray display
  TrayConnectionStatus getTrayConnectionStatus() {
    final ollamaConnected = _connectionStatus['ollama']?.isConnected ?? false;
    final cloudConnected = _connectionStatus['cloud']?.isConnected ?? false;

    if (ollamaConnected && cloudConnected) {
      return TrayConnectionStatus.allConnected;
    } else if (ollamaConnected || cloudConnected) {
      return TrayConnectionStatus.partiallyConnected;
    } else if (_isConnecting) {
      return TrayConnectionStatus.connecting;
    } else {
      return TrayConnectionStatus.disconnected;
    }
  }
}

/// Connection status for a specific endpoint
class ConnectionStatus {
  final String type;
  final bool isConnected;
  final String endpoint;
  final String? version;
  final List<String> models;
  final String? error;
  final DateTime lastCheck;
  final double latency;

  const ConnectionStatus({
    required this.type,
    required this.isConnected,
    required this.endpoint,
    this.version,
    this.models = const [],
    this.error,
    required this.lastCheck,
    this.latency = 0.0,
  });

  ConnectionStatus copyWith({
    String? type,
    bool? isConnected,
    String? endpoint,
    String? version,
    List<String>? models,
    String? error,
    DateTime? lastCheck,
    double? latency,
  }) {
    return ConnectionStatus(
      type: type ?? this.type,
      isConnected: isConnected ?? this.isConnected,
      endpoint: endpoint ?? this.endpoint,
      version: version ?? this.version,
      models: models ?? this.models,
      error: error ?? this.error,
      lastCheck: lastCheck ?? this.lastCheck,
      latency: latency ?? this.latency,
    );
  }
}

/// Tunnel configuration
class TunnelConfig {
  final bool enableLocalOllama;
  final bool enableCloudProxy;
  final String ollamaHost;
  final int ollamaPort;
  final String cloudProxyUrl;
  final int connectionTimeout;
  final int healthCheckInterval;

  const TunnelConfig({
    required this.enableLocalOllama,
    required this.enableCloudProxy,
    required this.ollamaHost,
    required this.ollamaPort,
    required this.cloudProxyUrl,
    required this.connectionTimeout,
    required this.healthCheckInterval,
  });

  factory TunnelConfig.defaultConfig() {
    return const TunnelConfig(
      enableLocalOllama: true,
      enableCloudProxy: true,
      ollamaHost: 'localhost',
      ollamaPort: 11434,
      cloudProxyUrl: 'https://app.cloudtolocalllm.online',
      connectionTimeout: 10,
      healthCheckInterval: 30,
    );
  }
}

/// System tray connection status
enum TrayConnectionStatus {
  disconnected,
  connecting,
  partiallyConnected,
  allConnected,
}
