import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:auth0_flutter/auth0_flutter.dart' as auth0;

// Conditional imports for web-specific functionality
import 'auth_service_stub.dart' if (dart.library.html) 'auth_service_web.dart'
    as platform_auth;

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
  final ValueNotifier<UserProfile?> currentUser =
      ValueNotifier<UserProfile?>(null);

  AuthService(this._auth0) : _credentialsManager = _auth0.credentialsManager;

  // Initialize the service
  Future<void> initialize() async {
    if (kIsWeb) {
      // For web platform, use simplified initialization
      try {
        platform_auth.PlatformAuth.handleWebCallback();
        debugPrint('Web auth callback handled');
      } catch (e) {
        debugPrint('No Auth0 callback detected: $e');
      }
    } else {
      // For mobile/desktop platforms, use credentials manager
      try {
        final credentials = await _credentialsManager.credentials();
        isAuthenticated.value = true;
        currentUser.value = UserProfile.fromAuth0User(credentials.user);
      } catch (e) {
        debugPrint('Error initializing auth service: $e');
      }
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

  Future<UserProfile> signInWithEmailAndPassword(
      String email, String password) async {
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

  Future<UserProfile> createUserWithEmailAndPassword(
      String email, String password) async {
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
