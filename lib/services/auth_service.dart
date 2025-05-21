import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import 'package:cloudtolocalllm/auth0_options.dart';
import 'package:auth0_flutter/auth0_flutter.dart';
import 'dart:js' as js;
import 'package:http/http.dart' as http;

// Auth0 User Profile
class Auth0UserProfile {
  final String sub;
  final String? email;
  final String? name;

  Auth0UserProfile({
    required this.sub,
    this.email,
    this.name,
  });

  factory Auth0UserProfile.fromJson(Map<String, dynamic> json) {
    return Auth0UserProfile(
      sub: json['sub'],
      email: json['email'],
      name: json['name'],
    );
  }
}

class AuthService {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  late final Auth0 auth0;

  // Secure Storage Keys
  static const String _idTokenKey = 'id_token';
  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';

  // Observable for authentication state
  final ValueNotifier<bool> isAuthenticated = ValueNotifier<bool>(false);
  final ValueNotifier<Map<String, dynamic>?> currentUser = ValueNotifier<Map<String, dynamic>?>(null);

  AuthService() {
    auth0 = Auth0(
      Auth0Options.domain,
      Auth0Options.clientId,
    );
  }

  // Initialize the service
  Future<void> initialize() async {
    // Check if tokens exist in secure storage
    final idToken = await _secureStorage.read(key: _idTokenKey);
    final accessToken = await _secureStorage.read(key: _accessTokenKey);

    if (idToken != null && accessToken != null) {
      // Validate token by getting user profile
      try {
        final userInfo = await getUserProfile();
        if (userInfo != null) {
          isAuthenticated.value = true;
          currentUser.value = userInfo;
        } else {
          // Token is invalid, clear storage
          await _clearStoredData();
          isAuthenticated.value = false;
        }
      } catch (e) {
        // Token is invalid, clear storage
        await _clearStoredData();
        isAuthenticated.value = false;
      }
    } else {
      isAuthenticated.value = false;
    }

    // On web, check for Auth0 redirect handling
    if (kIsWeb) {
      try {
        // Check for session storage items set by the callback page
        final code = js.context['sessionStorage'].callMethod('getItem', ['auth0_code']);
        final state = js.context['sessionStorage'].callMethod('getItem', ['auth0_state']);

        if (code != null && state != null) {
          debugPrint('Found Auth0 callback code, processing...');
          // Exchange the code for tokens
          await _handleAuth0Callback(code.toString(), state.toString());
          // Clear the stored code and state
          js.context['sessionStorage'].callMethod('removeItem', ['auth0_code']);
          js.context['sessionStorage'].callMethod('removeItem', ['auth0_state']);
        } else {
          // Try standard web auth handling
          await _checkWebAuth();
        }
      } catch (e) {
        debugPrint('Error in web auth initialization: $e');
      }
    }
  }

  Future<void> _checkWebAuth() async {
    try {
      // Check for Auth0 redirect result
      final credentials = await auth0.webAuthentication().login();
      await _processLoginResult(credentials);
    } catch (e) {
      // Not a redirect callback or other error
      debugPrint('No Auth0 callback detected: $e');
    }
  }

  Future<bool> _handleAuth0Callback(String code, String state) async {
    try {
      // Exchange code for tokens using the auth code grant flow
      final credentials = await auth0.webAuthentication().login(
        redirectUrl: Auth0Options.redirectUri,
        parameters: {'code': code, 'state': state},
      );
      await _processLoginResult(credentials);
      return true;
    } catch (e) {
      debugPrint('Error handling Auth0 callback: $e');
      return false;
    }
  }

  Future<void> _processLoginResult(Credentials credentials) async {
    // Store tokens
    await _secureStorage.write(key: _idTokenKey, value: credentials.idToken);
    await _secureStorage.write(key: _accessTokenKey, value: credentials.accessToken);
    if (credentials.refreshToken != null) {
      await _secureStorage.write(key: _refreshTokenKey, value: credentials.refreshToken);
    }

    // Get user info
    final userInfo = await getUserProfile();
    if (userInfo != null) {
      currentUser.value = userInfo;
    }

    isAuthenticated.value = true;
  }

  Future<void> _clearStoredData() async {
    await _secureStorage.delete(key: _idTokenKey);
    await _secureStorage.delete(key: _accessTokenKey);
    await _secureStorage.delete(key: _refreshTokenKey);
    currentUser.value = null;
  }

  // Login methods
  Future<void> login() async {
    try {
      if (kIsWeb) {
        // Web uses redirect-based authentication
        await auth0.webAuthentication().login(
          redirectUrl: Auth0Options.redirectUri,
        );
        // The page will redirect to Auth0, then back to the app
        // The initialize() method will handle the callback
      } else {
        // Mobile uses a WebView popup
        await auth0.webAuthentication().login();
      }
    } catch (e) {
      debugPrint('Login error: $e');
      rethrow;
    }
  }

  Future<void> signInWithEmailAndPassword(String email, String password) async {
    try {
      await login();
    } catch (e) {
      debugPrint('Email/password sign in error: $e');
      rethrow;
    }
  }

  Future<void> signupWithEmailAndPassword(String email, String password) async {
    try {
      await login();
    } catch (e) {
      debugPrint('Create user error: $e');
      rethrow;
    }
  }

  Future<void> refreshToken() async {
    try {
      final refreshToken = await _secureStorage.read(key: _refreshTokenKey);
      if (refreshToken == null) {
        throw Exception('Refresh token not found');
      }

      // Use the web authentication to refresh the token
      final credentials = await auth0.webAuthentication().login(
        redirectUrl: Auth0Options.redirectUri,
        parameters: {'grant_type': 'refresh_token', 'refresh_token': refreshToken},
      );
      await _processLoginResult(credentials);
    } catch (e) {
      debugPrint('Error refreshing token: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getUserProfile() async {
    try {
      final accessToken = await _secureStorage.read(key: _accessTokenKey);
      if (accessToken == null) {
        return null;
      }

      // Use the Auth0 Management API to get user info
      final response = await http.get(
        Uri.parse('https://${Auth0Options.domain}/userinfo'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        debugPrint('Error getting user info: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('Error getting user profile: $e');
      return null;
    }
  }

  Future<void> logout() async {
    try {
      if (kIsWeb) {
        // On web, we need to redirect to Auth0's logout endpoint
        await auth0.webAuthentication().logout(
          returnTo: Uri.base.origin,
        );
      } else {
        // On mobile, we can use the SDK's logout method
        await auth0.webAuthentication().logout();
      }

      // Clear stored data
      await _clearStoredData();
      isAuthenticated.value = false;
    } catch (e) {
      debugPrint('Error signing out: $e');
      rethrow;
    }
  }

  Future<String?> getAccessToken() async {
    return await _secureStorage.read(key: _accessTokenKey);
  }
}
