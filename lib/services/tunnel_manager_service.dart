import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/ollama_connection_error.dart';
import 'streaming_service.dart';
import 'auth_service.dart';

/// Integrated tunnel manager service for CloudToLocalLLM v3.3.1+
///
/// Consolidates tunnel management functionality from the separate tunnel_manager app
/// into the main application for unified architecture.
class TunnelManagerService extends ChangeNotifier {
  static const String _authTokenKey = 'cloudtolocalllm_auth_token';

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final AuthService? _authService;

  // Constructor
  TunnelManagerService({AuthService? authService}) : _authService = authService;

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

  // Cloud streaming services only
  StreamSubscription<ConnectionStatusEvent>? _statusSubscription;

  // Debouncing for notifyListeners to prevent excessive rebuilds
  Timer? _notifyDebounceTimer;
  static const Duration _notifyDebounceDelay = Duration(milliseconds: 300);
  bool _isDisposed = false;

  // Getters
  bool get isConnected => _isConnected;
  bool get isConnecting => _isConnecting;
  String? get error => _error;
  TunnelConfig get config => _config;
  Map<String, ConnectionStatus> get connectionStatus =>
      Map.unmodifiable(_connectionStatus);

  /// Get cloud streaming service (local Ollama is now handled separately)
  /// TODO: Implement cloud streaming service

  /// Debounced notifyListeners to prevent excessive UI rebuilds
  void _debouncedNotifyListeners() {
    _notifyDebounceTimer?.cancel();
    _notifyDebounceTimer = Timer(_notifyDebounceDelay, () {
      if (!_isDisposed) {
        notifyListeners();
      }
    });
  }

  /// Initialize the tunnel manager service
  Future<void> initialize() async {
    _httpClient = http.Client();

    debugPrint('🚇 [TunnelManager] Initializing tunnel manager service...');

    // Load configuration
    await _loadConfiguration();

    // Initialize streaming services
    await _initializeStreamingServices();

    // Start initial connection attempts
    await _initializeConnections();

    // Start health monitoring
    _startHealthChecks();

    // Listen to status events
    _setupStatusEventListener();

    _debouncedNotifyListeners();
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

  /// Initialize cloud streaming services
  /// Local Ollama is now handled independently
  Future<void> _initializeStreamingServices() async {
    try {
      debugPrint('🚇 [TunnelManager] Initializing cloud streaming services...');

      // TODO: Initialize cloud streaming service when implemented

      debugPrint(
        '🚇 [TunnelManager] Cloud streaming services initialized successfully',
      );
    } catch (e) {
      debugPrint(
        '🚇 [TunnelManager] Failed to initialize cloud streaming services: $e',
      );
    }
  }

  /// Setup status event listener for cloud services only
  /// Local Ollama events are now handled independently
  void _setupStatusEventListener() {
    _statusSubscription?.cancel();
    _statusSubscription = StatusEventBus().statusStream.listen(
      (event) {
        debugPrint('🚇 [TunnelManager] Received status event: $event');

        // Only handle cloud proxy events now
        // Local Ollama events are handled by LocalOllamaConnectionService
        if (event.endpoint?.contains(_config.cloudProxyUrl) == true) {
          // TODO: Handle cloud proxy streaming events when implemented
          debugPrint('🚇 [TunnelManager] Cloud proxy event: ${event.state}');
        }
      },
      onError: (error) {
        debugPrint('🚇 [TunnelManager] Status event listener error: $error');
      },
    );
  }

  /// Initialize cloud proxy connections only
  /// Local Ollama is now handled independently
  Future<void> _initializeConnections() async {
    _isConnecting = true;
    _error = null;
    _debouncedNotifyListeners();

    try {
      // Initialize cloud proxy connection
      if (_config.enableCloudProxy) {
        await _initializeCloudConnection();
      }

      // Update overall connection status
      _updateOverallStatus();
    } catch (e) {
      _error = 'Failed to initialize cloud connections: $e';
      debugPrint(
        '🚇 [TunnelManager] Cloud connection initialization error: $e',
      );
    } finally {
      _isConnecting = false;
      _debouncedNotifyListeners();
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

  /// Establish WebSocket bridge connection to cloud proxy
  Future<void> _establishCloudWebSocket(String authToken) async {
    try {
      // Connect to bridge endpoint instead of status endpoint
      final wsUrl =
          '${_config.cloudProxyUrl.replaceFirst('http', 'ws')}/ws/bridge?token=$authToken';
      debugPrint('🚇 [TunnelManager] Connecting to bridge: $wsUrl');

      _cloudWebSocket = await WebSocket.connect(wsUrl);

      _cloudWebSocket!.listen(
        (data) {
          try {
            final message = json.decode(data);
            _handleCloudBridgeMessage(message);
          } catch (e) {
            debugPrint('🚇 [TunnelManager] Error parsing bridge message: $e');
          }
        },
        onError: (error) {
          debugPrint('🚇 [TunnelManager] Cloud bridge WebSocket error: $error');
          _cloudWebSocket = null;
          _updateConnectionStatus(false, 'WebSocket error: $error');
        },
        onDone: () {
          debugPrint(
            '🚇 [TunnelManager] Cloud bridge WebSocket connection closed',
          );
          _cloudWebSocket = null;
          _updateConnectionStatus(false, 'Connection closed');
        },
      );

      debugPrint(
        '🚇 [TunnelManager] Cloud bridge WebSocket connection established',
      );
    } catch (e) {
      debugPrint(
        '🚇 [TunnelManager] Failed to establish cloud bridge WebSocket: $e',
      );
      _updateConnectionStatus(false, 'Failed to connect: $e');
    }
  }

  /// Handle incoming bridge messages from cloud proxy
  void _handleCloudBridgeMessage(Map<String, dynamic> message) {
    final type = message['type'];
    final messageId = message['id'];

    debugPrint(
      '🚇 [TunnelManager] Received bridge message: $type (ID: $messageId)',
    );

    switch (type) {
      case 'auth':
        // Bridge authentication successful
        final data = message['data'];
        if (data['success'] == true) {
          final bridgeId = data['bridgeId'];
          debugPrint('🚇 [TunnelManager] Bridge authenticated: $bridgeId');
          _updateConnectionStatus(true, null);
        }
        break;

      case 'ping':
        // Respond to ping with pong
        _sendBridgeMessage({
          'type': 'pong',
          'id': _generateUuid(),
          'timestamp': DateTime.now().toIso8601String(),
        });
        break;

      case 'request':
        // Handle incoming Ollama request from cloud
        _handleOllamaRequest(message);
        break;

      default:
        debugPrint('🚇 [TunnelManager] Unknown bridge message type: $type');
    }
  }

  /// Handle bridge messages (public for testing)
  @visibleForTesting
  void handleCloudBridgeMessage(Map<String, dynamic> message) {
    _handleCloudBridgeMessage(message);
  }

  /// Update connection status helper
  void _updateConnectionStatus(bool isConnected, String? error) {
    _connectionStatus['cloud'] = ConnectionStatus(
      type: 'cloud',
      isConnected: isConnected,
      endpoint: _config.cloudProxyUrl,
      error: error,
      lastCheck: DateTime.now(),
      latency: 0,
    );
    _debouncedNotifyListeners();
  }

  /// Update connection status (public for testing)
  @visibleForTesting
  void updateConnectionStatus(bool isConnected, String? error) {
    _updateConnectionStatus(isConnected, error);
  }

  /// Generate a simple UUID v4
  String _generateUuid() {
    final random = Random();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));

    // Set version (4) and variant bits
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;

    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20, 32)}';
  }

  /// Generate UUID (public for testing)
  @visibleForTesting
  String generateUuid() {
    return _generateUuid();
  }

  /// Send message through bridge WebSocket
  void _sendBridgeMessage(Map<String, dynamic> message) {
    if (_cloudWebSocket != null &&
        _cloudWebSocket!.readyState == WebSocket.open) {
      try {
        final jsonMessage = json.encode(message);
        _cloudWebSocket!.add(jsonMessage);
        debugPrint(
          '🚇 [TunnelManager] Sent bridge message: ${message['type']}',
        );
      } catch (e) {
        debugPrint('🚇 [TunnelManager] Failed to send bridge message: $e');
      }
    } else {
      debugPrint(
        '🚇 [TunnelManager] Cannot send message - WebSocket not connected',
      );
    }
  }

  /// Handle incoming Ollama request from cloud
  Future<void> _handleOllamaRequest(Map<String, dynamic> message) async {
    final requestId = message['id'];
    final data = message['data'];

    debugPrint('🚇 [TunnelManager] Handling Ollama request: $requestId');

    try {
      // Extract request details
      final method = data['method'] ?? 'GET';
      final path = data['path'] ?? '/';
      final headers = Map<String, String>.from(data['headers'] ?? {});
      final body = data['body'];

      // Forward request to local Ollama
      final ollamaUrl = 'http://localhost:11434$path';
      final uri = Uri.parse(ollamaUrl);

      http.Response response;

      switch (method.toUpperCase()) {
        case 'GET':
          response = await _httpClient.get(uri, headers: headers);
          break;
        case 'POST':
          response = await _httpClient.post(uri, headers: headers, body: body);
          break;
        case 'PUT':
          response = await _httpClient.put(uri, headers: headers, body: body);
          break;
        case 'DELETE':
          response = await _httpClient.delete(uri, headers: headers);
          break;
        default:
          throw Exception('Unsupported HTTP method: $method');
      }

      // Send response back through bridge
      _sendBridgeMessage({
        'type': 'response',
        'id': requestId,
        'data': {
          'statusCode': response.statusCode,
          'headers': response.headers,
          'body': response.body,
        },
        'timestamp': DateTime.now().toIso8601String(),
      });

      debugPrint('🚇 [TunnelManager] Ollama request completed: $requestId');
    } catch (e) {
      debugPrint('🚇 [TunnelManager] Ollama request failed: $e');

      // Send error response
      _sendBridgeMessage({
        'type': 'response',
        'id': requestId,
        'data': {
          'statusCode': 500,
          'headers': {'content-type': 'application/json'},
          'body': json.encode({
            'error': 'Internal server error',
            'message': e.toString(),
          }),
        },
        'timestamp': DateTime.now().toIso8601String(),
      });
    }
  }

  /// Get authentication token from AuthService or fallback to secure storage
  Future<String?> _getAuthToken() async {
    // First try to get token from AuthService if available
    final authService = _authService;
    if (authService != null) {
      final token = authService.getAccessToken();
      if (token != null) {
        debugPrint('🚇 [TunnelManager] Using token from AuthService');
        return token;
      }
    }

    // Fallback to secure storage for backward compatibility
    final storedToken = await _secureStorage.read(key: _authTokenKey);
    if (storedToken != null) {
      debugPrint('🚇 [TunnelManager] Using token from secure storage');
      return storedToken;
    }

    debugPrint('🚇 [TunnelManager] No authentication token available');
    return null;
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

        if (type == 'cloud') {
          await _checkCloudHealth(status);
        }
        // Local Ollama health is now handled independently

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
    _debouncedNotifyListeners();
  }

  /// Local Ollama health is now handled independently by LocalOllamaConnectionService

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
    _statusSubscription?.cancel();
    _cloudWebSocket?.close();
    _httpClient.close();

    // Cloud streaming services cleanup (local Ollama handled separately)

    _isConnected = false;
    _connectionStatus.clear();

    _debouncedNotifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _notifyDebounceTimer?.cancel();
    _healthCheckTimer?.cancel();
    _statusSubscription?.cancel();
    _cloudWebSocket?.close();

    // Only close HTTP client if it was initialized
    try {
      _httpClient.close();
    } catch (e) {
      // HTTP client was not initialized, ignore
    }

    // Local Ollama streaming service is now handled separately
    super.dispose();
  }

  /// Force reconnection to all endpoints
  Future<void> reconnect() async {
    debugPrint('🚇 [TunnelManager] Forcing reconnection to all endpoints...');

    _connectionStatus.clear();
    await _initializeConnections();
  }

  /// Update tunnel configuration and reinitialize connections
  Future<void> updateConfiguration(TunnelConfig newConfig) async {
    debugPrint('🚇 [TunnelManager] Updating configuration...');

    _config = newConfig;

    // Clear existing connections
    _connectionStatus.clear();
    _cloudWebSocket?.close();
    _cloudWebSocket = null;

    // Reinitialize with new configuration
    await _initializeConnections();

    debugPrint('🚇 [TunnelManager] Configuration updated successfully');
  }

  /// Get cloud connection status (local Ollama handled separately)
  String? getBestConnection() {
    // Only handle cloud proxy connections now
    // Local Ollama connections are managed by LocalOllamaConnectionService
    final cloudStatus = _connectionStatus['cloud'];
    if (cloudStatus?.isConnected == true) {
      return 'cloud';
    }

    return null;
  }

  /// Get cloud connection status for system tray display
  /// Local Ollama status is now handled separately
  TrayConnectionStatus getTrayConnectionStatus() {
    final cloudConnected = _connectionStatus['cloud']?.isConnected ?? false;

    if (cloudConnected) {
      return TrayConnectionStatus.allConnected;
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
  final OllamaConnectionError? connectionError;
  final ConnectionRetryState? retryState;

  const ConnectionStatus({
    required this.type,
    required this.isConnected,
    required this.endpoint,
    this.version,
    this.models = const [],
    this.error,
    required this.lastCheck,
    this.latency = 0.0,
    this.connectionError,
    this.retryState,
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
    OllamaConnectionError? connectionError,
    ConnectionRetryState? retryState,
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
      connectionError: connectionError ?? this.connectionError,
      retryState: retryState ?? this.retryState,
    );
  }
}

/// Tunnel configuration (cloud proxy only)
///
/// Local Ollama connections are now handled independently
/// and are not part of tunnel management.
class TunnelConfig {
  final bool enableCloudProxy;
  final String cloudProxyUrl;
  final int connectionTimeout;
  final int healthCheckInterval;

  const TunnelConfig({
    required this.enableCloudProxy,
    required this.cloudProxyUrl,
    required this.connectionTimeout,
    required this.healthCheckInterval,
  });

  factory TunnelConfig.defaultConfig() {
    return const TunnelConfig(
      enableCloudProxy: true,
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
