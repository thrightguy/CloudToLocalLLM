import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;
import '../config/app_config.dart';
import '../models/user_model.dart';

/// Web-specific authentication service using direct Auth0 redirect
class AuthServiceWeb extends ChangeNotifier {
  final ValueNotifier<bool> _isAuthenticated = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _isLoading = ValueNotifier<bool>(false);
  UserModel? _currentUser;

  // Getters
  ValueNotifier<bool> get isAuthenticated => _isAuthenticated;
  ValueNotifier<bool> get isLoading => _isLoading;
  UserModel? get currentUser => _currentUser;

  AuthServiceWeb() {
    _initialize();
  }

  /// Initialize authentication service
  Future<void> _initialize() async {
    try {
      _isLoading.value = true;
      notifyListeners();

      // Check for existing authentication
      await _checkAuthenticationStatus();
    } catch (e) {
      debugPrint('Error initializing Auth0: $e');
    } finally {
      _isLoading.value = false;
      notifyListeners();
    }
  }

  /// Check current authentication status
  Future<void> _checkAuthenticationStatus() async {
    try {
      // For now, we'll implement a simple check
      // In a production app, you'd check for stored tokens
      _isAuthenticated.value = false;
    } catch (e) {
      debugPrint('Error checking authentication status: $e');
      _isAuthenticated.value = false;
    }
  }

  /// Login using Auth0 redirect flow
  Future<void> login() async {
    debugPrint('🔐 Web login method called');
    try {
      _isLoading.value = true;
      notifyListeners();
      debugPrint('🔐 Loading state set to true');

      // For web, redirect directly to Auth0 login page
      final redirectUri = AppConfig.auth0WebRedirectUri;
      final state = DateTime.now().millisecondsSinceEpoch.toString();
      debugPrint('🔐 Redirect URI: $redirectUri');
      debugPrint('🔐 State: $state');

      final authUrl = Uri.https(
        AppConfig.auth0Domain,
        '/authorize',
        {
          'client_id': AppConfig.auth0ClientId,
          'redirect_uri': redirectUri,
          'response_type': 'code',
          'scope': AppConfig.auth0Scopes.join(' '),
          'audience': AppConfig.auth0Audience,
          'state': state,
        },
      );

      debugPrint('Redirecting to Auth0: $authUrl');
      debugPrint('Auth URL string: ${authUrl.toString()}');

      // For web, redirect the current window to Auth0
      try {
        web.window.location.href = authUrl.toString();
        debugPrint('Redirect initiated successfully');
      } catch (redirectError) {
        debugPrint('Redirect error: $redirectError');
        // Fallback: try using window.open with _self
        web.window.open(authUrl.toString(), '_self');
      }
    } catch (e) {
      debugPrint('Login error: $e');
      _isAuthenticated.value = false;
      rethrow;
    } finally {
      _isLoading.value = false;
      notifyListeners();
    }
  }

  /// Logout
  Future<void> logout() async {
    try {
      _isLoading.value = true;
      notifyListeners();

      // Clear local state
      _currentUser = null;
      _isAuthenticated.value = false;
    } catch (e) {
      debugPrint('Logout error: $e');
      rethrow;
    } finally {
      _isLoading.value = false;
      notifyListeners();
    }
  }

  /// Handle Auth0 callback
  Future<bool> handleCallback() async {
    try {
      // For web, the callback is handled by the redirect
      // This is a placeholder for future token processing
      debugPrint('Web callback handling - checking authentication state');

      // In a real implementation, you would:
      // 1. Extract the authorization code from the URL
      // 2. Exchange it for tokens
      // 3. Store the tokens securely
      // 4. Load user profile

      return _isAuthenticated.value;
    } catch (e) {
      debugPrint('Callback handling error: $e');
      return false;
    }
  }

  @override
  void dispose() {
    _isAuthenticated.dispose();
    _isLoading.dispose();
    super.dispose();
  }
}
