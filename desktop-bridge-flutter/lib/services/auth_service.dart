import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../config/app_config.dart';
import '../models/auth_tokens.dart';
import '../utils/logger.dart';

class AuthService extends ChangeNotifier {
  static const _storage = FlutterSecureStorage();
  
  AuthTokens? _tokens;
  bool _isAuthenticated = false;
  bool _isLoading = false;
  String? _error;
  
  HttpServer? _callbackServer;
  
  // Getters
  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  String? get error => _error;
  AuthTokens? get tokens => _tokens;
  String? get accessToken => _tokens?.accessToken;
  
  Future<void> initialize() async {
    AppLogger.info('Initializing AuthService...');
    await _loadStoredTokens();
    _validateTokens();
    AppLogger.info('AuthService initialized. Authenticated: $_isAuthenticated');
  }
  
  Future<void> _loadStoredTokens() async {
    try {
      final tokensJson = await _storage.read(key: AppConfig.storageKeyAuthTokens);
      if (tokensJson != null) {
        final tokensMap = jsonDecode(tokensJson) as Map<String, dynamic>;
        _tokens = AuthTokens.fromJson(tokensMap);
        AppLogger.info('Loaded stored authentication tokens');
      }
    } catch (e) {
      AppLogger.error('Failed to load stored tokens: $e');
      await _clearStoredTokens();
    }
  }
  
  Future<void> _saveTokens() async {
    if (_tokens != null) {
      try {
        final tokensJson = jsonEncode(_tokens!.toJson());
        await _storage.write(
          key: AppConfig.storageKeyAuthTokens,
          value: tokensJson,
        );
        AppLogger.info('Authentication tokens saved');
      } catch (e) {
        AppLogger.error('Failed to save tokens: $e');
      }
    }
  }
  
  Future<void> _clearStoredTokens() async {
    try {
      await _storage.delete(key: AppConfig.storageKeyAuthTokens);
      AppLogger.info('Stored authentication tokens cleared');
    } catch (e) {
      AppLogger.error('Failed to clear stored tokens: $e');
    }
  }
  
  void _validateTokens() {
    if (_tokens == null) {
      _isAuthenticated = false;
      return;
    }
    
    // Check if access token is expired (with 5 minute buffer)
    final now = DateTime.now();
    final expiryWithBuffer = _tokens!.expiresAt.subtract(const Duration(minutes: 5));
    
    if (now.isAfter(expiryWithBuffer)) {
      AppLogger.info('Access token expired, attempting refresh...');
      _refreshTokenIfNeeded();
    } else {
      _isAuthenticated = true;
      AppLogger.info('Access token is valid');
    }
  }
  
  Future<void> _refreshTokenIfNeeded() async {
    if (_tokens?.refreshToken == null) {
      AppLogger.warning('No refresh token available');
      _isAuthenticated = false;
      return;
    }
    
    try {
      await _refreshAccessToken();
    } catch (e) {
      AppLogger.error('Failed to refresh token: $e');
      _isAuthenticated = false;
      await logout();
    }
  }
  
  Future<void> _refreshAccessToken() async {
    if (_tokens?.refreshToken == null) {
      throw Exception('No refresh token available');
    }
    
    final response = await http.post(
      Uri.parse('https://${AppConfig.auth0Domain}/oauth/token'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'grant_type': 'refresh_token',
        'client_id': AppConfig.auth0ClientId,
        'refresh_token': _tokens!.refreshToken,
      }),
    );
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      _tokens = AuthTokens(
        accessToken: data['access_token'],
        refreshToken: data['refresh_token'] ?? _tokens!.refreshToken,
        idToken: data['id_token'],
        tokenType: data['token_type'] ?? 'Bearer',
        expiresAt: DateTime.now().add(
          Duration(seconds: data['expires_in'] ?? 3600),
        ),
      );
      
      await _saveTokens();
      _isAuthenticated = true;
      AppLogger.info('Access token refreshed successfully');
      notifyListeners();
    } else {
      throw Exception('Token refresh failed: ${response.statusCode}');
    }
  }
  
  Future<void> login() async {
    if (_isLoading) return;
    
    _setLoading(true);
    _clearError();
    
    try {
      AppLogger.info('Starting authentication flow...');
      
      // Generate PKCE parameters
      final codeVerifier = _generateCodeVerifier();
      final codeChallenge = _generateCodeChallenge(codeVerifier);
      final state = _generateState();
      
      // Start callback server
      await _startCallbackServer();
      
      // Build authorization URL
      final authUrl = _buildAuthUrl(codeChallenge, state);
      
      AppLogger.info('Opening browser for authentication...');
      
      // Launch browser
      if (await canLaunchUrl(Uri.parse(authUrl))) {
        await launchUrl(Uri.parse(authUrl));
      } else {
        throw Exception('Could not launch authentication URL');
      }
      
      // Wait for callback
      await _waitForCallback(codeVerifier, state);
      
    } catch (e) {
      AppLogger.error('Authentication failed: $e');
      _setError('Authentication failed: $e');
    } finally {
      _setLoading(false);
      await _stopCallbackServer();
    }
  }
  
  String _buildAuthUrl(String codeChallenge, String state) {
    final params = {
      'response_type': 'code',
      'client_id': AppConfig.auth0ClientId,
      'redirect_uri': AppConfig.auth0DesktopRedirectUri,
      'scope': AppConfig.auth0Scopes.join(' '),
      'state': state,
      'code_challenge': codeChallenge,
      'code_challenge_method': 'S256',
      'audience': AppConfig.auth0Audience,
    };
    
    final query = params.entries
        .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
    
    return 'https://${AppConfig.auth0Domain}/authorize?$query';
  }
  
  Future<void> _startCallbackServer() async {
    try {
      _callbackServer = await HttpServer.bind('localhost', 3025);
      AppLogger.info('Callback server started on port 3025');
    } catch (e) {
      throw Exception('Failed to start callback server: $e');
    }
  }
  
  Future<void> _stopCallbackServer() async {
    if (_callbackServer != null) {
      await _callbackServer!.close();
      _callbackServer = null;
      AppLogger.info('Callback server stopped');
    }
  }
  
  Future<void> _waitForCallback(String codeVerifier, String expectedState) async {
    if (_callbackServer == null) {
      throw Exception('Callback server not started');
    }
    
    await for (HttpRequest request in _callbackServer!) {
      try {
        final uri = request.uri;
        final code = uri.queryParameters['code'];
        final state = uri.queryParameters['state'];
        final error = uri.queryParameters['error'];
        
        if (error != null) {
          final errorDescription = uri.queryParameters['error_description'] ?? error;
          _sendCallbackResponse(request, false, 'Authentication failed: $errorDescription');
          throw Exception('Authentication error: $errorDescription');
        }
        
        if (state != expectedState) {
          _sendCallbackResponse(request, false, 'Invalid state parameter');
          throw Exception('Invalid state parameter');
        }
        
        if (code == null) {
          _sendCallbackResponse(request, false, 'No authorization code received');
          throw Exception('No authorization code received');
        }
        
        // Exchange code for tokens
        await _exchangeCodeForTokens(code, codeVerifier);
        
        _sendCallbackResponse(request, true, 'Authentication successful!');
        AppLogger.info('Authentication completed successfully');
        break;
        
      } catch (e) {
        _sendCallbackResponse(request, false, 'Authentication failed: $e');
        rethrow;
      }
    }
  }
  
  void _sendCallbackResponse(HttpRequest request, bool success, String message) {
    final html = '''
    <!DOCTYPE html>
    <html>
    <head>
        <title>CloudToLocalLLM Bridge - Authentication</title>
        <style>
            body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; 
                   text-align: center; padding: 50px; background: #f5f5f5; }
            .container { max-width: 400px; margin: 0 auto; background: white; 
                        padding: 40px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
            .success { color: #22c55e; }
            .error { color: #ef4444; }
            h1 { margin-bottom: 20px; }
            p { margin-bottom: 20px; line-height: 1.5; }
        </style>
    </head>
    <body>
        <div class="container">
            <h1 class="${success ? 'success' : 'error'}">
                ${success ? '✓' : '✗'} ${success ? 'Success!' : 'Error'}
            </h1>
            <p>$message</p>
            <p><small>You can close this window and return to the CloudToLocalLLM Bridge.</small></p>
        </div>
        <script>
            setTimeout(() => window.close(), 3000);
        </script>
    </body>
    </html>
    ''';
    
    request.response
      ..headers.contentType = ContentType.html
      ..write(html)
      ..close();
  }
  
  Future<void> _exchangeCodeForTokens(String code, String codeVerifier) async {
    final response = await http.post(
      Uri.parse('https://${AppConfig.auth0Domain}/oauth/token'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'grant_type': 'authorization_code',
        'client_id': AppConfig.auth0ClientId,
        'code': code,
        'redirect_uri': AppConfig.auth0DesktopRedirectUri,
        'code_verifier': codeVerifier,
      }),
    );
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      _tokens = AuthTokens(
        accessToken: data['access_token'],
        refreshToken: data['refresh_token'],
        idToken: data['id_token'],
        tokenType: data['token_type'] ?? 'Bearer',
        expiresAt: DateTime.now().add(
          Duration(seconds: data['expires_in'] ?? 3600),
        ),
      );
      
      await _saveTokens();
      _isAuthenticated = true;
      notifyListeners();
      
      AppLogger.info('Tokens exchanged successfully');
    } else {
      throw Exception('Token exchange failed: ${response.statusCode}');
    }
  }
  
  Future<void> logout() async {
    AppLogger.info('Logging out...');
    
    _tokens = null;
    _isAuthenticated = false;
    await _clearStoredTokens();
    
    notifyListeners();
    AppLogger.info('Logout completed');
  }
  
  // PKCE helper methods
  String _generateCodeVerifier() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (i) => random.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }
  
  String _generateCodeChallenge(String verifier) {
    final bytes = utf8.encode(verifier);
    final digest = sha256.convert(bytes);
    return base64Url.encode(digest.bytes).replaceAll('=', '');
  }
  
  String _generateState() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (i) => random.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }
  
  // Helper methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
  
  void _setError(String? error) {
    _error = error;
    notifyListeners();
  }
  
  void _clearError() {
    _error = null;
    notifyListeners();
  }
}
