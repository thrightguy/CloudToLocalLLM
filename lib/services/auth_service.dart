import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import '../models/user.dart';

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

  // Get the auth URL for Auth0
  String getAuth0Url() {
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
    });

    return auth0Url.toString();
  }

  // Login with Auth0
  Future<bool> loginWithAuth0() async {
    try {
      if (kIsWeb) {
        // On web, we just log that we would redirect to Auth0
        // In a real implementation, we'd use platform-specific code here
        final url = getAuth0Url();
        debugPrint("Would redirect to Auth0: $url");
      }

      // For demo purposes on non-web platforms
      debugPrint("Auth0 login would be implemented for this platform");

      // Simulate successful login for development
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

      return false;
    } catch (e) {
      debugPrint("Error with Auth0 login: $e");
      return false;
    }
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
