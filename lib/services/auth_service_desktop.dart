import 'package:flutter/foundation.dart';
import 'package:flutter_appauth/flutter_appauth.dart';
import '../config/app_config.dart';
import '../models/user_model.dart';

/// Desktop-specific authentication service using Flutter AppAuth
class AuthServiceDesktop extends ChangeNotifier {
  // Flutter AppAuth client and credentials
  final FlutterAppAuth _appAuth = const FlutterAppAuth();
  AuthorizationTokenResponse? _tokenResponse;
  String? _accessToken;
  String? _idToken;

  final ValueNotifier<bool> _isAuthenticated = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _isLoading = ValueNotifier<bool>(false);
  UserModel? _currentUser;

  // Getters
  ValueNotifier<bool> get isAuthenticated => _isAuthenticated;
  ValueNotifier<bool> get isLoading => _isLoading;
  UserModel? get currentUser => _currentUser;
  String? get accessToken => _accessToken;

  // Legacy compatibility getter for existing code
  dynamic get credential => _tokenResponse;

  AuthServiceDesktop() {
    _initialize();
  }

  /// Initialize Flutter AppAuth client with Auth0
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

  /// Login using Authorization Code Flow with PKCE
  Future<void> login() async {
    try {
      _isLoading.value = true;
      notifyListeners();

      // Use flutter_appauth for Auth0 authentication
      _tokenResponse = await _appAuth.authorizeAndExchangeCode(
        AuthorizationTokenRequest(
          AppConfig.auth0ClientId,
          AppConfig.auth0DesktopRedirectUri,
          discoveryUrl:
              '${AppConfig.auth0Issuer}.well-known/openid-configuration',
          scopes: AppConfig.auth0Scopes,
        ),
      );

      if (_tokenResponse != null) {
        _accessToken = _tokenResponse!.accessToken;
        _idToken = _tokenResponse!.idToken;

        // Token expiry is handled by flutter_appauth internally

        await _loadUserProfile();
        _isAuthenticated.value = true;
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
      _tokenResponse = null;
      _accessToken = null;
      _idToken = null;
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

  /// Load user profile from ID token
  Future<void> _loadUserProfile() async {
    try {
      if (_idToken != null) {
        // For now, create a basic user model
        // In a production app, you would decode the JWT token to extract claims
        // or make an API call to the Auth0 userinfo endpoint

        _currentUser = UserModel(
          id: 'user_id', // Would be extracted from JWT claims
          email: 'user@example.com', // Would be extracted from JWT claims
          name: 'User Name', // Would be extracted from JWT claims
          picture: null,
          nickname: null,
          emailVerified: DateTime.now(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        debugPrint('User profile loaded: ${_currentUser?.email}');
      }
    } catch (e) {
      debugPrint('Error loading user profile: $e');
    }
  }

  /// Handle Auth0 callback
  Future<bool> handleCallback() async {
    try {
      // Desktop apps using flutter_appauth handle callbacks automatically
      // This method is kept for compatibility but may not be needed
      debugPrint('Desktop callback handling - checking authentication state');

      // Check if we have valid tokens
      if (_tokenResponse != null && _accessToken != null) {
        await _loadUserProfile();
        _isAuthenticated.value = true;
        notifyListeners();
        return true;
      }

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
