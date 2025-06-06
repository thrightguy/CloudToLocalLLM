import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// Simplified connection service for local Ollama connections
///
/// This service provides direct HTTP connections to local Ollama instance
/// without external daemon dependencies.
class SimplifiedConnectionService extends ChangeNotifier {
  static const String _baseUrl = 'http://localhost:11434';

  bool _isConnected = false;
  String? _version;
  List<OllamaModel> _models = [];
  bool _isLoading = false;
  String? _error;

  // Getters
  bool get isConnected => _isConnected;
  String? get version => _version;
  List<OllamaModel> get models => _models;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Initialize the connection service
  Future<bool> initialize() async {
    return await testConnection();
  }

  /// Test connection by getting version info
  Future<bool> testConnection() async {
    try {
      _setLoading(true);
      _clearError();

      final response = await http.get(
        Uri.parse('$_baseUrl/api/version'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _version = data['version'] ?? 'Unknown';
        _isConnected = true;
        debugPrint('✅ [SimplifiedConnectionService] Connected to Ollama v$_version');
        notifyListeners();
        return true;
      } else {
        _setError('Ollama server returned status ${response.statusCode}');
        return false;
      }
    } catch (e) {
      _setError('Failed to connect to Ollama: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Get available models
  Future<List<OllamaModel>> getModels() async {
    try {
      _setLoading(true);
      _clearError();

      final response = await http.get(
        Uri.parse('$_baseUrl/api/tags'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final modelsData = data['models'] as List<dynamic>? ?? [];
        _models = modelsData
            .map((model) => OllamaModel.fromJson(model as Map<String, dynamic>))
            .toList();

        debugPrint('✅ [SimplifiedConnectionService] Loaded ${_models.length} models');
        notifyListeners();
        return _models;
      } else {
        _setError('Failed to load models: status ${response.statusCode}');
        return [];
      }
    } catch (e) {
      _setError('Error loading models: $e');
      return [];
    } finally {
      _setLoading(false);
    }
  }

  /// Send a chat message
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

      final response = await http.post(
        Uri.parse('$_baseUrl/api/chat'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'model': model,
          'messages': messages,
          'stream': false,
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final responseMessage = data['message'];
        if (responseMessage != null && responseMessage['content'] != null) {
          return responseMessage['content'] as String;
        } else {
          _setError('Invalid response format from Ollama');
          return null;
        }
      } else {
        _setError('Chat request failed: status ${response.statusCode}');
        return null;
      }
    } catch (e) {
      _setError('Chat error: $e');
      return null;
    } finally {
      _setLoading(false);
    }
  }

  /// Pull a model from registry
  Future<bool> pullModel(String modelName) async {
    try {
      _setLoading(true);
      _clearError();

      final response = await http.post(
        Uri.parse('$_baseUrl/api/pull'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'name': modelName}),
      ).timeout(const Duration(minutes: 10)); // Model pulls can take a while

      if (response.statusCode == 200) {
        debugPrint('✅ [SimplifiedConnectionService] Model pull successful: $modelName');
        // Refresh models list
        await getModels();
        return true;
      } else {
        _setError('Model pull failed: status ${response.statusCode}');
        return false;
      }
    } catch (e) {
      _setError('Model pull error: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Helper methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _error = error;
    _isConnected = false;
    debugPrint('❌ [SimplifiedConnectionService] Error: $error');
    notifyListeners();
  }

  void _clearError() {
    _error = null;
    notifyListeners();
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
