import 'package:flutter/foundation.dart';
import 'package:auth0_flutter/auth0_flutter.dart';
import 'package:auth0_flutter/auth0_flutter_web.dart';
import '../config/app_config.dart';
import '../models/user_model.dart';

/// Authentication service using Auth0
class AuthService extends ChangeNotifier {
  late final Auth0Web _auth0;
  final ValueNotifier<bool> _isAuthenticated = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _isLoading = ValueNotifier<bool>(false);
  UserModel? _currentUser;
  Credentials? _credentials;

  // Getters
  ValueNotifier<bool> get isAuthenticated => _isAuthenticated;
  ValueNotifier<bool> get isLoading => _isLoading;
  UserModel? get currentUser => _currentUser;
  Credentials? get credentials => _credentials;

  AuthService() {
    _initializeAuth0();
  }

  /// Initialize Auth0
  void _initializeAuth0() {
    _auth0 = Auth0Web(AppConfig.auth0Domain, AppConfig.auth0ClientId);
    _checkAuthenticationStatus();
  }

  /// Check if user is already authenticated
  Future<void> _checkAuthenticationStatus() async {
    try {
      _isLoading.value = true;

      // For web, check if we have credentials from onLoad
      final credentials = await _auth0.onLoad();
      if (credentials != null) {
        _credentials = credentials;
        await _loadUserProfile();
        _isAuthenticated.value = true;
      }
    } catch (e) {
      debugPrint('Error checking authentication status: $e');
      _isAuthenticated.value = false;
    } finally {
      _isLoading.value = false;
      notifyListeners();
    }
  }

  /// Login with Auth0
  Future<void> login() async {
    try {
      _isLoading.value = true;
      notifyListeners();

      // Use Auth0Web loginWithRedirect method
      await _auth0.loginWithRedirect(
        redirectUrl: AppConfig.auth0RedirectUri,
        audience: AppConfig.auth0Audience,
        scopes: {'openid', 'profile', 'email'},
      );

      // Note: After redirect, the user will be redirected back to the callback URL
      // The actual credential handling happens in the callback processing
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

      // Logout from Auth0 with return URL
      await _auth0.logout(returnToUrl: AppConfig.appUrl);

      // Clear local state
      _credentials = null;
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

  /// Load user profile from Auth0
  Future<void> _loadUserProfile() async {
    if (_credentials?.user == null) return;

    try {
      // For Auth0Web, user profile is available directly from credentials
      _currentUser = UserModel.fromAuth0Profile(_credentials!.user);
    } catch (e) {
      debugPrint('Error loading user profile: $e');
    }
  }

  /// Handle Auth0 callback (for web)
  Future<bool> handleCallback() async {
    if (!kIsWeb) return false;

    try {
      _isLoading.value = true;
      notifyListeners();

      // For Auth0Web, use onLoad to handle the callback
      final credentials = await _auth0.onLoad();

      if (credentials != null) {
        _credentials = credentials;
        await _loadUserProfile();
        _isAuthenticated.value = true;
        return true;
      }
    } catch (e) {
      debugPrint('Callback processing error: $e');
      _isAuthenticated.value = false;
    } finally {
      _isLoading.value = false;
      notifyListeners();
    }

    return false;
  }

  /// Refresh access token
  Future<void> refreshToken() async {
    try {
      // For Auth0Web, credentials are managed automatically
      // We can try to get fresh credentials using onLoad
      final credentials = await _auth0.onLoad();
      if (credentials != null) {
        _credentials = credentials;
        notifyListeners();
      } else {
        // If no credentials available, logout user
        await logout();
      }
    } catch (e) {
      debugPrint('Error refreshing token: $e');
      // If refresh fails, logout user
      await logout();
    }
  }

  @override
  void dispose() {
    _isAuthenticated.dispose();
    _isLoading.dispose();
    super.dispose();
  }
}
