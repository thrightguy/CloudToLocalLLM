import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Ollama service for testing and managing local Ollama connections
///
/// Provides functionality for:
/// - Testing Ollama server connectivity
/// - Listing available models
/// - Testing model responses
/// - Connection health monitoring
/// - Configuration validation
class OllamaService extends ChangeNotifier {
  String _status = 'Not Initialized';
  bool _isConnected = false;
  String _baseUrl = 'http://localhost:11434';
  List<String> _availableModels = [];
  String? _lastError;
  Timer? _healthCheckTimer;
  http.Client? _httpClient;

  /// Get current service status
  String get status => _status;

  /// Check if connected to Ollama
  bool get isConnected => _isConnected;

  /// Get base URL
  String get baseUrl => _baseUrl;

  /// Get available models
  List<String> get availableModels => List.from(_availableModels);

  /// Get last error message
  String? get lastError => _lastError;

  /// Initialize Ollama service
  Future<bool> initialize() async {
    try {
      debugPrint("Initializing OllamaService...");
      _status = "Initializing";
      notifyListeners();

      // Create HTTP client
      _httpClient = http.Client();

      _status = "Initialized";
      notifyListeners();

      debugPrint("OllamaService initialized successfully");
      return true;
    } catch (e) {
      debugPrint("Failed to initialize OllamaService: $e");
      _status = "Error: $e";
      _lastError = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Set Ollama base URL
  Future<void> setBaseUrl(String url) async {
    if (_baseUrl != url) {
      _baseUrl = url;
      _isConnected = false;
      _availableModels.clear();
      _lastError = null;
      
      debugPrint("Ollama base URL updated: $url");
      notifyListeners();
    }
  }

  /// Test connection to Ollama server
  Future<bool> testConnection() async {
    try {
      debugPrint("Testing Ollama connection to $_baseUrl");
      _status = "Testing connection";
      _lastError = null;
      notifyListeners();

      if (_httpClient == null) {
        throw Exception("HTTP client not initialized");
      }

      // Test basic connectivity with version endpoint
      final versionUrl = Uri.parse('$_baseUrl/api/version');
      final response = await _httpClient!.get(versionUrl)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final versionData = jsonDecode(response.body) as Map<String, dynamic>;
        debugPrint("Ollama version: ${versionData['version']}");
        
        _isConnected = true;
        _status = "Connected";
        
        // Load available models
        await _loadModels();
        
        notifyListeners();
        return true;
      } else {
        throw Exception("HTTP ${response.statusCode}: ${response.reasonPhrase}");
      }
    } catch (e) {
      debugPrint("Ollama connection test failed: $e");
      _isConnected = false;
      _status = "Connection failed";
      _lastError = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Load available models from Ollama
  Future<void> _loadModels() async {
    try {
      debugPrint("Loading Ollama models...");
      
      if (_httpClient == null) {
        throw Exception("HTTP client not initialized");
      }

      final modelsUrl = Uri.parse('$_baseUrl/api/tags');
      final response = await _httpClient!.get(modelsUrl)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final modelsData = jsonDecode(response.body) as Map<String, dynamic>;
        final models = modelsData['models'] as List<dynamic>? ?? [];
        
        _availableModels = models
            .map((model) => model['name'] as String)
            .toList();
        
        debugPrint("Loaded ${_availableModels.length} Ollama models");
      } else {
        throw Exception("Failed to load models: HTTP ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("Failed to load Ollama models: $e");
      _lastError = e.toString();
    }
  }

  /// Test a specific model with a simple prompt
  Future<String?> testModel(String modelName, {String? prompt}) async {
    try {
      debugPrint("Testing Ollama model: $modelName");
      _status = "Testing model $modelName";
      _lastError = null;
      notifyListeners();

      if (_httpClient == null) {
        throw Exception("HTTP client not initialized");
      }

      final testPrompt = prompt ?? "Hello! Please respond with a brief greeting.";
      
      final generateUrl = Uri.parse('$_baseUrl/api/generate');
      final requestBody = jsonEncode({
        'model': modelName,
        'prompt': testPrompt,
        'stream': false,
        'options': {
          'temperature': 0.7,
          'max_tokens': 100,
        },
      });

      final response = await _httpClient!.post(
        generateUrl,
        headers: {'Content-Type': 'application/json'},
        body: requestBody,
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body) as Map<String, dynamic>;
        final responseText = responseData['response'] as String?;
        
        _status = "Model test completed";
        notifyListeners();
        
        debugPrint("Model test successful: ${responseText?.substring(0, 50)}...");
        return responseText;
      } else {
        throw Exception("HTTP ${response.statusCode}: ${response.reasonPhrase}");
      }
    } catch (e) {
      debugPrint("Model test failed: $e");
      _status = "Model test failed";
      _lastError = e.toString();
      notifyListeners();
      return null;
    }
  }

  /// Start health monitoring
  void startHealthMonitoring({Duration interval = const Duration(minutes: 5)}) {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = Timer.periodic(interval, (_) {
      if (_isConnected) {
        _performHealthCheck();
      }
    });
    debugPrint("Ollama health monitoring started");
  }

  /// Stop health monitoring
  void stopHealthMonitoring() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = null;
    debugPrint("Ollama health monitoring stopped");
  }

  /// Perform health check
  Future<void> _performHealthCheck() async {
    try {
      if (_httpClient == null) return;

      final versionUrl = Uri.parse('$_baseUrl/api/version');
      final response = await _httpClient!.get(versionUrl)
          .timeout(const Duration(seconds: 5));

      if (response.statusCode != 200) {
        _handleConnectionLost();
      }
    } catch (e) {
      debugPrint("Health check failed: $e");
      _handleConnectionLost();
    }
  }

  /// Handle connection lost
  void _handleConnectionLost() {
    if (_isConnected) {
      _isConnected = false;
      _status = "Connection lost";
      _lastError = "Health check failed";
      notifyListeners();
      debugPrint("Ollama connection lost");
    }
  }

  /// Get server information
  Future<Map<String, dynamic>?> getServerInfo() async {
    try {
      if (_httpClient == null || !_isConnected) {
        return null;
      }

      final versionUrl = Uri.parse('$_baseUrl/api/version');
      final response = await _httpClient!.get(versionUrl)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint("Failed to get server info: $e");
    }
    return null;
  }

  /// Pull a model from Ollama registry
  Future<bool> pullModel(String modelName) async {
    try {
      debugPrint("Pulling Ollama model: $modelName");
      _status = "Pulling model $modelName";
      _lastError = null;
      notifyListeners();

      if (_httpClient == null) {
        throw Exception("HTTP client not initialized");
      }

      final pullUrl = Uri.parse('$_baseUrl/api/pull');
      final requestBody = jsonEncode({
        'name': modelName,
        'stream': false,
      });

      final response = await _httpClient!.post(
        pullUrl,
        headers: {'Content-Type': 'application/json'},
        body: requestBody,
      ).timeout(const Duration(minutes: 10)); // Model pulling can take time

      if (response.statusCode == 200) {
        _status = "Model pulled successfully";
        await _loadModels(); // Refresh model list
        notifyListeners();
        debugPrint("Model $modelName pulled successfully");
        return true;
      } else {
        throw Exception("HTTP ${response.statusCode}: ${response.reasonPhrase}");
      }
    } catch (e) {
      debugPrint("Failed to pull model: $e");
      _status = "Model pull failed";
      _lastError = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Delete a model
  Future<bool> deleteModel(String modelName) async {
    try {
      debugPrint("Deleting Ollama model: $modelName");
      _status = "Deleting model $modelName";
      _lastError = null;
      notifyListeners();

      if (_httpClient == null) {
        throw Exception("HTTP client not initialized");
      }

      final deleteUrl = Uri.parse('$_baseUrl/api/delete');
      final requestBody = jsonEncode({'name': modelName});

      final response = await _httpClient!.delete(
        deleteUrl,
        headers: {'Content-Type': 'application/json'},
        body: requestBody,
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        _status = "Model deleted successfully";
        await _loadModels(); // Refresh model list
        notifyListeners();
        debugPrint("Model $modelName deleted successfully");
        return true;
      } else {
        throw Exception("HTTP ${response.statusCode}: ${response.reasonPhrase}");
      }
    } catch (e) {
      debugPrint("Failed to delete model: $e");
      _status = "Model deletion failed";
      _lastError = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Cleanup resources
  @override
  Future<void> dispose() async {
    stopHealthMonitoring();
    _httpClient?.close();
    _httpClient = null;
    super.dispose();
  }
}
