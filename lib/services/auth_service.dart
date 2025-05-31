import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:auth0_flutter/auth0_flutter.dart';
import '../config/app_config.dart';
import '../models/user_model.dart';

/// Authentication service using Auth0
class AuthService extends ChangeNotifier {
  late final Auth0 _auth0;
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
    _auth0 = Auth0(AppConfig.auth0Domain, AppConfig.auth0ClientId);
    _checkAuthenticationStatus();
  }

  /// Check if user is already authenticated
  Future<void> _checkAuthenticationStatus() async {
    try {
      _isLoading.value = true;

      // Check if we have stored credentials
      final hasValidCredentials =
          await _auth0.credentialsManager.hasValidCredentials();

      if (hasValidCredentials) {
        _credentials = await _auth0.credentialsManager.credentials();
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

      _credentials = await _auth0.webAuthentication().login();

      if (_credentials != null) {
        // Store credentials securely
        await _auth0.credentialsManager.storeCredentials(_credentials!);

        // Load user profile
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

      // Clear stored credentials
      await _auth0.credentialsManager.clearCredentials();

      // Logout from Auth0
      await _auth0.webAuthentication().logout();

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
    if (_credentials?.accessToken == null) return;

    try {
      final userProfile = await _auth0.api.userProfile(
        accessToken: _credentials!.accessToken,
      );
      _currentUser = UserModel.fromAuth0Profile(userProfile);
    } catch (e) {
      debugPrint('Error loading user profile: $e');
    }
  }

  /// Refresh access token
  Future<void> refreshToken() async {
    try {
      _credentials = await _auth0.credentialsManager.credentials();
      notifyListeners();
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
