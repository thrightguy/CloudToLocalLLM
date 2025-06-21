import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import 'auth_service.dart';

/// Service for communicating with Ollama API
/// - Web: Uses cloud relay through API backend with authentication
/// - Desktop: Direct connection to localhost Ollama
class OllamaService extends ChangeNotifier {
  final String _baseUrl;
  final Duration _timeout;
  final AuthService? _authService;
  final bool _isWeb;

  bool _isConnected = false;
  String? _version;
  List<OllamaModel> _models = [];
  bool _isLoading = false;
  String? _error;

  OllamaService({String? baseUrl, Duration? timeout, AuthService? authService})
    : _isWeb = kIsWeb,
      _baseUrl =
          baseUrl ??
          (kIsWeb ? AppConfig.cloudOllamaUrl : AppConfig.defaultOllamaUrl),
      _timeout = timeout ?? AppConfig.ollamaTimeout,
      _authService = authService {
    // Debug logging for service initialization
    if (kDebugMode) {
      debugPrint('[DEBUG] OllamaService initialized:');
      debugPrint('[DEBUG] - Platform: ${_isWeb ? 'Web' : 'Desktop'}');
      debugPrint('[DEBUG] - Base URL: $_baseUrl');
      debugPrint('[DEBUG] - Timeout: $_timeout');
      debugPrint(
        '[DEBUG] - Auth Service: ${_authService != null ? 'provided' : 'null'}',
      );
      AppConfig.logConfiguration();
    }
  }

  // Getters
  bool get isConnected => _isConnected;
  String? get version => _version;
  List<OllamaModel> get models => _models;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isWeb => _isWeb;

  /// Get HTTP headers with authentication for API requests
  Map<String, String> _getHeaders() {
    final headers = <String, String>{'Content-Type': 'application/json'};

    // Add authentication header for web platform
    if (_isWeb && _authService != null) {
      final accessToken = _authService.getAccessToken();
      if (accessToken != null) {
        headers['Authorization'] = 'Bearer $accessToken';
        if (kDebugMode) {
          debugPrint('[DEBUG] Added Authorization header for web request');
        }
      } else if (kDebugMode) {
        debugPrint('[DEBUG] No access token available for web request');
      }
    }

    return headers;
  }

  /// Test connection to Ollama server (platform-aware)
  Future<bool> testConnection() async {
    try {
      _setLoading(true);
      _clearError();

      final url = _isWeb
          ? '$_baseUrl/api/ollama/bridge/status'
          : '$_baseUrl/api/version';
      if (kDebugMode) {
        debugPrint(
          '[DEBUG] Making ${_isWeb ? 'authenticated' : 'direct'} request to: $url',
        );
      }

      final response = await http
          .get(Uri.parse(url), headers: _getHeaders())
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (_isWeb) {
          // For web, check bridge status response
          _isConnected = data['status'] == 'healthy' || data['bridges'] != null;
          _version = 'Bridge Connected';
          debugPrint(
            'Connected to Ollama bridge: ${data['bridges'] ?? 0} bridges',
          );
        } else {
          // For desktop, check direct Ollama response
          _version = data['version'] as String?;
          _isConnected = true;
          debugPrint('Connected to Ollama v$_version directly');
        }

        // Load models when connection is successful
        if (_isConnected) {
          await getModels();
        }
        return _isConnected;
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

  /// Get list of available models (platform-aware)
  Future<List<OllamaModel>> getModels() async {
    try {
      _setLoading(true);
      _clearError();

      final url = _isWeb
          ? '$_baseUrl/api/ollama/api/tags'
          : '$_baseUrl/api/tags';
      debugPrint('[DEBUG] Getting models from: $url');

      final response = await http
          .get(Uri.parse(url), headers: _getHeaders())
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final modelsList = data['models'] as List<dynamic>? ?? [];

        _models = modelsList
            .map((model) => OllamaModel.fromJson(model))
            .toList();
        debugPrint(
          'Found ${_models.length} Ollama models via ${_isWeb ? 'bridge' : 'direct connection'}',
        );
        return _models;
      } else {
        _setError('Failed to get models: HTTP ${response.statusCode}');
        debugPrint(
          '[DEBUG] Models request failed with status: ${response.statusCode}',
        );
        debugPrint('[DEBUG] Response body: ${response.body}');
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

  /// Send a chat message to Ollama (platform-aware)
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

      final url = _isWeb
          ? '$_baseUrl/api/ollama/api/chat'
          : '$_baseUrl/api/chat';
      debugPrint('[DEBUG] Sending chat message to: $url');

      final response = await http
          .post(
            Uri.parse(url),
            headers: _getHeaders(),
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
        debugPrint(
          'Chat response received via ${_isWeb ? 'bridge' : 'direct connection'}',
        );
        return responseMessage;
      } else {
        _setError('Chat failed: HTTP ${response.statusCode}');
        debugPrint(
          '[DEBUG] Chat request failed with status: ${response.statusCode}',
        );
        debugPrint('[DEBUG] Response body: ${response.body}');
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

  /// Pull a model from Ollama registry (platform-aware)
  Future<bool> pullModel(String modelName) async {
    try {
      _setLoading(true);
      _clearError();

      final url = _isWeb
          ? '$_baseUrl/api/ollama/api/pull'
          : '$_baseUrl/api/pull';
      debugPrint('[DEBUG] Pulling model from: $url');

      final response = await http
          .post(
            Uri.parse(url),
            headers: _getHeaders(),
            body: json.encode({'name': modelName}),
          )
          .timeout(
            const Duration(minutes: 10),
          ); // Longer timeout for model downloads

      final success = response.statusCode == 200;
      debugPrint(
        '[DEBUG] Model pull ${success ? 'successful' : 'failed'} via ${_isWeb ? 'bridge' : 'direct connection'}',
      );
      if (!success) {
        debugPrint('[DEBUG] Pull response: ${response.body}');
      }

      // Refresh models list if successful
      if (success) {
        await getModels();
      }

      return success;
    } catch (e) {
      _setError('Failed to pull model: $e');
      debugPrint('Error pulling model: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Delete a model from Ollama (platform-aware)
  Future<bool> deleteModel(String modelName) async {
    try {
      _setLoading(true);
      _clearError();

      final url = _isWeb
          ? '$_baseUrl/api/ollama/api/delete'
          : '$_baseUrl/api/delete';
      debugPrint('🦙 [OllamaService] Deleting model from: $url');

      final response = await http
          .delete(
            Uri.parse(url),
            headers: _getHeaders(),
            body: json.encode({'name': modelName}),
          )
          .timeout(_timeout);

      final success = response.statusCode == 200;
      debugPrint(
        '🦙 [OllamaService] Model deletion ${success ? 'successful' : 'failed'} via ${_isWeb ? 'bridge' : 'direct connection'}',
      );

      if (!success) {
        debugPrint('🦙 [OllamaService] Delete response: ${response.body}');
        _setError('Failed to delete model: HTTP ${response.statusCode}');
      } else {
        // Refresh models list after successful deletion
        await getModels();
      }

      return success;
    } catch (e) {
      _setError('Failed to delete model: $e');
      debugPrint('🦙 [OllamaService] Error deleting model: $e');
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
}

/// Model representing an Ollama model
class OllamaModel {
  final String name;
  final String? tag;
  final int? size;
  final DateTime? modifiedAt;

  const OllamaModel({required this.name, this.tag, this.size, this.modifiedAt});

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
