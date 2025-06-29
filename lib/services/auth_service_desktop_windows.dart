import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:url_launcher/url_launcher.dart';
import '../config/app_config.dart';
import '../models/user_model.dart';

/// Windows-compatible desktop authentication service using OAuth 2.0 with PKCE
///
/// This service implements the OAuth 2.0 Authorization Code Flow with PKCE
/// for Windows desktop applications, using a local HTTP server to handle
/// the OAuth callback and url_launcher to open the browser.
class AuthServiceDesktopWindows extends ChangeNotifier {
  // OAuth state and PKCE parameters
  String? _codeVerifier;
  String? _state;
  String? _accessToken;
  UserModel? _currentUser;

  // Local server for OAuth callback
  HttpServer? _callbackServer;
  int _callbackPort = 8080; // Will be extracted from configured redirect URI
  Completer<Map<String, String>>? _authCompleter;

  final ValueNotifier<bool> _isAuthenticated = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _isLoading = ValueNotifier<bool>(false);

  // Getters
  ValueNotifier<bool> get isAuthenticated => _isAuthenticated;
  ValueNotifier<bool> get isLoading => _isLoading;
  UserModel? get currentUser => _currentUser;
  String? get accessToken => _accessToken;

  AuthServiceDesktopWindows() {
    debugPrint(
      '🖥️ [AuthWindows] Windows-compatible authentication service initialized',
    );
  }

  /// Generate a cryptographically secure random string
  String _generateRandomString(int length) {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';
    final random = Random.secure();
    return List.generate(
      length,
      (index) => chars[random.nextInt(chars.length)],
    ).join();
  }

  /// Generate PKCE code verifier and challenge
  Map<String, String> _generatePKCE() {
    _codeVerifier = _generateRandomString(128);
    final bytes = utf8.encode(_codeVerifier!);
    final digest = sha256.convert(bytes);
    final codeChallenge = base64Url.encode(digest.bytes).replaceAll('=', '');

    return {
      'code_verifier': _codeVerifier!,
      'code_challenge': codeChallenge,
      'code_challenge_method': 'S256',
    };
  }

  /// Start local HTTP server to handle OAuth callback
  Future<void> _startCallbackServer() async {
    try {
      // Extract port from configured redirect URI to ensure consistency with Auth0
      final redirectUri = Uri.parse(AppConfig.auth0DesktopRedirectUri);
      _callbackPort = redirectUri.port;

      debugPrint(
        '🖥️ [AuthWindows] Starting callback server on configured port $_callbackPort',
      );

      // Start server on the exact port configured in Auth0
      _callbackServer = await io.serve(
        _handleCallback,
        'localhost',
        _callbackPort,
      );

      debugPrint(
        '🖥️ [AuthWindows] Callback server started successfully on port $_callbackPort',
      );
    } catch (e) {
      debugPrint(
        '🖥️ [AuthWindows] Failed to start callback server on port $_callbackPort: $e',
      );
      debugPrint(
        '🖥️ [AuthWindows] Make sure port $_callbackPort is available and not used by another application',
      );
      rethrow;
    }
  }

  /// Handle OAuth callback from the browser
  Response _handleCallback(Request request) {
    try {
      final uri = request.requestedUri;
      debugPrint('🖥️ [AuthWindows] Received callback: ${uri.toString()}');

      final params = uri.queryParameters;

      if (params.containsKey('error')) {
        final error = params['error'];
        final errorDescription = params['error_description'] ?? 'Unknown error';
        debugPrint('🖥️ [AuthWindows] OAuth error: $error - $errorDescription');
        _authCompleter?.complete({
          'error': error!,
          'error_description': errorDescription,
        });
      } else if (params.containsKey('code')) {
        final code = params['code']!;
        final state = params['state'];
        debugPrint('🖥️ [AuthWindows] Received authorization code');
        _authCompleter?.complete({'code': code, 'state': state ?? ''});
      } else {
        debugPrint(
          '🖥️ [AuthWindows] Invalid callback - missing code and error',
        );
        _authCompleter?.complete({
          'error': 'invalid_callback',
          'error_description': 'Missing authorization code',
        });
      }

      // Return a success page
      return Response.ok(
        '''
        <!DOCTYPE html>
        <html>
        <head>
          <title>CloudToLocalLLM - Authentication</title>
          <style>
            body { font-family: Arial, sans-serif; text-align: center; padding: 50px; }
            .success { color: #4CAF50; }
            .error { color: #f44336; }
          </style>
        </head>
        <body>
          <h1>CloudToLocalLLM</h1>
          <p class="success">Authentication completed! You can close this window.</p>
          <script>
            // Auto-close the window after 3 seconds
            setTimeout(() => window.close(), 3000);
          </script>
        </body>
        </html>
      ''',
        headers: {'Content-Type': 'text/html'},
      );
    } catch (e) {
      debugPrint('🖥️ [AuthWindows] Error handling callback: $e');
      _authCompleter?.complete({
        'error': 'callback_error',
        'error_description': e.toString(),
      });
      return Response.internalServerError(body: 'Internal server error');
    }
  }

  /// Stop the callback server
  Future<void> _stopCallbackServer() async {
    if (_callbackServer != null) {
      await _callbackServer!.close();
      _callbackServer = null;
      debugPrint('🖥️ [AuthWindows] Callback server stopped');
    }
  }

  /// Login using OAuth 2.0 Authorization Code Flow with PKCE
  Future<void> login() async {
    try {
      _isLoading.value = true;
      notifyListeners();

      // Generate PKCE parameters
      final pkce = _generatePKCE();
      _state = _generateRandomString(32);

      // Start callback server
      await _startCallbackServer();

      // Use the configured redirect URI to ensure consistency with Auth0
      final redirectUri = AppConfig.auth0DesktopRedirectUri;
      final authUrl = Uri.parse('${AppConfig.auth0Issuer}authorize').replace(
        queryParameters: {
          'response_type': 'code',
          'client_id': AppConfig.auth0ClientId,
          'redirect_uri': redirectUri,
          'scope': AppConfig.auth0Scopes.join(' '),
          'state': _state!,
          'code_challenge': pkce['code_challenge']!,
          'code_challenge_method': pkce['code_challenge_method']!,
        },
      );

      debugPrint(
        '🖥️ [AuthWindows] Opening authorization URL: ${authUrl.toString()}',
      );

      // Open browser for authentication
      if (await canLaunchUrl(authUrl)) {
        await launchUrl(authUrl, mode: LaunchMode.externalApplication);
      } else {
        throw Exception('Could not launch authentication URL');
      }

      // Wait for callback
      _authCompleter = Completer<Map<String, String>>();
      final result = await _authCompleter!.future.timeout(
        const Duration(minutes: 5),
        onTimeout: () => {
          'error': 'timeout',
          'error_description': 'Authentication timed out',
        },
      );

      // Stop callback server
      await _stopCallbackServer();

      if (result.containsKey('error')) {
        throw Exception(
          'Authentication failed: ${result['error']} - ${result['error_description']}',
        );
      }

      // Verify state parameter
      if (result['state'] != _state) {
        throw Exception('Invalid state parameter - possible CSRF attack');
      }

      // Exchange authorization code for tokens
      await _exchangeCodeForTokens(result['code']!, redirectUri);

      _isAuthenticated.value = true;
      debugPrint('🖥️ [AuthWindows] Authentication successful');
    } catch (e) {
      debugPrint('🖥️ [AuthWindows] Authentication failed: $e');
      await _stopCallbackServer();
      rethrow;
    } finally {
      _isLoading.value = false;
      notifyListeners();
    }
  }

  /// Exchange authorization code for access and ID tokens
  Future<void> _exchangeCodeForTokens(String code, String redirectUri) async {
    try {
      final tokenUrl = '${AppConfig.auth0Issuer}oauth/token';

      final response = await http.post(
        Uri.parse(tokenUrl),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'grant_type': 'authorization_code',
          'client_id': AppConfig.auth0ClientId,
          'code': code,
          'redirect_uri': redirectUri,
          'code_verifier': _codeVerifier!,
        },
      );

      if (response.statusCode == 200) {
        final tokenData = json.decode(response.body);
        _accessToken = tokenData['access_token'];

        debugPrint('🖥️ [AuthWindows] Tokens received successfully');

        // Load user profile
        await _loadUserProfile();
      } else {
        final errorData = json.decode(response.body);
        throw Exception(
          'Token exchange failed: ${errorData['error']} - ${errorData['error_description']}',
        );
      }
    } catch (e) {
      debugPrint('🖥️ [AuthWindows] Token exchange failed: $e');
      rethrow;
    }
  }

  /// Load user profile from Auth0
  Future<void> _loadUserProfile() async {
    if (_accessToken == null) return;

    try {
      final userInfoUrl = '${AppConfig.auth0Issuer}userinfo';
      final response = await http.get(
        Uri.parse(userInfoUrl),
        headers: {'Authorization': 'Bearer $_accessToken'},
      );

      if (response.statusCode == 200) {
        final userData = json.decode(response.body);
        _currentUser = UserModel.fromJson(userData);
        debugPrint(
          '🖥️ [AuthWindows] User profile loaded: ${_currentUser?.email}',
        );
      } else {
        debugPrint(
          '🖥️ [AuthWindows] Failed to load user profile: ${response.statusCode}',
        );
      }
    } catch (e) {
      debugPrint('🖥️ [AuthWindows] Error loading user profile: $e');
    }
  }

  /// Logout
  Future<void> logout() async {
    try {
      _isLoading.value = true;
      notifyListeners();

      // Clear tokens and user data
      _accessToken = null;
      _currentUser = null;
      _codeVerifier = null;
      _state = null;

      _isAuthenticated.value = false;
      debugPrint('🖥️ [AuthWindows] Logout successful');
    } catch (e) {
      debugPrint('🖥️ [AuthWindows] Logout error: $e');
    } finally {
      _isLoading.value = false;
      notifyListeners();
    }
  }

  /// Handle authentication callback (compatibility method)
  Future<bool> handleCallback() async {
    // This method is handled automatically by the local server
    return _isAuthenticated.value;
  }

  @override
  void dispose() {
    _stopCallbackServer();
    _isAuthenticated.dispose();
    _isLoading.dispose();
    super.dispose();
  }
}
