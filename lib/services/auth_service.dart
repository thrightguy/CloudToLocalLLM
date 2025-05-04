import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import '../models/user.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:js' as js;

class AuthService {
  final String baseUrl;
  User? _currentUser;
  String? _token;
  final ValueNotifier<bool> isAuthenticated = ValueNotifier<bool>(false);

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

  // Login with Auth0
  Future<bool> loginWithAuth0() async {
    // For web platform, redirect directly to Auth0 login
    if (kIsWeb) {
      try {
        // Get the current URL to use as the base for the redirect URI
        final redirectUri = AppConfig.auth0RedirectUri;

        // Construct Auth0 login URL with values from AppConfig
        final auth0Domain = AppConfig.auth0Domain;
        final clientId = AppConfig.auth0ClientId;
        final audience = AppConfig.auth0Audience;

        final auth0Url = Uri.https(auth0Domain, '/authorize', {
          'client_id': clientId,
          'redirect_uri': redirectUri,
          'response_type': 'code',
          'scope': 'openid profile email',
          'audience': audience,
        });

        // Redirect to Auth0 login page
        js.context.callMethod('open', [auth0Url.toString(), '_self']);
        return true;
      } catch (e) {
        debugPrint("Error redirecting to Auth0: $e");
        return false;
      }
    } else {
      // Mobile/desktop implementation would go here
      debugPrint("Auth0 login not implemented for this platform yet.");
      return false;
    }
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
        debugPrint(
            'Login failed: ${response.statusCode} ${response.body}'); // Use debugPrint
        return false;
      }
    } catch (e) {
      debugPrint('Login error: $e'); // Use debugPrint
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
      debugPrint(
          'Logout API call failed: $e'); // Use debugPrint, but don't block logout
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
      debugPrint('Token validation error: $e'); // Use debugPrint
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
      debugPrint('Registration error: $e'); // Use debugPrint
      return false;
    }
  }
}
