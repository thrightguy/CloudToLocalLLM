import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import 'package:auth0_flutter/auth0_flutter.dart';
import 'package:cloudtolocalllm/auth0_options.dart';
// Import the openid client library with an alias for compatibility
import 'package:openid_client/openid_client.dart' as openid;
import 'dart:js' as js;

// Stub classes for backward compatibility with Firebase
class Auth0User {
  final String uid;
  final String? email;
  final String? displayName;

  Auth0User({required this.uid, this.email, this.displayName});
}

class UserCredential {
  final Auth0User? user;

  UserCredential({this.user});
}

class AuthService {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  late Auth0 _auth0;

  // Secure Storage Keys
  static const String _idTokenKey = 'id_token';
  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _userInfoKey = 'user_info';

  // Observable for authentication state
  final ValueNotifier<bool> isAuthenticated = ValueNotifier<bool>(false);
  final ValueNotifier<UserProfile?> currentUser =
      ValueNotifier<UserProfile?>(null);

  AuthService() {
    _auth0 = Auth0(Auth0Options.domain, Auth0Options.clientId);
  }

  // Initialize the service
  Future<void> initialize() async {
    // Check if tokens exist in secure storage
    final idToken = await _secureStorage.read(key: _idTokenKey);
    final accessToken = await _secureStorage.read(key: _accessTokenKey);

    if (idToken != null && accessToken != null) {
      // Load user info if available
      final userInfoStr = await _secureStorage.read(key: _userInfoKey);
      if (userInfoStr != null) {
        try {
          final Map<String, dynamic> userInfoMap = json.decode(userInfoStr);
          // Auth0 Flutter doesn't have a fromMap constructor
          // We'll have to manually populate the user info when needed
          isAuthenticated.value = true;
        } catch (e) {
          debugPrint('Error parsing stored user info: $e');
          // Clear invalid data
          await _clearStoredData();
        }
      }

      // Verify token validity by getting user profile
      try {
        final result = await _auth0.api.userProfile(accessToken: accessToken);
        currentUser.value = result;
        isAuthenticated.value = true;
      } catch (e) {
        debugPrint('Error verifying token: $e');
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
        final code =
            js.context['sessionStorage'].callMethod('getItem', ['auth0_code']);
        final state =
            js.context['sessionStorage'].callMethod('getItem', ['auth0_state']);

        if (code != null && state != null) {
          debugPrint('Found Auth0 callback code, processing...');
          // Exchange the code for tokens
          await _handleAuth0Callback(code.toString(), state.toString());
          // Clear the stored code and state
          js.context['sessionStorage'].callMethod('removeItem', ['auth0_code']);
          js.context['sessionStorage']
              .callMethod('removeItem', ['auth0_state']);
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
      final result = await _auth0.credentialsManager.credentials();
      if (result == null) {
        // Try to exchange the code
        await _auth0.webAuthentication().login(
          redirectUrl: Auth0Options.redirectUri,
          parameters: {'code': code, 'state': state},
        );
        final credentials = await _auth0.credentialsManager.credentials();
        if (credentials == null) {
          debugPrint('Failed to get credentials after code exchange');
          return false;
        }

        // Store tokens
        await _secureStorage.write(
            key: _idTokenKey, value: credentials.idToken);
        await _secureStorage.write(
            key: _accessTokenKey, value: credentials.accessToken);
        if (credentials.refreshToken != null) {
          await _secureStorage.write(
              key: _refreshTokenKey, value: credentials.refreshToken);
        }

        // Get user info
        final userInfo =
            await _auth0.api.userProfile(accessToken: credentials.accessToken);
        await _secureStorage.write(
            key: _userInfoKey, value: json.encode(_userProfileToMap(userInfo)));
        currentUser.value = userInfo;

        isAuthenticated.value = true;
        return true;
      } else {
        // We already have credentials from the redirect flow
        await _processLoginResult(result);
        return true;
      }
    } catch (e) {
      debugPrint('Error handling Auth0 callback: $e');
      return false;
    }
  }

  // Helper method to convert UserProfile to a Map
  Map<String, dynamic> _userProfileToMap(UserProfile profile) {
    // Convert only the fields that actually exist in UserProfile
    final map = <String, dynamic>{
      'sub': profile.sub,
      'name': profile.name,
      'email': profile.email,
    };

    // Add optional fields if they exist
    if (profile.nickname != null) map['nickname'] = profile.nickname;
    if (profile.givenName != null) map['given_name'] = profile.givenName;
    if (profile.familyName != null) map['family_name'] = profile.familyName;
    if (profile.updatedAt != null)
      map['updated_at'] = profile.updatedAt!.toIso8601String();

    return map;
  }

  Future<void> _processLoginResult(Credentials credentials) async {
    // Store tokens
    await _secureStorage.write(key: _idTokenKey, value: credentials.idToken);
    await _secureStorage.write(
        key: _accessTokenKey, value: credentials.accessToken);
    if (credentials.refreshToken != null) {
      await _secureStorage.write(
          key: _refreshTokenKey, value: credentials.refreshToken);
    }

    // Store user info
    if (credentials.user != null) {
      await _secureStorage.write(
          key: _userInfoKey,
          value: json.encode(_userProfileToMap(credentials.user!)));
      currentUser.value = credentials.user;
    } else {
      // If user info is not included in credentials, fetch it
      try {
        final userInfo =
            await _auth0.api.userProfile(accessToken: credentials.accessToken);
        await _secureStorage.write(
            key: _userInfoKey, value: json.encode(_userProfileToMap(userInfo)));
        currentUser.value = userInfo;
      } catch (e) {
        debugPrint('Error fetching user profile after login: $e');
      }
    }

    isAuthenticated.value = true;
  }

  Future<void> _clearStoredData() async {
    await _secureStorage.delete(key: _idTokenKey);
    await _secureStorage.delete(key: _accessTokenKey);
    await _secureStorage.delete(key: _refreshTokenKey);
    await _secureStorage.delete(key: _userInfoKey);
    currentUser.value = null;
  }

  // Login methods

  // Universal login - uses Auth0 universal login
  Future<void> login() async {
    try {
      if (kIsWeb) {
        // Web uses redirect-based authentication
        await _auth0.webAuthentication().login(
          redirectUrl: Auth0Options.redirectUri,
          audience: Auth0Options.audience,
          scopes: {Auth0Options.scope}, // Use a set, not a list
        );
        // The page will redirect to Auth0, then back to the app
        // The initialize() method will handle the callback
      } else {
        // Mobile uses a WebView popup
        final credentials = await _auth0.webAuthentication().login(
          audience: Auth0Options.audience,
          scopes: {Auth0Options.scope}, // Use a set, not a list
        );
        await _processLoginResult(credentials);
      }
    } catch (e) {
      debugPrint('Login error: $e');
      rethrow;
    }
  }

  // For compatibility with existing code
  Future<UserCredential?> signInWithEmailAndPassword(
      String email, String password) async {
    // With Auth0 SDK, we can't directly use password grant from the client
    // We redirect to the Auth0 Universal Login instead
    try {
      await login();
      // Return null for now as we're using redirects
      return null;
    } catch (e) {
      debugPrint('Email/password sign in error: $e');
      return null;
    }
  }

  // For compatibility with existing code
  Future<UserCredential?> signInWithGoogle() async {
    // In Auth0, social logins are handled by the Universal Login
    try {
      await login();
      // Return null for now as we're using redirects
      return null;
    } catch (e) {
      debugPrint('Google sign in error: $e');
      return null;
    }
  }

  // For compatibility with existing code
  Future<UserCredential?> createUserWithEmailAndPassword(
      String email, String password) async {
    // With Auth0, account creation is typically handled by Universal Login
    try {
      await login();
      // Return null for now as we're using redirects
      return null;
    } catch (e) {
      debugPrint('Create user error: $e');
      return null;
    }
  }

  // Sign Out
  Future<void> logout() async {
    try {
      if (kIsWeb) {
        // On web, we need to redirect to Auth0's logout endpoint
        await _auth0.webAuthentication().logout(
              returnTo: Uri.base.origin,
            );
      } else {
        // On mobile, we can use the SDK's logout method
        await _auth0.webAuthentication().logout();
      }

      // Clear stored data
      await _clearStoredData();
      isAuthenticated.value = false;
    } catch (e) {
      debugPrint('Error signing out: $e');
      rethrow;
    }
  }

  // Token management

  Future<String?> getAccessToken() async {
    return await _secureStorage.read(key: _accessTokenKey);
  }

  Future<bool> refreshTokenIfNeeded() async {
    final refreshToken = await _secureStorage.read(key: _refreshTokenKey);
    if (refreshToken == null) {
      return false;
    }

    try {
      // Auth0 Flutter doesn't provide a direct method to refresh tokens using a stored refresh token
      // So we'll use the credentials manager which attempts to refresh tokens automatically
      final accessToken = await getAccessToken();
      if (accessToken == null) return false;

      // Try to validate the current token
      try {
        await _auth0.api.userProfile(accessToken: accessToken);
        // Token is still valid
        return true;
      } catch (e) {
        // Token is invalid, let's try to use the credentials manager
        debugPrint('Access token invalid, attempting refresh');
      }

      // Try to get new credentials from the credentials manager
      // Note: This only works if the SDK has been properly initialized with valid tokens
      final credentials = await _auth0.credentialsManager.credentials();
      if (credentials == null) {
        // If that fails, we'll need to force a new login
        debugPrint('Failed to refresh token automatically');
        return false;
      }

      // Store the new tokens
      await _secureStorage.write(
          key: _accessTokenKey, value: credentials.accessToken);
      await _secureStorage.write(key: _idTokenKey, value: credentials.idToken);

      if (credentials.refreshToken != null) {
        await _secureStorage.write(
            key: _refreshTokenKey, value: credentials.refreshToken!);
      }

      return true;
    } catch (e) {
      debugPrint('Error refreshing token: $e');
      return false;
    }
  }

  // For backward compatibility
  Future<bool> validateToken() async {
    final accessToken = await getAccessToken();
    if (accessToken == null) {
      return false;
    }

    try {
      final userInfo = await _auth0.api.userProfile(accessToken: accessToken);
      currentUser.value = userInfo;
      return true;
    } catch (e) {
      debugPrint('Token validation failed: $e');
      return false;
    }
  }

  // For backward compatibility with your older code
  Future<void> loginWithToken(String token) async {
    await _secureStorage.write(key: _accessTokenKey, value: token);
    try {
      final userInfo = await _auth0.api.userProfile(accessToken: token);
      currentUser.value = userInfo;
      isAuthenticated.value = true;
      await _secureStorage.write(
          key: _userInfoKey, value: json.encode(_userProfileToMap(userInfo)));
    } catch (e) {
      debugPrint('Error validating token: $e');
      isAuthenticated.value = false;
    }
  }

  // Helper method for backward compatibility
  Future<openid.UserInfo?> getUserInfo() async {
    // This is a stub to maintain compatibility with existing code
    // that expects an openid.UserInfo object
    // You'll need to replace usages of this with the new getUserProfile method
    debugPrint('getUserInfo method is deprecated, use currentUser instead');
    return null;
  }

  // New method to get Auth0 user profile
  Future<UserProfile?> getUserProfile() async {
    final accessToken = await getAccessToken();
    if (accessToken == null) {
      return null;
    }

    try {
      final userInfo = await _auth0.api.userProfile(accessToken: accessToken);
      currentUser.value = userInfo;
      return userInfo;
    } catch (e) {
      debugPrint('Error getting user profile: $e');
      return null;
    }
  }

  // For backward compatibility - get the current user
  Auth0User? get currentFirebaseUser {
    if (currentUser.value == null) return null;
    return Auth0User(
      uid: currentUser.value!.sub,
      email: currentUser.value!.email,
      displayName: currentUser.value!.name,
    );
  }

  // Handle redirect from auth server
  Future<Auth0User?> handleRedirectAndLogin(Uri responseUri) async {
    // This is a backward compatibility method
    // Auth0 handles callbacks differently
    debugPrint(
        'handleRedirectAndLogin called, but Auth0 handles callbacks differently');

    // Try to extract code and state from the URI
    final queryParams = responseUri.queryParameters;
    final code = queryParams['code'];
    final state = queryParams['state'];

    if (code != null && state != null) {
      final success = await _handleAuth0Callback(code, state);
      if (success) {
        return currentFirebaseUser;
      }
    }

    return null;
  }
}
