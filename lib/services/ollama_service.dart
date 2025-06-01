import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import 'auth_service.dart';

/// Service for communicating with Ollama API directly (localhost for desktop)
class OllamaService extends ChangeNotifier {
  final String _baseUrl;
  final Duration _timeout;
  final AuthService? _authService;

  bool _isConnected = false;
  String? _version;
  List<OllamaModel> _models = [];
  bool _isLoading = false;
  String? _error;

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

  /// Test connection to Ollama server directly (localhost)
  Future<bool> testConnection() async {
    try {
      _setLoading(true);
      _clearError();

      final url = '$_baseUrl/api/version';
      debugPrint('[DEBUG] Making direct request to: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _version = data['version'] as String?;
        _isConnected = true;
        debugPrint('Connected to Ollama v$_version directly');

        // Also load models when connection is successful
        await getModels();
        return true;
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

  /// Get list of available models directly from Ollama
  Future<List<OllamaModel>> getModels() async {
    try {
      _setLoading(true);
      _clearError();

      final response = await http.get(
        Uri.parse('$_baseUrl/api/tags'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final modelsList = data['models'] as List<dynamic>? ?? [];

        _models =
            modelsList.map((model) => OllamaModel.fromJson(model)).toList();
        debugPrint('Found ${_models.length} Ollama models directly');
        return _models;
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

  /// Send a chat message to Ollama directly
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

      final response = await http
          .post(
            Uri.parse('$_baseUrl/api/chat'),
            headers: {'Content-Type': 'application/json'},
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
        debugPrint('Chat response received directly from Ollama');
        return responseMessage;
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
