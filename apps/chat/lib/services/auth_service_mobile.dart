import 'package:flutter/foundation.dart';
import '../config/app_config.dart';
import '../models/user_model.dart';

// Mock types for web/desktop builds (auth0_flutter is mobile-only)
class Auth0 {
  Auth0(String domain, String clientId);
  late final CredentialsManager credentialsManager;
  late final WebAuthentication Function({required String scheme})
      webAuthentication;
  late final Api api;
}

class CredentialsManager {
  Future<bool> hasValidCredentials() async => false;
  Future<Credentials> credentials() async => throw UnimplementedError();
  Future<void> storeCredentials(Credentials credentials) async {}
  Future<void> clearCredentials() async {}
  Future<void> enableBiometrics({
    required String title,
    required String subtitle,
    required String description,
    required String negativeButtonText,
  }) async {}
}

class WebAuthentication {
  Future<Credentials> login({String? audience, Set<String>? scopes}) async =>
      throw UnimplementedError();
  Future<void> logout() async {}
}

class Api {
  Future<UserProfile> userInfo({required String accessToken}) async =>
      throw UnimplementedError();
}

class Credentials {
  final String accessToken;
  Credentials({required this.accessToken});
}

class UserProfile {
  final String sub;
  final String? email;
  final String? name;
  final String? pictureUrl;
  final String? nickname;
  final bool isEmailVerified;

  UserProfile({
    required this.sub,
    this.email,
    this.name,
    this.pictureUrl,
    this.nickname,
    this.isEmailVerified = false,
  });
}

/// Mobile-specific authentication service using Auth0 Flutter SDK
/// Supports iOS and Android with native authentication flows
///
/// NOTE: This is currently a placeholder implementation with mock types.
/// When building for mobile platforms, replace the mock imports above with:
/// import 'package:auth0_flutter/auth0_flutter.dart';
/// and add auth0_flutter to pubspec.yaml dependencies.
class AuthServiceMobile extends ChangeNotifier {
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

  AuthServiceMobile() {
    _initialize();
  }

  /// Initialize Auth0 Flutter SDK
  Future<void> _initialize() async {
    try {
      _isLoading.value = true;
      notifyListeners();

      // Initialize Auth0 with domain and client ID
      _auth0 = Auth0(
        AppConfig.auth0Domain,
        AppConfig.auth0ClientId,
      );

      // Check for existing authentication
      await _checkAuthenticationStatus();
    } catch (e) {
      debugPrint('Error initializing Auth0 Mobile: $e');
    } finally {
      _isLoading.value = false;
      notifyListeners();
    }
  }

  /// Check current authentication status
  Future<void> _checkAuthenticationStatus() async {
    try {
      // Check if we have stored credentials
      final hasValidCredentials =
          await _auth0.credentialsManager.hasValidCredentials();

      if (hasValidCredentials) {
        // Retrieve stored credentials
        _credentials = await _auth0.credentialsManager.credentials();
        await _loadUserProfile();
        _isAuthenticated.value = true;
      } else {
        _isAuthenticated.value = false;
      }
    } catch (e) {
      debugPrint('Error checking authentication status: $e');
      _isAuthenticated.value = false;
    }
  }

  /// Login using Auth0 Universal Login (recommended for mobile)
  Future<void> login() async {
    try {
      _isLoading.value = true;
      notifyListeners();

      // Use Auth0 Universal Login with native browser
      _credentials = await _auth0.webAuthentication(scheme: 'app').login(
            audience: AppConfig.auth0Audience,
            scopes: AppConfig.auth0Scopes.toSet(),
          );

      if (_credentials != null) {
        // Store credentials securely
        await _auth0.credentialsManager.storeCredentials(_credentials!);

        await _loadUserProfile();
        _isAuthenticated.value = true;
      }
    } catch (e) {
      debugPrint('Mobile login error: $e');
      _isAuthenticated.value = false;
      rethrow;
    } finally {
      _isLoading.value = false;
      notifyListeners();
    }
  }

  /// Login with biometric authentication (if available)
  Future<void> loginWithBiometrics() async {
    try {
      _isLoading.value = true;
      notifyListeners();

      // Enable biometric authentication
      await _auth0.credentialsManager.enableBiometrics(
        title: 'Authenticate with Biometrics',
        subtitle: 'Use your fingerprint or face to access CloudToLocalLLM',
        description:
            'Biometric authentication provides secure and convenient access',
        negativeButtonText: 'Cancel',
      );

      // Retrieve credentials with biometric prompt
      _credentials = await _auth0.credentialsManager.credentials();

      if (_credentials != null) {
        await _loadUserProfile();
        _isAuthenticated.value = true;
      }
    } catch (e) {
      debugPrint('Biometric login error: $e');
      _isAuthenticated.value = false;
      rethrow;
    } finally {
      _isLoading.value = false;
      notifyListeners();
    }
  }

  /// Logout and clear stored credentials
  Future<void> logout() async {
    try {
      _isLoading.value = true;
      notifyListeners();

      // Logout from Auth0 and clear browser session
      await _auth0.webAuthentication(scheme: 'app').logout();

      // Clear stored credentials
      await _auth0.credentialsManager.clearCredentials();

      // Clear local state
      _credentials = null;
      _currentUser = null;
      _isAuthenticated.value = false;
    } catch (e) {
      debugPrint('Mobile logout error: $e');
      rethrow;
    } finally {
      _isLoading.value = false;
      notifyListeners();
    }
  }

  /// Refresh access token if needed
  Future<void> refreshTokenIfNeeded() async {
    try {
      if (_credentials != null && _credentials!.accessToken.isNotEmpty) {
        // Check if token needs refresh (Auth0 SDK handles this automatically)
        final hasValidCredentials =
            await _auth0.credentialsManager.hasValidCredentials();

        if (!hasValidCredentials) {
          // Token expired, try to refresh
          _credentials = await _auth0.credentialsManager.credentials();
          await _loadUserProfile();
        }
      }
    } catch (e) {
      debugPrint('Token refresh error: $e');
      // If refresh fails, user needs to login again
      await logout();
    }
  }

  /// Load user profile from Auth0 Management API
  Future<void> _loadUserProfile() async {
    try {
      if (_credentials?.accessToken != null) {
        // Get user info from Auth0
        final userProfile =
            await _auth0.api.userInfo(accessToken: _credentials!.accessToken);

        // Create user model from Auth0 profile
        _currentUser = UserModel(
          id: userProfile.sub,
          email: userProfile.email ?? '',
          name: userProfile.name ?? '',
          picture: userProfile.pictureUrl?.toString(),
          nickname: userProfile.nickname,
          emailVerified: userProfile.isEmailVerified ? DateTime.now() : null,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
      }
    } catch (e) {
      debugPrint('Error loading user profile: $e');
    }
  }

  /// Handle deep link callback (for custom URL schemes)
  Future<bool> handleCallback() async {
    try {
      // For mobile, deep links are handled automatically by the Auth0 SDK
      // This method is here for interface compatibility
      debugPrint('Mobile callback handling - checking authentication state');

      // Check current authentication status
      await _checkAuthenticationStatus();

      return _isAuthenticated.value;
    } catch (e) {
      debugPrint('Mobile callback handling error: $e');
      return false;
    }
  }

  /// Check if biometric authentication is available
  Future<bool> isBiometricAvailable() async {
    try {
      // This would need to be implemented based on platform capabilities
      // For now, return false as a placeholder
      return false;
    } catch (e) {
      debugPrint('Biometric availability check error: $e');
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
