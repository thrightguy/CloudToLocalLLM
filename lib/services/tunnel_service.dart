import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import 'auth_service.dart';

class TunnelService {
  final String cloudBaseUrl;
  final AuthService authService;
  
  HttpServer? _server;
  bool _isRunning = false;
  final ValueNotifier<bool> isConnected = ValueNotifier<bool>(false);
  final ValueNotifier<String> tunnelUrl = ValueNotifier<String>('');
  
  TunnelService({
    String? cloudBaseUrl,
    required this.authService,
  }) : cloudBaseUrl = cloudBaseUrl ?? AppConfig.cloudBaseUrl;
  
  // Check if the tunnel is running
  bool get isRunning => _isRunning;
  
  // Start the tunnel server
  Future<bool> startTunnel() async {
    if (_isRunning) return true;
    
    try {
      // Start a local HTTP server
      _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final port = _server!.port;
      
      // Register the tunnel with the cloud service
      final registered = await _registerTunnel(port);
      if (!registered) {
        await _server!.close();
        _server = null;
        return false;
      }
      
      _isRunning = true;
      isConnected.value = true;
      
      // Handle incoming requests
      _server!.listen((HttpRequest request) async {
        try {
          // Parse the request
          final body = await utf8.decoder.bind(request).join();
          final Map<String, dynamic> data = jsonDecode(body);
          
          // Forward the request to the local LLM
          final response = await _forwardToLocalLlm(data);
          
          // Send the response back
          request.response.headers.contentType = ContentType.json;
          request.response.write(jsonEncode(response));
          await request.response.close();
        } catch (e) {
          request.response.statusCode = HttpStatus.internalServerError;
          request.response.write(jsonEncode({'error': e.toString()}));
          await request.response.close();
        }
      });
      
      return true;
    } catch (e) {
      print('Error starting tunnel: $e');
      _isRunning = false;
      isConnected.value = false;
      return false;
    }
  }
  
  // Stop the tunnel server
  Future<void> stopTunnel() async {
    if (!_isRunning) return;
    
    try {
      // Unregister the tunnel with the cloud service
      await _unregisterTunnel();
      
      // Close the server
      await _server?.close();
      _server = null;
      _isRunning = false;
      isConnected.value = false;
      tunnelUrl.value = '';
    } catch (e) {
      print('Error stopping tunnel: $e');
    }
  }
  
  // Register the tunnel with the cloud service
  Future<bool> _registerTunnel(int port) async {
    try {
      // Ensure the user is authenticated
      if (!authService.isAuthenticated.value) {
        return false;
      }
      
      // Register the tunnel
      final response = await http.post(
        Uri.parse('$cloudBaseUrl/api/tunnel/register'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${authService.token}',
        },
        body: jsonEncode({
          'port': port,
          'userId': authService.currentUser?.id,
        }),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        tunnelUrl.value = data['tunnelUrl'];
        return true;
      } else {
        return false;
      }
    } catch (e) {
      print('Error registering tunnel: $e');
      return false;
    }
  }
  
  // Unregister the tunnel with the cloud service
  Future<bool> _unregisterTunnel() async {
    try {
      // Ensure the user is authenticated
      if (!authService.isAuthenticated.value) {
        return false;
      }
      
      // Unregister the tunnel
      final response = await http.post(
        Uri.parse('$cloudBaseUrl/api/tunnel/unregister'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${authService.token}',
        },
        body: jsonEncode({
          'userId': authService.currentUser?.id,
        }),
      );
      
      return response.statusCode == 200;
    } catch (e) {
      print('Error unregistering tunnel: $e');
      return false;
    }
  }
  
  // Forward a request to the local LLM
  Future<Map<String, dynamic>> _forwardToLocalLlm(Map<String, dynamic> data) async {
    try {
      final prompt = data['prompt'] as String?;
      final model = data['model'] as String? ?? 'tinyllama';
      
      if (prompt == null || prompt.isEmpty) {
        return {'error': 'Missing or empty prompt'};
      }
      
      // Forward to Ollama
      final ollamaUrl = Uri.parse('http://localhost:11434/api/generate');
      final ollamaResponse = await http.post(
        ollamaUrl,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'model': model, 'prompt': prompt}),
      );
      
      if (ollamaResponse.statusCode == 200) {
        final responseData = jsonDecode(ollamaResponse.body);
        return {'response': responseData['response']};
      } else {
        return {'error': 'Failed to get response from local LLM'};
      }
    } catch (e) {
      return {'error': e.toString()};
    }
  }
  
  // Check the tunnel status
  Future<bool> checkTunnelStatus() async {
    try {
      // Ensure the user is authenticated
      if (!authService.isAuthenticated.value) {
        return false;
      }
      
      // Check the tunnel status
      final response = await http.get(
        Uri.parse('$cloudBaseUrl/api/tunnel/status'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${authService.token}',
        },
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        isConnected.value = data['isConnected'] ?? false;
        tunnelUrl.value = data['tunnelUrl'] ?? '';
        return isConnected.value;
      } else {
        isConnected.value = false;
        tunnelUrl.value = '';
        return false;
      }
    } catch (e) {
      print('Error checking tunnel status: $e');
      isConnected.value = false;
      tunnelUrl.value = '';
      return false;
    }
  }
}