import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/tunnel_config.dart';
import '../models/connection_status.dart';
import '../models/tunnel_metrics.dart';

class TunnelService extends ChangeNotifier {
  static const String _authTokenKey = 'cloudtolocalllm_auth_token';

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  // Connection state
  bool _isConnected = false;
  bool _isConnecting = false;
  String? _error;
  TunnelConfig? _config;

  // Connection status for different endpoints
  final Map<String, ConnectionStatus> _connectionStatus = {};

  // Metrics collection
  final TunnelMetrics _metrics = TunnelMetrics();

  // HTTP client for connections
  late http.Client _httpClient;

  // Timers for health checks and metrics
  Timer? _healthCheckTimer;
  Timer? _metricsTimer;

  // WebSocket connections for real-time updates
  WebSocket? _cloudWebSocket;

  // Getters
  bool get isConnected => _isConnected;
  bool get isConnecting => _isConnecting;
  String? get error => _error;
  TunnelConfig? get config => _config;
  Map<String, ConnectionStatus> get connectionStatus =>
      Map.unmodifiable(_connectionStatus);
  TunnelMetrics get metrics => _metrics;

  /// Initialize the tunnel service with configuration
  Future<void> initialize(TunnelConfig config) async {
    _config = config;
    _httpClient = http.Client();

    debugPrint('Initializing Tunnel Service with config: ${config.toJson()}');

    // Start initial connection attempts
    await _initializeConnections();

    // Start health monitoring
    _startHealthChecks();

    // Start metrics collection
    _startMetricsCollection();

    notifyListeners();
  }

  /// Initialize all configured connections
  Future<void> _initializeConnections() async {
    _isConnecting = true;
    _error = null;
    notifyListeners();

    try {
      // Initialize local Ollama connection
      if (_config!.enableLocalOllama) {
        await _initializeOllamaConnection();
      }

      // Initialize cloud proxy connection
      if (_config!.enableCloudProxy) {
        await _initializeCloudConnection();
      }

      // Update overall connection status
      _updateOverallStatus();
    } catch (e) {
      _error = 'Failed to initialize connections: $e';
      debugPrint('Connection initialization error: $e');
    } finally {
      _isConnecting = false;
      notifyListeners();
    }
  }

  /// Initialize local Ollama connection
  Future<void> _initializeOllamaConnection() async {
    final ollamaUrl = 'http://${_config!.ollamaHost}:${_config!.ollamaPort}';

    try {
      debugPrint('Testing Ollama connection to $ollamaUrl');

      final response = await _httpClient
          .get(
            Uri.parse('$ollamaUrl/api/version'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(Duration(seconds: _config!.connectionTimeout));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final version = data['version'] ?? 'Unknown';

        // Get available models
        final modelsResponse = await _httpClient
            .get(
              Uri.parse('$ollamaUrl/api/tags'),
              headers: {'Content-Type': 'application/json'},
            )
            .timeout(Duration(seconds: _config!.connectionTimeout));

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
          latency: 0, // Will be updated by health checks
        );

        debugPrint(
          'Ollama connection successful: $version, ${models.length} models',
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
      debugPrint('Ollama connection failed: $e');
    }
  }

  /// Initialize cloud proxy connection
  Future<void> _initializeCloudConnection() async {
    try {
      debugPrint('Testing cloud proxy connection to ${_config!.cloudProxyUrl}');

      // Get authentication token
      final authToken = await _getAuthToken();
      if (authToken == null) {
        throw Exception('No authentication token available');
      }

      final response = await _httpClient
          .get(
            Uri.parse('${_config!.cloudProxyUrl}/api/health'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $authToken',
            },
          )
          .timeout(Duration(seconds: _config!.connectionTimeout));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final version = data['version'] ?? 'Unknown';

        _connectionStatus['cloud'] = ConnectionStatus(
          type: 'cloud',
          isConnected: true,
          endpoint: _config!.cloudProxyUrl,
          version: version,
          lastCheck: DateTime.now(),
          latency: 0, // Will be updated by health checks
        );

        debugPrint('Cloud proxy connection successful: $version');

        // Establish WebSocket connection for real-time updates
        await _establishCloudWebSocket(authToken);
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      _connectionStatus['cloud'] = ConnectionStatus(
        type: 'cloud',
        isConnected: false,
        endpoint: _config!.cloudProxyUrl,
        error: e.toString(),
        lastCheck: DateTime.now(),
      );
      debugPrint('Cloud proxy connection failed: $e');
    }
  }

  /// Establish WebSocket connection to cloud proxy
  Future<void> _establishCloudWebSocket(String authToken) async {
    try {
      final wsUrl = '${_config!.cloudProxyUrl.replaceFirst('http', 'ws')}/ws';
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
            debugPrint('Error parsing WebSocket message: $e');
          }
        },
        onError: (error) {
          debugPrint('Cloud WebSocket error: $error');
          _cloudWebSocket = null;
        },
        onDone: () {
          debugPrint('Cloud WebSocket connection closed');
          _cloudWebSocket = null;
        },
      );

      debugPrint('Cloud WebSocket connection established');
    } catch (e) {
      debugPrint('Failed to establish cloud WebSocket: $e');
    }
  }

  /// Handle incoming WebSocket messages from cloud proxy
  void _handleCloudWebSocketMessage(Map<String, dynamic> message) {
    final type = message['type'];

    switch (type) {
      case 'status_update':
        // Update cloud connection status
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
        // Update available models from cloud
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
        debugPrint('Unknown WebSocket message type: $type');
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
      Duration(seconds: _config!.healthCheckInterval),
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

        // Update metrics
        _metrics.recordLatency(type, stopwatch.elapsedMilliseconds.toDouble());
      } catch (e) {
        // Mark connection as failed
        _connectionStatus[type] = status.copyWith(
          isConnected: false,
          error: e.toString(),
          lastCheck: DateTime.now(),
        );

        debugPrint('Health check failed for $type: $e');
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

  /// Start metrics collection
  void _startMetricsCollection() {
    _metricsTimer?.cancel();
    _metricsTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _collectMetrics(),
    );
  }

  /// Collect performance metrics
  void _collectMetrics() {
    // Update connection counts
    final connectedCount = _connectionStatus.values
        .where((s) => s.isConnected)
        .length;
    final totalCount = _connectionStatus.length;

    _metrics.updateConnectionCounts(connectedCount, totalCount);

    // Calculate uptime percentage
    final now = DateTime.now();
    final uptimePercentage = _metrics.calculateUptimePercentage(now);

    debugPrint(
      'Metrics: $connectedCount/$totalCount connections, ${uptimePercentage.toStringAsFixed(1)}% uptime',
    );
  }

  /// Graceful shutdown
  Future<void> shutdown() async {
    debugPrint('Shutting down Tunnel Service...');

    _healthCheckTimer?.cancel();
    _metricsTimer?.cancel();

    _cloudWebSocket?.close();
    _httpClient.close();

    _isConnected = false;
    _connectionStatus.clear();

    notifyListeners();
  }

  /// Force reconnection to all endpoints
  Future<void> reconnect() async {
    debugPrint('Forcing reconnection to all endpoints...');

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
}
