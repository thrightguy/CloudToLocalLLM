import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

import '../models/connection_status.dart';
import 'tunnel_service.dart';

class ApiServerService extends ChangeNotifier {
  HttpServer? _server;
  bool _isRunning = false;
  int _port = 8765;
  TunnelService? _tunnelService;

  // Request statistics
  int _totalRequests = 0;
  int _successfulRequests = 0;
  int _errorRequests = 0;
  DateTime? _lastRequest;

  // Getters
  bool get isRunning => _isRunning;
  int get port => _port;
  int get totalRequests => _totalRequests;
  int get successfulRequests => _successfulRequests;
  int get errorRequests => _errorRequests;
  DateTime? get lastRequest => _lastRequest;

  /// Start the API server
  Future<void> start(int port, {TunnelService? tunnelService}) async {
    if (_isRunning) {
      debugPrint('API server already running on port $_port');
      return;
    }

    _port = port;
    _tunnelService = tunnelService;

    try {
      _server = await HttpServer.bind(InternetAddress.anyIPv4, port);
      _isRunning = true;

      debugPrint('API server started on http://localhost:$port');

      // Handle incoming requests
      _server!.listen(_handleRequest);

      notifyListeners();
    } catch (e) {
      debugPrint('Failed to start API server: $e');
      _isRunning = false;
      rethrow;
    }
  }

  /// Stop the API server
  Future<void> stop() async {
    if (!_isRunning || _server == null) {
      return;
    }

    try {
      await _server!.close();
      _server = null;
      _isRunning = false;

      debugPrint('API server stopped');
      notifyListeners();
    } catch (e) {
      debugPrint('Error stopping API server: $e');
    }
  }

  /// Handle incoming HTTP requests
  Future<void> _handleRequest(HttpRequest request) async {
    _totalRequests++;
    _lastRequest = DateTime.now();

    try {
      // Add CORS headers
      _addCorsHeaders(request.response);

      // Handle preflight requests
      if (request.method == 'OPTIONS') {
        request.response.statusCode = 200;
        await request.response.close();
        return;
      }

      // Route the request
      await _routeRequest(request);

      _successfulRequests++;
    } catch (e) {
      _errorRequests++;
      debugPrint('API request error: $e');

      request.response.statusCode = 500;
      request.response.headers.contentType = ContentType.json;

      final errorResponse = {
        'error': 'Internal server error',
        'message': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      };

      request.response.write(json.encode(errorResponse));
      await request.response.close();
    }

    notifyListeners();
  }

  /// Add CORS headers to response
  void _addCorsHeaders(HttpResponse response) {
    response.headers.add('Access-Control-Allow-Origin', '*');
    response.headers.add(
      'Access-Control-Allow-Methods',
      'GET, POST, PUT, DELETE, OPTIONS',
    );
    response.headers.add(
      'Access-Control-Allow-Headers',
      'Content-Type, Authorization',
    );
  }

  /// Route HTTP requests to appropriate handlers
  Future<void> _routeRequest(HttpRequest request) async {
    final path = request.uri.path;
    final method = request.method;

    debugPrint('API request: $method $path');

    switch (path) {
      case '/api/health':
        await _handleHealthCheck(request);
        break;

      case '/api/status':
        await _handleStatusRequest(request);
        break;

      case '/api/connections':
        await _handleConnectionsRequest(request);
        break;

      case '/api/metrics':
        await _handleMetricsRequest(request);
        break;

      case '/api/tunnel/start':
        await _handleTunnelStart(request);
        break;

      case '/api/tunnel/stop':
        await _handleTunnelStop(request);
        break;

      case '/api/tunnel/restart':
        await _handleTunnelRestart(request);
        break;

      case '/api/version':
        await _handleVersionRequest(request);
        break;

      default:
        await _handleNotFound(request);
    }
  }

  /// Handle health check requests
  Future<void> _handleHealthCheck(HttpRequest request) async {
    final response = {
      'status': 'healthy',
      'timestamp': DateTime.now().toIso8601String(),
      'uptime': _isRunning
          ? DateTime.now().difference(_lastRequest ?? DateTime.now()).inSeconds
          : 0,
      'version': '1.0.0',
    };

    await _sendJsonResponse(request, response);
  }

  /// Handle status requests
  Future<void> _handleStatusRequest(HttpRequest request) async {
    final tunnelStatus = _tunnelService?.connectionStatus ?? {};

    final response = {
      'tunnel_manager': {
        'running': _tunnelService?.isConnected ?? false,
        'connecting': _tunnelService?.isConnecting ?? false,
        'error': _tunnelService?.error,
      },
      'connections': tunnelStatus.map(
        (key, value) => MapEntry(key, {
          'type': value.type,
          'connected': value.isConnected,
          'endpoint': value.endpoint,
          'version': value.version,
          'models': value.models,
          'latency': value.latency,
          'last_check': value.lastCheck.toIso8601String(),
          'quality': value.quality.displayName,
          'error': value.error,
        }),
      ),
      'best_connection': _tunnelService?.getBestConnection(),
      'timestamp': DateTime.now().toIso8601String(),
    };

    await _sendJsonResponse(request, response);
  }

  /// Handle connections list requests
  Future<void> _handleConnectionsRequest(HttpRequest request) async {
    final connections = _tunnelService?.connectionStatus ?? {};

    final response = {
      'connections': connections.values
          .map(
            (status) => {
              'type': status.type,
              'connected': status.isConnected,
              'endpoint': status.endpoint,
              'version': status.version,
              'models': status.models,
              'latency': status.latency,
              'quality': status.quality.displayName,
              'status_description': status.statusDescription,
              'last_check': status.lastCheck.toIso8601String(),
              'needs_attention': status.needsAttention,
              'error': status.error,
            },
          )
          .toList(),
      'total_connections': connections.length,
      'active_connections': connections.values
          .where((s) => s.isConnected)
          .length,
      'timestamp': DateTime.now().toIso8601String(),
    };

    await _sendJsonResponse(request, response);
  }

  /// Handle metrics requests
  Future<void> _handleMetricsRequest(HttpRequest request) async {
    final metrics = _tunnelService?.metrics;

    final response = {
      'api_server': {
        'total_requests': _totalRequests,
        'successful_requests': _successfulRequests,
        'error_requests': _errorRequests,
        'success_rate': _totalRequests > 0
            ? _successfulRequests / _totalRequests
            : 0.0,
        'last_request': _lastRequest?.toIso8601String(),
      },
      'tunnel_metrics': metrics?.toJson() ?? {},
      'timestamp': DateTime.now().toIso8601String(),
    };

    await _sendJsonResponse(request, response);
  }

  /// Handle tunnel start requests
  Future<void> _handleTunnelStart(HttpRequest request) async {
    if (_tunnelService == null) {
      await _sendErrorResponse(request, 'Tunnel service not available', 503);
      return;
    }

    try {
      await _tunnelService!.reconnect();

      final response = {
        'message': 'Tunnel start initiated',
        'status': 'success',
        'timestamp': DateTime.now().toIso8601String(),
      };

      await _sendJsonResponse(request, response);
    } catch (e) {
      await _sendErrorResponse(request, 'Failed to start tunnel: $e', 500);
    }
  }

  /// Handle tunnel stop requests
  Future<void> _handleTunnelStop(HttpRequest request) async {
    if (_tunnelService == null) {
      await _sendErrorResponse(request, 'Tunnel service not available', 503);
      return;
    }

    try {
      await _tunnelService!.shutdown();

      final response = {
        'message': 'Tunnel stopped',
        'status': 'success',
        'timestamp': DateTime.now().toIso8601String(),
      };

      await _sendJsonResponse(request, response);
    } catch (e) {
      await _sendErrorResponse(request, 'Failed to stop tunnel: $e', 500);
    }
  }

  /// Handle tunnel restart requests
  Future<void> _handleTunnelRestart(HttpRequest request) async {
    if (_tunnelService == null) {
      await _sendErrorResponse(request, 'Tunnel service not available', 503);
      return;
    }

    try {
      await _tunnelService!.shutdown();
      await Future.delayed(const Duration(seconds: 2));
      await _tunnelService!.reconnect();

      final response = {
        'message': 'Tunnel restarted',
        'status': 'success',
        'timestamp': DateTime.now().toIso8601String(),
      };

      await _sendJsonResponse(request, response);
    } catch (e) {
      await _sendErrorResponse(request, 'Failed to restart tunnel: $e', 500);
    }
  }

  /// Handle version requests
  Future<void> _handleVersionRequest(HttpRequest request) async {
    final response = {
      'tunnel_manager': '1.0.0',
      'api_version': '1.0',
      'build': 1,
      'timestamp': DateTime.now().toIso8601String(),
    };

    await _sendJsonResponse(request, response);
  }

  /// Handle 404 not found
  Future<void> _handleNotFound(HttpRequest request) async {
    await _sendErrorResponse(request, 'Endpoint not found', 404);
  }

  /// Send JSON response
  Future<void> _sendJsonResponse(
    HttpRequest request,
    Map<String, dynamic> data,
  ) async {
    request.response.statusCode = 200;
    request.response.headers.contentType = ContentType.json;
    request.response.write(json.encode(data));
    await request.response.close();
  }

  /// Send error response
  Future<void> _sendErrorResponse(
    HttpRequest request,
    String message,
    int statusCode,
  ) async {
    request.response.statusCode = statusCode;
    request.response.headers.contentType = ContentType.json;

    final errorResponse = {
      'error': message,
      'status_code': statusCode,
      'timestamp': DateTime.now().toIso8601String(),
    };

    request.response.write(json.encode(errorResponse));
    await request.response.close();
  }
}
