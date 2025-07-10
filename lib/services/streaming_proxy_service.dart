import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import 'auth_service.dart';

/// Service for managing streaming proxy connections
/// Handles proxy lifecycle, status monitoring, and connection management
class StreamingProxyService extends ChangeNotifier {
  final String _baseUrl;
  final Duration _timeout;
  final AuthService? _authService;

  bool _isProxyRunning = false;
  String? _proxyId;
  DateTime? _proxyCreatedAt;
  String? _error;
  bool _isLoading = false;

  StreamingProxyService({
    String? baseUrl,
    Duration? timeout,
    AuthService? authService,
  }) : _baseUrl = baseUrl ?? AppConfig.cloudOllamaUrl,
       _timeout = timeout ?? AppConfig.ollamaTimeout,
       _authService = authService {
    if (kDebugMode) {
      debugPrint('[StreamingProxy] Service initialized');
      debugPrint('[StreamingProxy] Base URL: $_baseUrl');
    }
  }

  // Getters
  bool get isProxyRunning => _isProxyRunning;
  String? get proxyId => _proxyId;
  DateTime? get proxyCreatedAt => _proxyCreatedAt;
  String? get error => _error;
  bool get isLoading => _isLoading;

  /// Get HTTP headers with authentication
  Map<String, String> _getHeaders() {
    final headers = <String, String>{'Content-Type': 'application/json'};

    if (_authService != null) {
      final accessToken = _authService.getAccessToken();
      if (accessToken != null) {
        headers['Authorization'] = 'Bearer $accessToken';
      }
    }

    return headers;
  }

  /// Start streaming proxy for current user
  Future<bool> startProxy() async {
    try {
      _setLoading(true);
      _clearError();

      if (kDebugMode) {
        debugPrint('[StreamingProxy] Starting proxy...');
      }

      final response = await http
          .post(Uri.parse('$_baseUrl/api/proxy/start'), headers: _getHeaders())
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          _proxyId = data['proxy']['proxyId'];
          _proxyCreatedAt = DateTime.parse(data['proxy']['createdAt']);
          _isProxyRunning = true;

          if (kDebugMode) {
            debugPrint('[StreamingProxy] Proxy started: $_proxyId');
          }

          notifyListeners();
          return true;
        } else {
          _setError('Failed to start proxy: ${data['message']}');
          return false;
        }
      } else {
        final errorData = json.decode(response.body);
        _setError('Failed to start proxy: ${errorData['message']}');
        return false;
      }
    } catch (e) {
      _setError('Failed to start proxy: $e');
      if (kDebugMode) {
        debugPrint('[StreamingProxy] Start error: $e');
      }
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Stop streaming proxy for current user
  Future<bool> stopProxy() async {
    try {
      _setLoading(true);
      _clearError();

      if (kDebugMode) {
        debugPrint('[StreamingProxy] Stopping proxy...');
      }

      final response = await http
          .post(Uri.parse('$_baseUrl/api/proxy/stop'), headers: _getHeaders())
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          _proxyId = null;
          _proxyCreatedAt = null;
          _isProxyRunning = false;

          if (kDebugMode) {
            debugPrint('[StreamingProxy] Proxy stopped successfully');
          }

          notifyListeners();
          return true;
        } else {
          _setError('Failed to stop proxy: ${data['message']}');
          return false;
        }
      } else {
        final errorData = json.decode(response.body);
        _setError('Failed to stop proxy: ${errorData['message']}');
        return false;
      }
    } catch (e) {
      _setError('Failed to stop proxy: $e');
      if (kDebugMode) {
        debugPrint('[StreamingProxy] Stop error: $e');
      }
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Get streaming proxy status
  Future<bool> checkProxyStatus() async {
    try {
      _setLoading(true);
      _clearError();

      final response = await http
          .get(Uri.parse('$_baseUrl/api/proxy/status'), headers: _getHeaders())
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        _isProxyRunning = data['status'] == 'running';

        if (_isProxyRunning) {
          _proxyId = data['proxyId'];
          if (data['createdAt'] != null) {
            _proxyCreatedAt = DateTime.parse(data['createdAt']);
          }
        } else {
          _proxyId = null;
          _proxyCreatedAt = null;
        }

        if (kDebugMode) {
          debugPrint('[StreamingProxy] Status: ${data['status']}');
        }

        notifyListeners();
        return _isProxyRunning;
      } else {
        final errorData = json.decode(response.body);
        _setError('Failed to check proxy status: ${errorData['message']}');
        return false;
      }
    } catch (e) {
      _setError('Failed to check proxy status: $e');
      if (kDebugMode) {
        debugPrint('[StreamingProxy] Status check error: $e');
      }
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Ensure proxy is running (start if not running)
  Future<bool> ensureProxyRunning() async {
    // First check current status
    await checkProxyStatus();

    // Start proxy if not running
    if (!_isProxyRunning) {
      return await startProxy();
    }

    return true;
  }

  /// Get proxy uptime
  Duration? get proxyUptime {
    if (_proxyCreatedAt == null) return null;
    return DateTime.now().difference(_proxyCreatedAt!);
  }

  /// Get formatted proxy uptime
  String get formattedUptime {
    final uptime = proxyUptime;
    if (uptime == null) return 'N/A';

    final hours = uptime.inHours;
    final minutes = uptime.inMinutes % 60;
    final seconds = uptime.inSeconds % 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
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

  @override
  void dispose() {
    // Clean up any resources
    super.dispose();
  }
}
