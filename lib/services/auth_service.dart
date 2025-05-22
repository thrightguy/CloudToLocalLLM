import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:auth0_flutter/auth0_flutter.dart' as auth0;
import 'package:cloudtolocalllm/auth0_options.dart';
import 'package:web/web.dart' as web;

// User Profile class
class UserProfile {
  final String sub;
  final String? email;
  final String? name;

  UserProfile({
    required this.sub,
    this.email,
    this.name,
  });

  factory UserProfile.fromAuth0User(auth0.UserProfile user) {
    return UserProfile(
      sub: user.sub,
      email: user.email,
      name: user.name,
    );
  }
}

class AuthService {
  final auth0.Auth0 _auth0;
  final auth0.CredentialsManager _credentialsManager;
  final ValueNotifier<bool> isAuthenticated = ValueNotifier<bool>(false);
  final ValueNotifier<UserProfile?> currentUser = ValueNotifier<UserProfile?>(null);

  AuthService(this._auth0) : _credentialsManager = _auth0.credentialsManager;

  // Initialize the service
  Future<void> initialize() async {
    try {
      final credentials = await _credentialsManager.credentials();
      isAuthenticated.value = true;
      currentUser.value = UserProfile.fromAuth0User(credentials.user);
    } catch (e) {
      debugPrint('Error initializing auth service: $e');
    }

    // On web, check for Auth0 redirect handling
    if (kIsWeb) {
      try {
        // Check for session storage items set by the callback page
        final storage = web.window.sessionStorage;
        final code = storage.getItem('auth0_code');
        final state = storage.getItem('auth0_state');

        if (code != null && state != null) {
          debugPrint('Found Auth0 callback code, processing...');
          // Exchange the code for tokens
          await _handleAuth0Callback(code.toString(), state.toString());
          // Clear the stored code and state
          storage.removeItem('auth0_code');
          storage.removeItem('auth0_state');
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

  Future<void> _processLoginResult(auth0.Credentials credentials) async {
    try {
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

  Future<UserProfile?> getUserProfile() async {
    try {
      final credentials = await _credentialsManager.credentials();
      return UserProfile.fromAuth0User(credentials.user);
    } catch (e) {
      debugPrint('Error getting user profile: $e');
      return null;
    }
  }

  Future<void> refreshToken() async {
    try {
      await _credentialsManager.credentials();
    } catch (e) {
      debugPrint('Error refreshing token: $e');
    }
  }

  // Login methods
  Future<UserProfile> login() async {
    try {
      final credentials = await _auth0.webAuthentication().login();
      isAuthenticated.value = true;
      final user = UserProfile.fromAuth0User(credentials.user);
      currentUser.value = user;
      return user;
    } catch (e) {
      debugPrint('Error during login: $e');
      rethrow;
    }
  }

  Future<UserProfile> signInWithEmailAndPassword(String email, String password) async {
    try {
      final credentials = await _auth0.api.login(
        usernameOrEmail: email,
        password: password,
        connectionOrRealm: 'Username-Password-Authentication',
      );
      isAuthenticated.value = true;
      final user = UserProfile.fromAuth0User(credentials.user);
      currentUser.value = user;
      return user;
    } catch (e) {
      debugPrint('Error signing in with email and password: $e');
      rethrow;
    }
  }

  Future<UserProfile> signInWithGoogle() async {
    try {
      final credentials = await _auth0.webAuthentication().login(
        parameters: {'connection': 'google-oauth2'},
      );
      isAuthenticated.value = true;
      final user = UserProfile.fromAuth0User(credentials.user);
      currentUser.value = user;
      return user;
    } catch (e) {
      debugPrint('Error signing in with Google: $e');
      rethrow;
    }
  }

  Future<UserProfile> handleRedirectAndLogin(Uri responseUri) async {
    try {
      final credentials = await _auth0.webAuthentication().login(
        redirectUrl: responseUri.toString(),
      );
      isAuthenticated.value = true;
      final user = UserProfile.fromAuth0User(credentials.user);
      currentUser.value = user;
      return user;
    } catch (e) {
      debugPrint('Error handling redirect and login: $e');
      rethrow;
    }
  }

  Future<void> logout() async {
    try {
      await _auth0.webAuthentication().logout();
      isAuthenticated.value = false;
      currentUser.value = null;
    } catch (e) {
      debugPrint('Error during logout: $e');
    }
  }

  Future<String?> getAccessToken() async {
    try {
      final credentials = await _credentialsManager.credentials();
      return credentials.accessToken;
    } catch (e) {
      debugPrint('Error getting access token: $e');
      return null;
    }
  }

  Future<UserProfile> createUserWithEmailAndPassword(String email, String password) async {
    try {
      await _auth0.api.signup(
        email: email,
        password: password,
        connection: 'Username-Password-Authentication',
      );
      
      // After signup, automatically sign in the user
      final loginCredentials = await _auth0.api.login(
        usernameOrEmail: email,
        password: password,
        connectionOrRealm: 'Username-Password-Authentication',
      );
      
      isAuthenticated.value = true;
      final user = UserProfile.fromAuth0User(loginCredentials.user);
      currentUser.value = user;
      return user;
    } catch (e) {
      debugPrint('Error creating user with email and password: $e');
      rethrow;
    }
  }
}
