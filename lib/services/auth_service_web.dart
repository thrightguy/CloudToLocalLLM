import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;
import '../config/app_config.dart';
import '../models/user_model.dart';
import 'auth_logger.dart';

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
    AuthLogger.initialize();
    AuthLogger.info('AuthServiceWeb constructor called');
    _initialize();
  }

  /// Initialize authentication service
  Future<void> _initialize() async {
    AuthLogger.info('Web authentication service initializing');
    try {
      _isLoading.value = true;
      notifyListeners();
      AuthLogger.debug('Loading state set to true during initialization');

      // Check for existing authentication
      await _checkAuthenticationStatus();
      AuthLogger.info('Authentication service initialized successfully');
    } catch (e) {
      AuthLogger.error('Error initializing Auth0', {'error': e.toString()});
    } finally {
      _isLoading.value = false;
      notifyListeners();
      AuthLogger.debug('Loading state set to false after initialization');
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
    AuthLogger.info('🔐 Web login method called');
    AuthLogger.logAuthStateChange(false, 'Login attempt started');

    try {
      _isLoading.value = true;
      notifyListeners();
      AuthLogger.debug('🔐 Loading state set to true');

      // For web, redirect directly to Auth0 login page
      final redirectUri = AppConfig.auth0WebRedirectUri;
      final state = DateTime.now().millisecondsSinceEpoch.toString();

      AuthLogger.info('🔐 Building Auth0 URL', {
        'redirectUri': redirectUri,
        'state': state,
        'domain': AppConfig.auth0Domain,
        'clientId': AppConfig.auth0ClientId,
        'scopes': AppConfig.auth0Scopes,
      });

      final authUrl = Uri.https(
        AppConfig.auth0Domain,
        '/authorize',
        {
          'client_id': AppConfig.auth0ClientId,
          'redirect_uri': redirectUri,
          'response_type': 'code',
          'scope': AppConfig.auth0Scopes.join(' '),
          'state': state,
        },
      );

      AuthLogger.info('🔐 Auth0 URL constructed', {
        'url': authUrl.toString(),
        'length': authUrl.toString().length,
      });

      // For web, redirect the current window to Auth0
      try {
        AuthLogger.info('🔐 Attempting window.location.href redirect');
        web.window.location.href = authUrl.toString();
        AuthLogger.info('🔐 Redirect initiated successfully');

        // Add a small delay to ensure the redirect happens
        await Future.delayed(const Duration(milliseconds: 100));
        AuthLogger.warning(
            '🔐 Still executing after redirect - this should not happen');
      } catch (redirectError) {
        AuthLogger.error('🔐 Primary redirect failed', {
          'error': redirectError.toString(),
          'errorType': redirectError.runtimeType.toString(),
        });

        // Fallback: try using window.open with _self
        try {
          AuthLogger.info('🔐 Attempting fallback redirect with window.open');
          web.window.open(authUrl.toString(), '_self');
          AuthLogger.info('🔐 Fallback redirect initiated');
        } catch (fallbackError) {
          AuthLogger.error('🔐 Fallback redirect also failed', {
            'error': fallbackError.toString(),
            'errorType': fallbackError.runtimeType.toString(),
          });
          throw 'Both redirect methods failed: $redirectError, $fallbackError';
        }
      }
    } catch (e) {
      AuthLogger.error('🔐 Login error', {
        'error': e.toString(),
        'errorType': e.runtimeType.toString(),
        'stackTrace': StackTrace.current.toString(),
      });
      _isAuthenticated.value = false;
      AuthLogger.logAuthStateChange(false, 'Login failed with error');
      rethrow;
    } finally {
      _isLoading.value = false;
      notifyListeners();
      AuthLogger.debug('🔐 Login method finally block executed');
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
      AuthLogger.info('🔐 Web callback handling started');

      // Get current URL parameters
      final uri = Uri.parse(web.window.location.href);
      AuthLogger.info('🔐 Current URL', {'url': uri.toString()});

      // Check for error parameters
      if (uri.queryParameters.containsKey('error')) {
        final error = uri.queryParameters['error'];
        final errorDescription = uri.queryParameters['error_description'];
        AuthLogger.error('🔐 Auth0 callback error', {
          'error': error,
          'error_description': errorDescription,
        });
        return false;
      }

      // Check for authorization code
      if (uri.queryParameters.containsKey('code')) {
        final code = uri.queryParameters['code'];
        final state = uri.queryParameters['state'];

        AuthLogger.info('🔐 Authorization code received', {
          'code': code != null ? '${code.substring(0, 10)}...' : 'null',
          'state': state,
        });

        // For now, just mark as authenticated
        // In a full implementation, you would exchange the code for tokens
        _isAuthenticated.value = true;
        AuthLogger.logAuthStateChange(true, 'Authorization code received');

        // Clear the URL parameters
        web.window.history.replaceState(null, '', '/');

        return true;
      }

      AuthLogger.warning('🔐 No authorization code or error in callback');
      return false;
    } catch (e) {
      AuthLogger.error('🔐 Callback handling error', {
        'error': e.toString(),
        'stackTrace': StackTrace.current.toString(),
      });
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
