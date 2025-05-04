import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/app_config.dart';
import '../models/user.dart';

class AuthService {
  final String baseUrl;
  User? _currentUser;
  String? _token;
  final ValueNotifier<bool> isAuthenticated = ValueNotifier<bool>(false);

  // For PKCE Auth0 flow
  String? _codeVerifier;
  String? _codeChallenge;
  String? _state;
  Timer? _authTimer;

  AuthService({String? baseUrl}) : baseUrl = baseUrl ?? AppConfig.cloudBaseUrl;

  // Get the current user
  User? get currentUser => _currentUser;

  // Get the authentication token
  String? getToken() => _token;

  // For backward compatibility
  String? get token => _token;

  // Initialize the auth service
  Future<void> initialize() async {
    await _loadStoredAuth();
  }

  // Generate random string for PKCE
  String _generateRandomString(int length) {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';
    final random = Random.secure();
    return List.generate(length, (_) => chars[random.nextInt(chars.length)])
        .join();
  }

  // Generate code challenge from verifier (for PKCE)
  String _generateCodeChallenge(String verifier) {
    final bytes = utf8.encode(verifier);
    final digest = sha256.convert(bytes);
    return base64Url
        .encode(digest.bytes)
        .replaceAll('+', '-')
        .replaceAll('/', '_')
        .replaceAll('=', '');
  }

  // Get the auth URL for Auth0
  String getAuth0Url() {
    // Generate PKCE code verifier and challenge
    _codeVerifier = _generateRandomString(96);
    _codeChallenge = _generateCodeChallenge(_codeVerifier!);

    // Generate state for CSRF protection
    _state = _generateRandomString(32);

    // Save state for validation
    _saveAuthState(_state!);

    final redirectUri = AppConfig.auth0RedirectUri;
    final auth0Domain = AppConfig.auth0Domain;
    final clientId = AppConfig.auth0ClientId;
    final audience = AppConfig.auth0Audience;

    final auth0Url = Uri.https(auth0Domain, '/authorize', {
      'client_id': clientId,
      'redirect_uri': redirectUri,
      'response_type': 'code',
      'scope': 'openid profile email',
      'audience': audience,
      'state': _state,
      'code_challenge': _codeChallenge,
      'code_challenge_method': 'S256',
    });

    return auth0Url.toString();
  }

  // Login with Auth0
  Future<bool> loginWithAuth0() async {
    try {
      if (kIsWeb) {
        // Web platform handling
        final url = getAuth0Url();
        if (await canLaunchUrl(Uri.parse(url))) {
          await launchUrl(Uri.parse(url));
          return true; // Just indicate launch was successful
        }
        return false;
      } else {
        // Desktop/Mobile handling
        final url = getAuth0Url();

        if (AppConfig.useExternalBrowser &&
            await canLaunchUrl(Uri.parse(url))) {
          // Launch external browser
          await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

          // Start auth timeout timer
          _startAuthTimer();

          // Return true to indicate successful launch
          return true;
        }

        // Fallback for development
        if (kDebugMode) {
          // Create a mock user for debugging
          final mockUser = User(
            id: 'mock-user-id',
            name: 'Test User',
            email: 'test@example.com',
            createdAt: DateTime.now(),
          );
          await _saveAuth('mock-token', mockUser);
          return true;
        }
      }

      return false;
    } catch (e) {
      debugPrint("Error with Auth0 login: $e");
      return false;
    }
  }

  // Check if auth code is available from external login
  Future<bool> checkExternalAuthResult() async {
    final prefs = await SharedPreferences.getInstance();
    final savedCode = prefs.getString(AppConfig.authCodeStorageKey);
    final savedState = prefs.getString(AppConfig.authStateStorageKey);

    if (savedCode != null && savedState != null && savedState == _state) {
      // We have a valid auth code, exchange it for token
      final success = await _exchangeCodeForToken(savedCode);

      // Clear stored code and state
      await prefs.remove(AppConfig.authCodeStorageKey);
      await prefs.remove(AppConfig.authStateStorageKey);

      return success;
    }

    return false;
  }

  // Exchange authorization code for token
  Future<bool> _exchangeCodeForToken(String code) async {
    try {
      final auth0Domain = AppConfig.auth0Domain;
      final clientId = AppConfig.auth0ClientId;
      final redirectUri = AppConfig.auth0RedirectUri;

      final response = await http.post(
        Uri.https(auth0Domain, '/oauth/token'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'grant_type': 'authorization_code',
          'client_id': clientId,
          'code_verifier': _codeVerifier,
          'code': code,
          'redirect_uri': redirectUri,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Parse user info from ID token
        final idToken = data['id_token'];
        final accessToken = data['access_token'];

        // Get user profile with the access token
        final userInfo = await _getUserInfo(accessToken);
        if (userInfo != null) {
          await _saveAuth(accessToken, userInfo);
          return true;
        }
      }

      return false;
    } catch (e) {
      debugPrint("Error exchanging code for token: $e");
      return false;
    }
  }

  // Get user info from Auth0
  Future<User?> _getUserInfo(String accessToken) async {
    try {
      final auth0Domain = AppConfig.auth0Domain;
      final response = await http.get(
        Uri.https(auth0Domain, '/userinfo'),
        headers: {'Authorization': 'Bearer $accessToken'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        return User(
          id: data['sub'],
          name: data['name'] ?? 'Unknown',
          email: data['email'] ?? '',
          createdAt: DateTime.now(),
        );
      }

      return null;
    } catch (e) {
      debugPrint("Error getting user info: $e");
      return null;
    }
  }

  // Save auth state for CSRF protection
  Future<void> _saveAuthState(String state) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConfig.authStateStorageKey, state);
  }

  // Start auth timeout timer
  void _startAuthTimer() {
    _authTimer?.cancel();
    _authTimer = Timer(Duration(seconds: AppConfig.authSessionTimeout), () {
      debugPrint("Auth session timeout");
    });
  }

  // Load stored authentication data
  Future<void> _loadStoredAuth() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(AppConfig.tokenStorageKey);
    final userJson = prefs.getString(AppConfig.userStorageKey);
    if (_token != null && userJson != null) {
      try {
        _currentUser = User.fromJson(jsonDecode(userJson));
        isAuthenticated.value = await validateToken(); // Validate token on load
      } catch (e) {
        debugPrint("Error decoding stored user: $e");
        await _clearAuth(); // Clear invalid stored data
      }
    } else {
      isAuthenticated.value = false;
    }
  }

  // Save authentication data
  Future<void> _saveAuth(String token, User user) async {
    _token = token;
    _currentUser = user;
    isAuthenticated.value = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConfig.tokenStorageKey, token);
    await prefs.setString(AppConfig.userStorageKey, jsonEncode(user.toJson()));
  }

  // Clear authentication data
  Future<void> _clearAuth() async {
    _token = null;
    _currentUser = null;
    isAuthenticated.value = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConfig.tokenStorageKey);
    await prefs.remove(AppConfig.userStorageKey);
  }

  // Login with username and password
  Future<bool> login(String email, String password) async {
    final url = Uri.parse('$baseUrl/api/auth/login');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await _saveAuth(data['token'], User.fromJson(data['user']));
        return true;
      } else {
        debugPrint('Login failed: ${response.statusCode} ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('Login error: $e');
      return false;
    }
  }

  // Logout
  Future<void> logout() async {
    try {
      if (_token != null) {
        final url = Uri.parse('$baseUrl/api/auth/logout');
        await http.post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $_token',
          },
        );
      }
    } catch (e) {
      debugPrint('Logout API call failed: $e');
    } finally {
      await _clearAuth();
    }
  }

  // Check if the token is valid
  Future<bool> validateToken() async {
    if (_token == null) return false;
    final url = Uri.parse('$baseUrl/api/auth/validate-token');
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        },
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Token validation error: $e');
      return false;
    }
  }

  // Register a new user
  Future<bool> register(String name, String email, String password) async {
    final url = Uri.parse('$baseUrl/api/auth/register');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name,
          'email': email,
          'password': password,
        }),
      );
      return response.statusCode == 201;
    } catch (e) {
      debugPrint('Registration error: $e');
      return false;
    }
  }
}
