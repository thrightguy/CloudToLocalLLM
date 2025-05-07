import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';

class LocalAuthService {
  final String baseUrl;
  User? _currentUser;
  String? _token;
  final ValueNotifier<bool> isAuthenticated = ValueNotifier<bool>(false);

  LocalAuthService({String? baseUrl})
      : baseUrl = baseUrl ?? 'http://localhost:8080';

  // Get the current user
  User? get currentUser => _currentUser;

  // Get the authentication token
  String? getToken() => _token;

  // Initialize the auth service
  Future<void> initialize() async {
    await _loadStoredAuth();
  }

  // Load stored authentication data
  Future<void> _loadStoredAuth() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      final userJson = prefs.getString('auth_user');

      if (token != null && userJson != null) {
        final user = User.fromJson(jsonDecode(userJson));
        await _saveAuth(token, user);
      }
    } catch (e) {
      debugPrint('Error loading stored auth: $e');
    }
  }

  // Save authentication data
  Future<void> _saveAuth(String token, User user) async {
    _token = token;
    _currentUser = user;
    isAuthenticated.value = true;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
    await prefs.setString('auth_user', jsonEncode(user.toJson()));
  }

  // Clear authentication data
  Future<void> _clearAuth() async {
    _token = null;
    _currentUser = null;
    isAuthenticated.value = false;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('auth_user');
  }

  // Register a new user
  Future<bool> register(String username, String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'email': email,
          'password': password,
        }),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final user = User.fromJson(data['user']);
        await _saveAuth(data['token'], user);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error registering: $e');
      return false;
    }
  }

  // Login with username and password
  Future<bool> login(String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final user = User.fromJson(data['user']);
        await _saveAuth(data['token'], user);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error logging in: $e');
      return false;
    }
  }

  // Logout
  Future<void> logout() async {
    await _clearAuth();
  }

  // Validate token
  Future<bool> validateToken() async {
    if (_token == null) return false;

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/verify'),
        headers: {'Authorization': 'Bearer $_token'},
      );

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error validating token: $e');
      return false;
    }
  }
}
