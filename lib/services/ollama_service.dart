import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import 'auth_service.dart';

/// Service for communicating with Ollama API via Cloud Relay
class OllamaService extends ChangeNotifier {
  final String _baseUrl;
  final Duration _timeout;
  final AuthService? _authService;

  bool _isConnected = false;
  String? _version;
  List<OllamaModel> _models = [];
  bool _isLoading = false;
  String? _error;
  BridgeStatus _bridgeStatus = BridgeStatus.disconnected;
  String? _bridgeError;

  OllamaService({
    String? baseUrl,
    Duration? timeout,
    AuthService? authService,
  })  : _baseUrl = baseUrl ?? AppConfig.defaultOllamaUrl,
        _timeout = timeout ?? AppConfig.ollamaTimeout,
        _authService = authService {
    // Debug logging for service initialization
    debugPrint('[DEBUG] OllamaService initialized:');
    debugPrint('[DEBUG] - Base URL: $_baseUrl');
    debugPrint('[DEBUG] - Timeout: $_timeout');
    debugPrint(
        '[DEBUG] - Auth Service: ${_authService != null ? 'provided' : 'null'}');
    AppConfig.logConfiguration();
  }

  // Getters
  bool get isConnected => _isConnected;
  String? get version => _version;
  List<OllamaModel> get models => _models;
  bool get isLoading => _isLoading;
  String? get error => _error;
  BridgeStatus get bridgeStatus => _bridgeStatus;
  String? get bridgeError => _bridgeError;

  /// Test connection to Ollama server via cloud relay
  Future<bool> testConnection() async {
    try {
      _setLoading(true);
      _clearError();

      // First check bridge status
      await _checkBridgeStatus();

      if (_bridgeStatus != BridgeStatus.connected) {
        _isConnected = false;
        return false;
      }

      final headers = await _getAuthHeaders();
      final url = '$_baseUrl/api/version';
      debugPrint('[DEBUG] Making request to: $url');
      debugPrint('[DEBUG] Headers: $headers');

      final response = await http
          .get(
            Uri.parse(url),
            headers: headers,
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _version = data['version'] as String?;
        _isConnected = true;
        debugPrint('Connected to Ollama v$_version via cloud relay');
        return true;
      } else if (response.statusCode == 401) {
        _setError('Authentication failed. Please log in again.');
        _isConnected = false;
        return false;
      } else if (response.statusCode == 503) {
        _setError(
            'Desktop bridge is not connected. Please start the bridge application.');
        _bridgeStatus = BridgeStatus.disconnected;
        _isConnected = false;
        return false;
      } else {
        _setError('Failed to connect: HTTP ${response.statusCode}');
        _isConnected = false;
        return false;
      }
    } catch (e) {
      _setError('Connection failed: $e');
      _isConnected = false;
      debugPrint('Ollama connection error: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Get list of available models via cloud relay
  Future<List<OllamaModel>> getModels() async {
    try {
      _setLoading(true);
      _clearError();

      // Check bridge status first
      await _checkBridgeStatus();
      if (_bridgeStatus != BridgeStatus.connected) {
        _setError('Desktop bridge is not connected');
        return [];
      }

      final headers = await _getAuthHeaders();
      final response = await http
          .get(
            Uri.parse('$_baseUrl/api/tags'),
            headers: headers,
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final modelsList = data['models'] as List<dynamic>? ?? [];

        _models =
            modelsList.map((model) => OllamaModel.fromJson(model)).toList();
        debugPrint('Found ${_models.length} Ollama models via cloud relay');
        return _models;
      } else if (response.statusCode == 401) {
        _setError('Authentication failed. Please log in again.');
        return [];
      } else if (response.statusCode == 503) {
        _setError(
            'Desktop bridge is not connected. Please start the bridge application.');
        _bridgeStatus = BridgeStatus.disconnected;
        return [];
      } else {
        _setError('Failed to get models: HTTP ${response.statusCode}');
        return [];
      }
    } catch (e) {
      _setError('Failed to get models: $e');
      debugPrint('Error getting Ollama models: $e');
      return [];
    } finally {
      _setLoading(false);
    }
  }

  /// Send a chat message to Ollama
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

      // Check bridge status first
      await _checkBridgeStatus();
      if (_bridgeStatus != BridgeStatus.connected) {
        _setError('Desktop bridge is not connected');
        return null;
      }

      final headers = await _getAuthHeaders();
      final response = await http
          .post(
            Uri.parse('$_baseUrl/api/chat'),
            headers: headers,
            body: json.encode({
              'model': model,
              'messages': messages,
              'stream': false,
            }),
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final responseMessage = data['message']?['content'] as String?;
        debugPrint('Chat response received via cloud relay');
        return responseMessage;
      } else if (response.statusCode == 401) {
        _setError('Authentication failed. Please log in again.');
        return null;
      } else if (response.statusCode == 503) {
        _setError(
            'Desktop bridge is not connected. Please start the bridge application.');
        _bridgeStatus = BridgeStatus.disconnected;
        return null;
      } else {
        _setError('Chat failed: HTTP ${response.statusCode}');
        return null;
      }
    } catch (e) {
      _setError('Chat failed: $e');
      debugPrint('Ollama chat error: $e');
      return null;
    } finally {
      _setLoading(false);
    }
  }

  /// Pull a model from Ollama registry
  Future<bool> pullModel(String modelName) async {
    try {
      _setLoading(true);
      _clearError();

      final response = await http
          .post(
            Uri.parse('$_baseUrl/api/pull'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'name': modelName}),
          )
          .timeout(const Duration(
              minutes: 10)); // Longer timeout for model downloads

      return response.statusCode == 200;
    } catch (e) {
      _setError('Failed to pull model: $e');
      debugPrint('Error pulling model: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
    notifyListeners();
  }

  /// Get authentication headers for API requests with JWT Bearer token
  Future<Map<String, String>> _getAuthHeaders() async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };

    if (_authService != null && _authService.isAuthenticated.value) {
      final token = _authService.getAccessToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
        debugPrint('Added Bearer token to request headers');
      } else {
        debugPrint(
            'Warning: User is authenticated but no access token available');
      }
    } else {
      debugPrint('Warning: User is not authenticated, request may fail');
    }

    return headers;
  }

  /// Check bridge connection status
  Future<void> _checkBridgeStatus() async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http
          .get(
            Uri.parse(AppConfig.bridgeStatusUrl),
            headers: headers,
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final isConnected = data['connected'] as bool? ?? false;
        final modelCount = data['modelCount'] as int? ?? 0;

        if (isConnected) {
          _bridgeStatus = BridgeStatus.connected;
          _bridgeError = null;
          debugPrint('Bridge connected with $modelCount models available');
        } else {
          _bridgeStatus = BridgeStatus.disconnected;
          _bridgeError = 'Desktop bridge is offline';
        }
      } else if (response.statusCode == 401) {
        _bridgeStatus = BridgeStatus.error;
        _bridgeError = 'Authentication failed';
      } else {
        _bridgeStatus = BridgeStatus.error;
        _bridgeError =
            'Bridge status check failed: HTTP ${response.statusCode}';
      }
    } catch (e) {
      _bridgeStatus = BridgeStatus.error;
      _bridgeError = 'Bridge status check failed: $e';
      debugPrint('Bridge status check error: $e');
    }

    notifyListeners();
  }
}

/// Model representing an Ollama model
class OllamaModel {
  final String name;
  final String? tag;
  final int? size;
  final DateTime? modifiedAt;

  const OllamaModel({
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

  String get displayName => tag != null ? '$name:$tag' : name;

  String get sizeFormatted {
    if (size == null) return 'Unknown size';
    final sizeInGB = size! / (1024 * 1024 * 1024);
    return '${sizeInGB.toStringAsFixed(1)} GB';
  }
}

/// Enum for bridge connection status
enum BridgeStatus {
  connected, // Bridge is online and Ollama is accessible
  disconnected, // Bridge is offline
  error, // Connection/authentication error
}
