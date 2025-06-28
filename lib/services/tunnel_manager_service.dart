import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage_x/flutter_secure_storage_x.dart';
import '../models/ollama_connection_error.dart';
import '../models/streaming_message.dart';
import 'streaming_service.dart';
import 'auth_service.dart';
import 'desktop_client_detection_service.dart';
import 'cloud_streaming_service.dart';
import 'ngrok_service.dart';
import 'ngrok_service_platform.dart';

/// Integrated tunnel manager service for CloudToLocalLLM v3.3.1+
///
/// Consolidates tunnel management functionality from the separate tunnel_manager app
/// into the main application for unified architecture.
class TunnelManagerService extends ChangeNotifier {
  static const String _authTokenKey = 'cloudtolocalllm_auth_token';

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final AuthService? _authService;
  final DesktopClientDetectionService? _clientDetectionService;

  // Constructor
  TunnelManagerService({
    AuthService? authService,
    DesktopClientDetectionService? clientDetectionService,
  }) : _authService = authService,
       _clientDetectionService = clientDetectionService;

  // Connection state
  bool _isConnected = false;
  bool _isConnecting = false;
  String? _error;

  // Enhanced connection state for wizard integration
  bool _isWizardMode = false;
  String? _wizardStepError;
  Map<String, dynamic>? _lastConnectionTest;

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
  CloudStreamingService? _cloudStreamingService;

  // Ngrok service for desktop tunneling
  NgrokServicePlatform? _ngrokService;

  // Desktop client detection listener (web platform only)
  StreamSubscription<void>? _clientDetectionSubscription;

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
  CloudStreamingService? get cloudStreamingService => _cloudStreamingService;

  /// Get ngrok service (desktop platform only)
  NgrokServicePlatform? get ngrokService => _ngrokService;

  /// Whether ngrok tunnel is active
  bool get hasNgrokTunnel => _ngrokService?.activeTunnel != null;

  /// Get ngrok tunnel URL if active
  String? get ngrokTunnelUrl => _ngrokService?.activeTunnel?.publicUrl;

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
    debugPrint('🚇 [TunnelManager] Platform: ${kIsWeb ? "Web" : "Desktop"}');

    // Load configuration
    await _loadConfiguration();

    // Initialize streaming services
    await _initializeStreamingServices();

    // Platform-specific initialization
    if (kIsWeb) {
      // Web platform: Act as bridge server, not tunnel client
      debugPrint(
        '🚇 [TunnelManager] Web platform detected - acting as bridge server',
      );
      await _initializeWebBridgeServer();

      // Listen for desktop client connection changes on web platform
      _setupDesktopClientListener();
    } else {
      // Desktop platform: Act as tunnel client
      debugPrint(
        '🚇 [TunnelManager] Desktop platform detected - acting as tunnel client',
      );

      // Initialize ngrok service for desktop platform
      await _initializeNgrokService();

      await _initializeConnections();
    }

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

      // Initialize cloud streaming service if auth service is available
      if (_authService != null) {
        _cloudStreamingService = CloudStreamingService(
          authService: _authService,
        );
        debugPrint('🚇 [TunnelManager] Cloud streaming service initialized');
      } else {
        debugPrint(
          '🚇 [TunnelManager] No auth service available for cloud streaming',
        );
      }

      debugPrint(
        '🚇 [TunnelManager] Cloud streaming services initialized successfully',
      );
    } catch (e) {
      debugPrint(
        '🚇 [TunnelManager] Failed to initialize cloud streaming services: $e',
      );
    }
  }

  /// Initialize ngrok service for desktop platform
  Future<void> _initializeNgrokService() async {
    try {
      debugPrint('🚇 [TunnelManager] Initializing ngrok service...');

      _ngrokService = NgrokServicePlatform(authService: _authService);
      await _ngrokService!.initialize();

      // Listen to ngrok service changes
      _ngrokService!.addListener(() {
        _debouncedNotifyListeners();
      });

      // Start ngrok tunnel if enabled in configuration
      if (_config.enableNgrok) {
        debugPrint('🚇 [TunnelManager] Starting ngrok tunnel...');
        await _ngrokService!.startTunnel(_config.toNgrokConfig());
      }

      debugPrint('🚇 [TunnelManager] Ngrok service initialized successfully');
    } catch (e) {
      debugPrint('🚇 [TunnelManager] Failed to initialize ngrok service: $e');
      // Don't fail the entire initialization if ngrok fails
    }
  }

  /// Initialize web platform as bridge server
  /// Web platform doesn't connect as tunnel client - it IS the bridge server
  /// Connection status depends on whether desktop clients are connected
  Future<void> _initializeWebBridgeServer() async {
    try {
      debugPrint('🚇 [TunnelManager] Initializing web bridge server...');

      // Check if desktop clients are connected to determine status
      await _updateWebBridgeStatus();

      debugPrint(
        '🚇 [TunnelManager] Web bridge server initialized successfully',
      );
      _updateOverallStatus();
    } catch (e) {
      _error = 'Failed to initialize web bridge server: $e';
      debugPrint(
        '🚇 [TunnelManager] Web bridge server initialization error: $e',
      );
    }
  }

  /// Update web bridge status based on desktop client connections
  Future<void> _updateWebBridgeStatus() async {
    if (!kIsWeb) return;

    bool hasConnectedClients = false;
    String? errorMessage;

    // Check if we have the client detection service and clients are connected
    if (_clientDetectionService != null) {
      hasConnectedClients = _clientDetectionService.hasConnectedClients;
      if (!hasConnectedClients) {
        errorMessage = 'Waiting for desktop client connection';
      }
    } else {
      errorMessage = 'Desktop client detection service not available';
    }

    _connectionStatus['cloud'] = ConnectionStatus(
      type: 'cloud',
      isConnected: hasConnectedClients,
      endpoint: _config.cloudProxyUrl,
      version: 'Bridge Server',
      lastCheck: DateTime.now(),
      latency: 0,
      error: errorMessage,
    );

    final statusMessage = hasConnectedClients
        ? 'Bridge Server (${_clientDetectionService?.connectedClientCount ?? 0} client${(_clientDetectionService?.connectedClientCount ?? 0) == 1 ? '' : 's'} connected)'
        : errorMessage ?? 'Waiting for desktop client connection';

    debugPrint(
      '🚇 [TunnelManager] Web bridge status updated: $statusMessage (connected: $hasConnectedClients)',
    );
  }

  /// Setup listener for desktop client connection changes (web platform only)
  void _setupDesktopClientListener() {
    if (!kIsWeb || _clientDetectionService == null) return;

    debugPrint(
      '🚇 [TunnelManager] Setting up desktop client detection listener...',
    );

    // Listen for changes in desktop client connections
    _clientDetectionSubscription =
        Stream.periodic(const Duration(seconds: 5), (_) => null).listen((
          _,
        ) async {
          await _updateWebBridgeStatus();
          _updateOverallStatus();
          _debouncedNotifyListeners();
        });

    // Also listen to the client detection service directly
    _clientDetectionService.addListener(() async {
      await _updateWebBridgeStatus();
      _updateOverallStatus();
      _debouncedNotifyListeners();
    });

    debugPrint(
      '🚇 [TunnelManager] Desktop client detection listener setup complete',
    );
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
          // Handle cloud proxy streaming events
          _handleCloudProxyStreamingEvent(event);
          debugPrint('🚇 [TunnelManager] Cloud proxy event: ${event.state}');
        }
      },
      onError: (error) {
        debugPrint('🚇 [TunnelManager] Status event listener error: $error');
      },
    );
  }

  /// Handle cloud proxy streaming events
  void _handleCloudProxyStreamingEvent(ConnectionStatusEvent event) {
    debugPrint(
      '🚇 [TunnelManager] Handling cloud proxy streaming event: ${event.state}',
    );

    // Update cloud streaming service connection status based on event
    if (_cloudStreamingService != null) {
      switch (event.state) {
        case StreamingConnectionState.connected:
          // Cloud proxy is connected, streaming service can be used
          debugPrint(
            '🚇 [TunnelManager] Cloud proxy connected - streaming available',
          );
          break;
        case StreamingConnectionState.disconnected:
          // Cloud proxy disconnected, close streaming service connection
          debugPrint(
            '🚇 [TunnelManager] Cloud proxy disconnected - closing streaming',
          );
          _cloudStreamingService!.closeConnection().catchError((e) {
            debugPrint('🚇 [TunnelManager] Error closing cloud streaming: $e');
          });
          break;
        case StreamingConnectionState.error:
          // Cloud proxy error, handle streaming service error
          debugPrint('🚇 [TunnelManager] Cloud proxy error: ${event.error}');
          break;
        case StreamingConnectionState.connecting:
          // Cloud proxy connecting
          debugPrint('🚇 [TunnelManager] Cloud proxy connecting...');
          break;
        case StreamingConnectionState.streaming:
          // Cloud proxy streaming
          debugPrint('🚇 [TunnelManager] Cloud proxy streaming...');
          break;
        case StreamingConnectionState.reconnecting:
          // Cloud proxy reconnecting
          debugPrint('🚇 [TunnelManager] Cloud proxy reconnecting...');
          break;
      }
    }

    // Update connection status
    _updateOverallStatus();
    _debouncedNotifyListeners();
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

        // Only establish WebSocket connection on desktop platform
        // Web platform IS the bridge server, so no client connection needed
        if (!kIsWeb) {
          await _establishCloudWebSocket(authToken);
        } else {
          debugPrint(
            '🚇 [TunnelManager] Skipping WebSocket connection on web platform (bridge server)',
          );
        }
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
  /// Only for desktop platform - web platform IS the bridge server
  Future<void> _establishCloudWebSocket(String authToken) async {
    // Safety check: Web platform should never attempt WebSocket client connections
    if (kIsWeb) {
      debugPrint(
        '🚇 [TunnelManager] Skipping WebSocket connection - web platform is bridge server',
      );
      return;
    }

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
  /// Only desktop platform should handle these - web platform doesn't have local Ollama
  Future<void> _handleOllamaRequest(Map<String, dynamic> message) async {
    final requestId = message['id'];

    // Safety check: Web platform should never handle Ollama requests
    if (kIsWeb) {
      debugPrint(
        '🚇 [TunnelManager] Ignoring Ollama request on web platform: $requestId',
      );
      return;
    }

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
    // Update ngrok connection status if available
    _updateNgrokConnectionStatus();

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

  /// Update ngrok connection status
  void _updateNgrokConnectionStatus() {
    if (_ngrokService == null || !_ngrokService!.isSupported) {
      return;
    }

    final tunnel = _ngrokService!.activeTunnel;
    final isRunning = _ngrokService!.isRunning;
    final lastError = _ngrokService!.lastError;

    _connectionStatus['ngrok'] = ConnectionStatus(
      type: 'ngrok',
      isConnected: isRunning && tunnel != null,
      endpoint: tunnel?.publicUrl ?? 'Not available',
      version: tunnel != null ? 'Active' : 'Inactive',
      lastCheck: DateTime.now(),
      latency: 0, // Ngrok latency is not directly measurable
      error: lastError,
    );
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
        } else if (type == 'ngrok') {
          await _checkNgrokHealth(status);
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

  /// Check ngrok tunnel health
  Future<void> _checkNgrokHealth(ConnectionStatus status) async {
    if (_ngrokService == null) {
      throw Exception('Ngrok service not available');
    }

    try {
      final tunnelStatus = await _ngrokService!.getTunnelStatus();

      if (!_ngrokService!.isRunning) {
        throw Exception('Ngrok tunnel is not running');
      }

      if (_ngrokService!.activeTunnel == null) {
        throw Exception('No active ngrok tunnel');
      }

      // Verify tunnel status indicates it's supported and running
      if (tunnelStatus['supported'] != true) {
        throw Exception('Ngrok not supported on this platform');
      }

      // Additional health check could include testing the tunnel URL
      // For now, we just verify the service is running and has an active tunnel
    } catch (e) {
      throw Exception('Ngrok health check failed: $e');
    }
  }

  /// Graceful shutdown
  Future<void> shutdown() async {
    debugPrint('🚇 [TunnelManager] Shutting down tunnel manager service...');

    _healthCheckTimer?.cancel();
    _statusSubscription?.cancel();
    _cloudWebSocket?.close();
    _httpClient.close();

    // Ngrok service cleanup
    if (_ngrokService != null) {
      await _ngrokService!.stopTunnel();
      _ngrokService!.dispose();
    }

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
    _clientDetectionSubscription?.cancel();
    _cloudWebSocket?.close();

    // Ngrok service cleanup
    _ngrokService?.dispose();

    // Only close HTTP client if it was initialized
    try {
      _httpClient.close();
    } catch (e) {
      // HTTP client was not initialized, ignore
    }

    // Dispose cloud streaming service
    _cloudStreamingService?.dispose();

    // Local Ollama streaming service is now handled separately
    super.dispose();
  }

  /// Force reconnection to all endpoints
  Future<void> reconnect() async {
    debugPrint('🚇 [TunnelManager] Forcing reconnection to all endpoints...');

    _connectionStatus.clear();

    // Platform-specific reconnection
    if (kIsWeb) {
      await _initializeWebBridgeServer();
    } else {
      await _initializeConnections();
    }
  }

  /// Update tunnel configuration and reinitialize connections
  Future<void> updateConfiguration(TunnelConfig newConfig) async {
    debugPrint('🚇 [TunnelManager] Updating configuration...');

    _config = newConfig;

    // Clear existing connections
    _connectionStatus.clear();
    _cloudWebSocket?.close();
    _cloudWebSocket = null;

    // Update ngrok configuration if service is available
    if (_ngrokService != null && !kIsWeb) {
      await _ngrokService!.updateConfiguration(newConfig.toNgrokConfig());
    }

    // Platform-specific reinitialization
    if (kIsWeb) {
      await _initializeWebBridgeServer();
    } else {
      await _initializeConnections();
    }

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

  // Enhanced methods for wizard integration

  /// Enable wizard mode for enhanced status reporting
  void enableWizardMode() {
    _isWizardMode = true;
    _wizardStepError = null;
    _lastConnectionTest = null;
    _debouncedNotifyListeners();
  }

  /// Disable wizard mode
  void disableWizardMode() {
    _isWizardMode = false;
    _wizardStepError = null;
    _lastConnectionTest = null;
    _debouncedNotifyListeners();
  }

  /// Get wizard-specific status information
  Map<String, dynamic> getWizardStatus() {
    return {
      'isWizardMode': _isWizardMode,
      'isConnecting': _isConnecting,
      'isConnected': _isConnected,
      'error': _error,
      'wizardStepError': _wizardStepError,
      'lastConnectionTest': _lastConnectionTest,
      'connectionStatus': _connectionStatus,
    };
  }

  /// Test connection with detailed reporting for wizard
  Future<Map<String, dynamic>> testConnectionForWizard(
    TunnelConfig testConfig,
  ) async {
    _isWizardMode = true;
    _wizardStepError = null;

    final steps = <Map<String, dynamic>>[];
    final testResult = <String, dynamic>{
      'success': false,
      'timestamp': DateTime.now().toIso8601String(),
      'config': {
        'cloudProxyUrl': testConfig.cloudProxyUrl,
        'enableCloudProxy': testConfig.enableCloudProxy,
        'connectionTimeout': testConfig.connectionTimeout,
      },
      'steps': steps,
      'error': null,
      'serverInfo': null,
    };

    try {
      _isConnecting = true;
      _debouncedNotifyListeners();

      // Step 1: Test HTTP connectivity
      steps.add({
        'name': 'HTTP Connectivity',
        'status': 'testing',
        'timestamp': DateTime.now().toIso8601String(),
      });

      final authToken = await _getAuthToken();
      if (authToken == null) {
        throw Exception('No authentication token available');
      }

      final response = await _httpClient
          .get(
            Uri.parse('${testConfig.cloudProxyUrl}/api/health'),
            headers: {'Authorization': 'Bearer $authToken'},
          )
          .timeout(Duration(seconds: testConfig.connectionTimeout));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        testResult['serverInfo'] = data;

        steps.last['status'] = 'success';
        steps.last['result'] = 'Server responded successfully';

        // Step 2: Test WebSocket connectivity (desktop only)
        if (!kIsWeb) {
          steps.add({
            'name': 'WebSocket Connectivity',
            'status': 'testing',
            'timestamp': DateTime.now().toIso8601String(),
          });

          try {
            final wsUrl =
                '${testConfig.cloudProxyUrl.replaceFirst('https://', 'wss://')}/ws/bridge';
            final testWebSocket = await WebSocket.connect(
              wsUrl,
            ).timeout(Duration(seconds: testConfig.connectionTimeout));

            await testWebSocket.close();

            steps.last['status'] = 'success';
            steps.last['result'] = 'WebSocket connection successful';
          } catch (e) {
            steps.last['status'] = 'failed';
            steps.last['error'] = e.toString();
            throw Exception('WebSocket test failed: $e');
          }
        }

        testResult['success'] = true;
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      testResult['error'] = e.toString();
      _wizardStepError = e.toString();

      // Mark current step as failed
      if (steps.isNotEmpty) {
        steps.last['status'] = 'failed';
        steps.last['error'] = e.toString();
      }
    } finally {
      _isConnecting = false;
      _lastConnectionTest = testResult;
      _debouncedNotifyListeners();
    }

    return testResult;
  }

  /// Get detailed connection diagnostics for troubleshooting
  Map<String, dynamic> getConnectionDiagnostics() {
    final diagnostics = <String, dynamic>{
      'timestamp': DateTime.now().toIso8601String(),
      'platform': kIsWeb ? 'web' : 'desktop',
      'config': {
        'enableCloudProxy': _config.enableCloudProxy,
        'cloudProxyUrl': _config.cloudProxyUrl,
        'connectionTimeout': _config.connectionTimeout,
        'healthCheckInterval': _config.healthCheckInterval,
      },
      'connectionStatus': {},
      'lastErrors': [],
      'networkInfo': {},
    };

    // Add connection status details
    for (final entry in _connectionStatus.entries) {
      final status = entry.value;
      diagnostics['connectionStatus'][entry.key] = {
        'isConnected': status.isConnected,
        'endpoint': status.endpoint,
        'version': status.version,
        'error': status.error,
        'lastCheck': status.lastCheck.toIso8601String(),
        'latency': status.latency,
      };
    }

    // Add recent errors
    final recentErrors = _connectionStatus.values
        .where((status) => status.error != null)
        .map(
          (status) => {
            'type': status.type,
            'error': status.error,
            'timestamp': status.lastCheck.toIso8601String(),
          },
        )
        .toList();
    diagnostics['lastErrors'] = recentErrors;

    return diagnostics;
  }

  /// Validate end-to-end tunnel functionality
  Future<Map<String, dynamic>> validateTunnelEndToEnd() async {
    final validationResult = <String, dynamic>{
      'success': false,
      'timestamp': DateTime.now().toIso8601String(),
      'tests': <Map<String, dynamic>>[],
      'error': null,
      'summary': {},
    };

    final tests = <Map<String, dynamic>>[];
    validationResult['tests'] = tests;

    try {
      // Test 1: Authentication validation
      tests.add({
        'name': 'Authentication Validation',
        'status': 'testing',
        'timestamp': DateTime.now().toIso8601String(),
      });

      final authToken = await _getAuthToken();
      if (authToken == null) {
        tests.last['status'] = 'failed';
        tests.last['error'] = 'No authentication token available';
        throw Exception('Authentication validation failed');
      }

      tests.last['status'] = 'success';
      tests.last['result'] = 'Authentication token validated';

      // Test 2: Server connectivity
      tests.add({
        'name': 'Server Connectivity',
        'status': 'testing',
        'timestamp': DateTime.now().toIso8601String(),
      });

      final healthResponse = await _httpClient
          .get(
            Uri.parse('${_config.cloudProxyUrl}/api/health'),
            headers: {'Authorization': 'Bearer $authToken'},
          )
          .timeout(Duration(seconds: _config.connectionTimeout));

      if (healthResponse.statusCode != 200) {
        tests.last['status'] = 'failed';
        tests.last['error'] =
            'HTTP ${healthResponse.statusCode}: ${healthResponse.body}';
        throw Exception('Server connectivity test failed');
      }

      final healthData = json.decode(healthResponse.body);
      tests.last['status'] = 'success';
      tests.last['result'] = 'Server health check passed';
      tests.last['serverInfo'] = healthData;

      // Test 3: WebSocket bridge connectivity (desktop only)
      if (!kIsWeb) {
        tests.add({
          'name': 'WebSocket Bridge',
          'status': 'testing',
          'timestamp': DateTime.now().toIso8601String(),
        });

        try {
          final wsUrl =
              '${_config.cloudProxyUrl.replaceFirst('https://', 'wss://')}/ws/bridge';
          final testWebSocket = await WebSocket.connect(
            wsUrl,
          ).timeout(Duration(seconds: _config.connectionTimeout));

          // Send a test message
          final testMessage = {
            'type': 'ping',
            'id': _generateUuid(),
            'timestamp': DateTime.now().toIso8601String(),
          };

          testWebSocket.add(json.encode(testMessage));

          // Wait for response
          bool receivedResponse = false;
          final responseCompleter = Completer<void>();

          testWebSocket.listen(
            (data) {
              try {
                final response = json.decode(data);
                if (response['type'] == 'pong') {
                  receivedResponse = true;
                  responseCompleter.complete();
                }
              } catch (e) {
                // Ignore parsing errors
              }
            },
            onError: (error) {
              if (!responseCompleter.isCompleted) {
                responseCompleter.completeError(error);
              }
            },
          );

          await responseCompleter.future.timeout(const Duration(seconds: 5));
          await testWebSocket.close();

          if (receivedResponse) {
            tests.last['status'] = 'success';
            tests.last['result'] = 'WebSocket bridge communication successful';
          } else {
            tests.last['status'] = 'failed';
            tests.last['error'] = 'No response received from bridge';
            throw Exception('WebSocket bridge test failed');
          }
        } catch (e) {
          tests.last['status'] = 'failed';
          tests.last['error'] = e.toString();
          throw Exception('WebSocket bridge test failed: $e');
        }
      }

      // Test 4: Ollama proxy test (if available)
      tests.add({
        'name': 'Ollama Proxy Test',
        'status': 'testing',
        'timestamp': DateTime.now().toIso8601String(),
      });

      try {
        final ollamaResponse = await _httpClient
            .get(
              Uri.parse('${_config.cloudProxyUrl}/api/ollama/api/tags'),
              headers: {'Authorization': 'Bearer $authToken'},
            )
            .timeout(Duration(seconds: _config.connectionTimeout));

        if (ollamaResponse.statusCode == 200) {
          final ollamaData = json.decode(ollamaResponse.body);
          tests.last['status'] = 'success';
          tests.last['result'] = 'Ollama proxy connection successful';
          tests.last['models'] = ollamaData['models'] ?? [];
        } else {
          tests.last['status'] = 'warning';
          tests.last['result'] =
              'Ollama proxy not available (this is normal if Ollama is not running)';
        }
      } catch (e) {
        tests.last['status'] = 'warning';
        tests.last['result'] =
            'Ollama proxy test skipped (Ollama may not be running)';
      }

      // All critical tests passed
      validationResult['success'] = true;
      validationResult['summary'] = {
        'totalTests': tests.length,
        'passedTests': tests
            .where((test) => test['status'] == 'success')
            .length,
        'failedTests': tests.where((test) => test['status'] == 'failed').length,
        'warningTests': tests
            .where((test) => test['status'] == 'warning')
            .length,
      };
    } catch (e) {
      validationResult['error'] = e.toString();
      validationResult['summary'] = {
        'totalTests': tests.length,
        'passedTests': tests
            .where((test) => test['status'] == 'success')
            .length,
        'failedTests': tests.where((test) => test['status'] == 'failed').length,
        'warningTests': tests
            .where((test) => test['status'] == 'warning')
            .length,
      };
    }

    return validationResult;
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

/// Tunnel configuration (cloud proxy and ngrok)
///
/// Local Ollama connections are now handled independently
/// and are not part of tunnel management.
class TunnelConfig {
  final bool enableCloudProxy;
  final String cloudProxyUrl;
  final int connectionTimeout;
  final int healthCheckInterval;

  // Ngrok configuration
  final bool enableNgrok;
  final String? ngrokAuthToken;
  final String? ngrokSubdomain;
  final String ngrokProtocol;
  final int ngrokLocalPort;
  final String ngrokLocalHost;

  const TunnelConfig({
    required this.enableCloudProxy,
    required this.cloudProxyUrl,
    required this.connectionTimeout,
    required this.healthCheckInterval,
    this.enableNgrok = false,
    this.ngrokAuthToken,
    this.ngrokSubdomain,
    this.ngrokProtocol = 'http',
    this.ngrokLocalPort = 11434,
    this.ngrokLocalHost = 'localhost',
  });

  factory TunnelConfig.defaultConfig() {
    return const TunnelConfig(
      enableCloudProxy: true,
      cloudProxyUrl: 'https://app.cloudtolocalllm.online',
      connectionTimeout: 10,
      healthCheckInterval: 30,
      enableNgrok: false,
      ngrokProtocol: 'http',
      ngrokLocalPort: 11434,
      ngrokLocalHost: 'localhost',
    );
  }

  /// Create a copy with updated values
  TunnelConfig copyWith({
    bool? enableCloudProxy,
    String? cloudProxyUrl,
    int? connectionTimeout,
    int? healthCheckInterval,
    bool? enableNgrok,
    String? ngrokAuthToken,
    String? ngrokSubdomain,
    String? ngrokProtocol,
    int? ngrokLocalPort,
    String? ngrokLocalHost,
  }) {
    return TunnelConfig(
      enableCloudProxy: enableCloudProxy ?? this.enableCloudProxy,
      cloudProxyUrl: cloudProxyUrl ?? this.cloudProxyUrl,
      connectionTimeout: connectionTimeout ?? this.connectionTimeout,
      healthCheckInterval: healthCheckInterval ?? this.healthCheckInterval,
      enableNgrok: enableNgrok ?? this.enableNgrok,
      ngrokAuthToken: ngrokAuthToken ?? this.ngrokAuthToken,
      ngrokSubdomain: ngrokSubdomain ?? this.ngrokSubdomain,
      ngrokProtocol: ngrokProtocol ?? this.ngrokProtocol,
      ngrokLocalPort: ngrokLocalPort ?? this.ngrokLocalPort,
      ngrokLocalHost: ngrokLocalHost ?? this.ngrokLocalHost,
    );
  }

  /// Convert to NgrokConfig for the ngrok service
  NgrokConfig toNgrokConfig() {
    return NgrokConfig(
      enabled: enableNgrok,
      authToken: ngrokAuthToken,
      subdomain: ngrokSubdomain,
      protocol: ngrokProtocol,
      localPort: ngrokLocalPort,
      localHost: ngrokLocalHost,
    );
  }

  @override
  String toString() {
    return 'TunnelConfig('
        'enableCloudProxy: $enableCloudProxy, '
        'cloudProxyUrl: $cloudProxyUrl, '
        'enableNgrok: $enableNgrok, '
        'ngrokProtocol: $ngrokProtocol, '
        'ngrokLocalPort: $ngrokLocalPort'
        ')';
  }
}

/// System tray connection status
enum TrayConnectionStatus {
  disconnected,
  connecting,
  partiallyConnected,
  allConnected,
}
