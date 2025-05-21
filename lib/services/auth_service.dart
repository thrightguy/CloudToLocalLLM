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
  final Auth0 _auth0;
  final FlutterSecureStorage _secureStorage;
  final ValueNotifier<bool> isAuthenticated = ValueNotifier<bool>(false);
  final ValueNotifier<UserProfile?> currentUser = ValueNotifier<UserProfile?>(null);

  AuthService({
    required Auth0 auth0,
    FlutterSecureStorage? secureStorage,
  })  : _auth0 = auth0,
        _secureStorage = secureStorage ?? const FlutterSecureStorage();

  // Secure Storage Keys
  static const String _idTokenKey = 'id_token';
  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';

  // Initialize the service
  Future<void> initialize() async {
    try {
      final credentials = await _auth0.credentialsManager.credentials();
      if (credentials != null) {
        isAuthenticated.value = true;
        currentUser.value = credentials.user;
      }
    } catch (e) {
      debugPrint('Error initializing auth service: $e');
      isAuthenticated.value = false;
      currentUser.value = null;
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
      final credentials = await _auth0.webAuthentication().login();
      await _processLoginResult(credentials);
    } catch (e) {
      // Not a redirect callback or other error
      debugPrint('No Auth0 callback detected: $e');
    }
  }

  Future<bool> _handleAuth0Callback(String code, String state) async {
    try {
      // Exchange code for tokens using the auth code grant flow
      final credentials = await _auth0.webAuthentication().login(
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
    try {
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
    } catch (e) {
      debugPrint('Error processing login result: $e');
      isAuthenticated.value = false;
      currentUser.value = null;
    }
  }

  Future<void> _clearStoredData() async {
    try {
      await _secureStorage.delete(key: _idTokenKey);
      await _secureStorage.delete(key: _accessTokenKey);
      await _secureStorage.delete(key: _refreshTokenKey);
      currentUser.value = null;
    } catch (e) {
      debugPrint('Error clearing stored data: $e');
    }
  }

  // Login methods
  Future<UserProfile?> login() async {
    try {
      final credentials = await _auth0.webAuthentication().login();
      isAuthenticated.value = true;
      currentUser.value = credentials.user;
      return credentials.user;
    } catch (e) {
      debugPrint('Error during login: $e');
      isAuthenticated.value = false;
      currentUser.value = null;
      rethrow;
    }
  }

  Future<UserProfile?> signInWithEmailAndPassword(String email, String password) async {
    try {
      final credentials = await _auth0.api.login(
        usernameOrEmail: email,
        password: password,
        connectionOrRealm: 'Username-Password-Authentication',
      );
      isAuthenticated.value = true;
      currentUser.value = credentials.user;
      return credentials.user;
    } catch (e) {
      debugPrint('Error signing in with email and password: $e');
      isAuthenticated.value = false;
      currentUser.value = null;
      rethrow;
    }
  }

  Future<UserProfile?> createUserWithEmailAndPassword(String email, String password) async {
    try {
      await _auth0.api.signup(
        email: email,
        password: password,
        connection: 'Username-Password-Authentication',
      );
      return signInWithEmailAndPassword(email, password);
    } catch (e) {
      debugPrint('Error creating user with email and password: $e');
      rethrow;
    }
  }

  Future<UserProfile?> signInWithGoogle() async {
    try {
      final credentials = await _auth0.webAuthentication().login(
        parameters: {'connection': 'google-oauth2'},
      );
      isAuthenticated.value = true;
      currentUser.value = credentials.user;
      return credentials.user;
    } catch (e) {
      debugPrint('Error signing in with Google: $e');
      isAuthenticated.value = false;
      currentUser.value = null;
      rethrow;
    }
  }

  Future<UserProfile?> handleRedirectAndLogin(Uri responseUri) async {
    try {
      final credentials = await _auth0.webAuthentication().login(
        redirectUrl: responseUri.toString(),
      );
      isAuthenticated.value = true;
      currentUser.value = credentials.user;
      return credentials.user;
    } catch (e) {
      debugPrint('Error handling redirect and login: $e');
      isAuthenticated.value = false;
      currentUser.value = null;
      rethrow;
    }
  }

  Future<void> logout() async {
    try {
      await _auth0.webAuthentication().logout();
      await _clearStoredData();
      isAuthenticated.value = false;
      currentUser.value = null;
    } catch (e) {
      debugPrint('Error during logout: $e');
      rethrow;
    }
  }

  Future<String?> getAccessToken() async {
    try {
      final credentials = await _auth0.credentialsManager.credentials();
      return credentials?.accessToken;
    } catch (e) {
      debugPrint('Error getting access token: $e');
      return null;
    }
  }

  Future<UserProfile?> getUserProfile() async {
    try {
      final credentials = await _auth0.credentialsManager.credentials();
      if (credentials != null) {
        final userInfo = await http.get(
          Uri.parse('https://${Auth0Options.domain}/userinfo'),
          headers: {'Authorization': 'Bearer ${credentials.accessToken}'},
        );
        if (userInfo.statusCode == 200) {
          final userData = credentials.user;
          return userData;
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error getting user profile: $e');
      return null;
    }
  }

  Future<void> refreshToken() async {
    try {
      final refreshToken = await _secureStorage.read(key: _refreshTokenKey);
      if (refreshToken == null) {
        throw Exception('No refresh token available');
      }
      // Use the web authentication to refresh the token
      final credentials = await _auth0.webAuthentication().login(
        redirectUrl: Auth0Options.redirectUri,
        parameters: {'grant_type': 'refresh_token', 'refresh_token': refreshToken},
      );
      await _processLoginResult(credentials);
    } catch (e) {
      debugPrint('Error refreshing token: $e');
      isAuthenticated.value = false;
      currentUser.value = null;
      rethrow;
    }
  }
}
