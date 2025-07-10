import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
// import '../models/ollama_model.dart'; // Not needed for basic functionality
import 'local_ollama_streaming_service.dart';
import 'streaming_service.dart';

/// Independent local Ollama connection service
///
/// Handles direct connections to localhost:11434 without tunnel management.
/// This service operates completely independently of cloud connections.
///
/// Platform-aware: On web platform, this service becomes a no-op to prevent
/// CORS errors. Web platform should use cloud proxy tunnel instead.
class LocalOllamaConnectionService extends ChangeNotifier {
  final String _baseUrl;
  final Duration _timeout;

  // Connection state
  bool _isConnected = false;
  bool _isConnecting = false;
  String? _version;
  List<String> _models = [];
  String? _error;
  DateTime? _lastCheck;

  // HTTP client for direct connections
  late http.Client _httpClient;

  // Streaming service for local Ollama
  LocalOllamaStreamingService? _streamingService;

  // Health check timer
  Timer? _healthCheckTimer;

  LocalOllamaConnectionService({String? baseUrl, Duration? timeout})
    : _baseUrl = baseUrl ?? AppConfig.defaultOllamaUrl,
      _timeout = timeout ?? AppConfig.ollamaTimeout {
    _httpClient = http.Client();

    if (kIsWeb) {
      debugPrint(
        '🦙 [LocalOllama] Web platform detected - service will be disabled to prevent CORS errors',
      );
      debugPrint(
        '🦙 [LocalOllama] Web platform should use cloud proxy tunnel: ${AppConfig.cloudOllamaUrl}',
      );
    } else {
      debugPrint(
        '🦙 [LocalOllama] Desktop platform detected - service initialized for $_baseUrl',
      );
    }
  }

  // Getters
  bool get isConnected => _isConnected;
  bool get isConnecting => _isConnecting;
  String? get version => _version;
  List<String> get models => List.unmodifiable(_models);
  String? get error => _error;
  DateTime? get lastCheck => _lastCheck;
  LocalOllamaStreamingService? get streamingService => _streamingService;

  /// Initialize the local Ollama connection
  Future<void> initialize() async {
    if (kIsWeb) {
      debugPrint(
        '🦙 [LocalOllama] Skipping initialization on web platform to prevent CORS errors',
      );
      debugPrint(
        '🦙 [LocalOllama] Web platform will use cloud proxy tunnel instead',
      );
      // Set appropriate state for web platform
      _isConnected = false;
      _error = 'Local Ollama not available on web platform - use cloud proxy';
      notifyListeners();
      return;
    }

    debugPrint('🦙 [LocalOllama] Initializing local Ollama connection...');

    // Initialize streaming service
    _streamingService = LocalOllamaStreamingService(
      baseUrl: _baseUrl,
      config: StreamingConfig.local(),
    );

    // Test initial connection
    await testConnection();

    // Start health monitoring
    _startHealthChecks();

    debugPrint('🦙 [LocalOllama] Local Ollama service initialized');
  }

  /// Test connection to local Ollama
  Future<bool> testConnection() async {
    if (kIsWeb) {
      debugPrint(
        '🦙 [LocalOllama] Skipping connection test on web platform to prevent CORS errors',
      );
      _isConnected = false;
      _error = 'Local Ollama not available on web platform - use cloud proxy';
      notifyListeners();
      return false;
    }

    if (_isConnecting) return _isConnected;

    _isConnecting = true;
    _error = null;
    notifyListeners();

    try {
      debugPrint('🦙 [LocalOllama] Testing connection to $_baseUrl');

      final response = await _httpClient
          .get(
            Uri.parse('$_baseUrl/api/version'),
            headers: {'Accept': 'application/json'},
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _version = data['version'] as String?;
        _isConnected = true;
        _lastCheck = DateTime.now();

        debugPrint('🦙 [LocalOllama] Connected to Ollama v$_version');

        // Load available models
        await _loadModels();

        // Initialize streaming service connection
        if (_streamingService != null) {
          try {
            await _streamingService!.establishConnection();
          } catch (e) {
            debugPrint(
              '🦙 [LocalOllama] Streaming service connection failed: $e',
            );
            // Don't fail the entire connection if streaming fails
          }
        }

        return true;
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      _isConnected = false;
      _error = _getConnectionErrorMessage(e);
      _lastCheck = DateTime.now();

      debugPrint('🦙 [LocalOllama] Connection failed: $_error');
      return false;
    } finally {
      _isConnecting = false;
      notifyListeners();
    }
  }

  /// Load available models from local Ollama
  Future<void> _loadModels() async {
    if (kIsWeb) {
      debugPrint(
        '🦙 [LocalOllama] Skipping model loading on web platform to prevent CORS errors',
      );
      _models = [];
      return;
    }

    try {
      final response = await _httpClient
          .get(
            Uri.parse('$_baseUrl/api/tags'),
            headers: {'Accept': 'application/json'},
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final modelsList = data['models'] as List<dynamic>? ?? [];

        _models = modelsList.map((model) => model['name'] as String).toList();

        debugPrint('🦙 [LocalOllama] Found ${_models.length} models: $_models');
      }
    } catch (e) {
      debugPrint('🦙 [LocalOllama] Failed to load models: $e');
      _models = [];
    }
  }

  /// Send a chat message to local Ollama
  Future<String?> chat({
    required String model,
    required String message,
    List<Map<String, String>>? history,
  }) async {
    if (kIsWeb) {
      debugPrint(
        '🦙 [LocalOllama] Chat request blocked on web platform to prevent CORS errors',
      );
      throw StateError(
        'Local Ollama not available on web platform - use cloud proxy',
      );
    }

    if (!_isConnected) {
      throw StateError('Not connected to local Ollama');
    }

    try {
      final messages = [
        if (history != null) ...history,
        {'role': 'user', 'content': message},
      ];

      final response = await _httpClient
          .post(
            Uri.parse('$_baseUrl/api/chat'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: json.encode({
              'model': model,
              'messages': messages,
              'stream': false,
            }),
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['message']?['content'] as String?;
      } else {
        throw Exception('Chat failed: HTTP ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('🦙 [LocalOllama] Chat error: $e');
      rethrow;
    }
  }

  /// Start health check monitoring
  void _startHealthChecks() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _performHealthCheck(),
    );
  }

  /// Perform periodic health check
  Future<void> _performHealthCheck() async {
    if (kIsWeb) {
      // Skip health checks on web platform
      return;
    }

    if (_isConnecting) return;

    try {
      await testConnection();
    } catch (e) {
      debugPrint('🦙 [LocalOllama] Health check failed: $e');
    }
  }

  /// Get user-friendly error message
  String _getConnectionErrorMessage(dynamic error) {
    final errorStr = error.toString().toLowerCase();

    if (errorStr.contains('connection refused') ||
        errorStr.contains('failed to connect')) {
      return 'Ollama is not running. Please start Ollama and try again.';
    } else if (errorStr.contains('timeout')) {
      return 'Connection timeout. Ollama may be starting up.';
    } else if (errorStr.contains('network is unreachable')) {
      return 'Network error. Check your connection.';
    } else {
      return 'Connection failed: ${error.toString()}';
    }
  }

  /// Force reconnection
  Future<void> reconnect() async {
    if (kIsWeb) {
      debugPrint(
        '🦙 [LocalOllama] Skipping reconnection on web platform to prevent CORS errors',
      );
      return;
    }

    debugPrint('🦙 [LocalOllama] Forcing reconnection...');
    _isConnected = false;
    await testConnection();
  }

  @override
  void dispose() {
    debugPrint('🦙 [LocalOllama] Disposing service');
    _healthCheckTimer?.cancel();
    _streamingService?.closeConnection();
    _httpClient.close();
    super.dispose();
  }
}
