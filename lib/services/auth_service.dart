import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
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
  String? get token => _token;
  
  // Initialize the auth service
  Future<void> initialize() async {
    await _loadStoredAuth();
  }
  
  // Load stored authentication data
  Future<void> _loadStoredAuth() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedToken = prefs.getString(AppConfig.tokenStorageKey);
      final storedUserJson = prefs.getString(AppConfig.userStorageKey);
      
      if (storedToken != null && storedUserJson != null) {
        _token = storedToken;
        _currentUser = User.fromJson(jsonDecode(storedUserJson));
        isAuthenticated.value = true;
      } else {
        // Create anonymous user if no stored user
        _currentUser = User.anonymous();
        isAuthenticated.value = false;
      }
    } catch (e) {
      // Create anonymous user on error
      _currentUser = User.anonymous();
      isAuthenticated.value = false;
    }
  }
  
  // Save authentication data
  Future<void> _saveAuth(String token, User user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConfig.tokenStorageKey, token);
      await prefs.setString(AppConfig.userStorageKey, jsonEncode(user.toJson()));
      
      _token = token;
      _currentUser = user;
      isAuthenticated.value = true;
    } catch (e) {
      throw Exception('Failed to save authentication data: $e');
    }
  }
  
  // Clear authentication data
  Future<void> _clearAuth() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(AppConfig.tokenStorageKey);
      await prefs.remove(AppConfig.userStorageKey);
      
      _token = null;
      _currentUser = User.anonymous();
      isAuthenticated.value = false;
    } catch (e) {
      throw Exception('Failed to clear authentication data: $e');
    }
  }
  
  // Login with Auth0
  Future<bool> loginWithAuth0() async {
    try {
      // Construct the Auth0 authorization URL
      final authUrl = Uri.parse(
        'https://${AppConfig.auth0Domain}/authorize'
        '?response_type=code'
        '&client_id=${AppConfig.auth0ClientId}'
        '&redirect_uri=${Uri.encodeComponent(AppConfig.auth0RedirectUri)}'
        '&scope=openid%20profile%20email'
      );
      
      // Launch the browser for authentication
      if (await canLaunchUrl(authUrl)) {
        await launchUrl(authUrl, mode: LaunchMode.externalApplication);
        
        // Handle the redirect in your app
        // This would typically be done with a platform channel or a plugin
        // For simplicity, we'll simulate a successful login
        
        // In a real implementation, you would:
        // 1. Set up a method channel to receive the redirect
        // 2. Exchange the code for a token
        // 3. Get the user profile
        
        // Simulate a successful login
        final user = User(
          id: 'auth0|123456789',
          email: 'user@example.com',
          name: 'Example User',
          pictureUrl: 'https://example.com/avatar.jpg',
          isAuthenticated: true,
          lastLogin: DateTime.now(),
        );
        
        await _saveAuth('simulated_token', user);
        return true;
      } else {
        throw Exception('Could not launch authentication URL');
      }
    } catch (e) {
      print('Login error: $e');
      return false;
    }
  }
  
  // Login with username and password
  Future<bool> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final token = data['token'];
        final user = User.fromJson(data['user']);
        
        await _saveAuth(token, user);
        return true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }
  
  // Logout
  Future<void> logout() async {
    try {
      if (_token != null) {
        // Call logout API if needed
        await http.post(
          Uri.parse('$baseUrl/api/auth/logout'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $_token',
          },
        );
      }
    } catch (e) {
      // Ignore errors during logout
    } finally {
      await _clearAuth();
    }
  }
  
  // Check if the token is valid
  Future<bool> validateToken() async {
    if (_token == null) return false;
    
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/auth/validate'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        },
      );
      
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
  
  // Register a new user
  Future<bool> register(String name, String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name,
          'email': email,
          'password': password,
        }),
      );
      
      return response.statusCode == 201;
    } catch (e) {
      return false;
    }
  }
}