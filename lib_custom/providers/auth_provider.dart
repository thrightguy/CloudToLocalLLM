import 'dart:async';
import 'package:flutter/foundation.dart';
// import 'package:provider/provider.dart'; // Unused
// import '../config/app_config.dart'; // Unused
// import 'settings_provider.dart'; // Unused
import '../models/user.dart';
import '../services/local_auth_service.dart';
import '../services/cloud_service.dart';
import '../services/storage_service.dart';
import '../config/app_config.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
// import '../utils/logger.dart'; // Postponing logger

class AuthProvider extends ChangeNotifier {
  final LocalAuthService authService;
  final CloudService cloudService;
  final StorageService storageService;
  // final _logger = Logger('AuthProvider'); // Postponing logger

  bool _isInitialized = false;
  bool _isLoading = false;
  String _error = '';

  AuthProvider({
    required this.authService,
    required this.cloudService,
    required this.storageService,
  });

  // Getters
  bool get isAuthenticated => authService.isAuthenticated.value;
  User? get currentUser => authService.currentUser;
  bool get isLoading => _isLoading;
  String get error => _error;
  bool get isInitialized => _isInitialized;

  // Initialize the provider
  Future<void> initialize() async {
    if (_isInitialized) return;
    _isLoading = true;
    notifyListeners();

    try {
      // Initialize auth service
      await authService.initialize();

      // Listen for authentication changes
      authService.isAuthenticated.addListener(_onAuthChanged);

      _isInitialized = true;
      _error = '';
    } catch (e) {
      _error = 'Error initializing auth provider: $e';
      debugPrint(_error); // Use debugPrint
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Login with FusionAuth
  Future<bool> loginWithFusionAuth(String email, String password) async {
    _isLoading = true;
    _error = '';
    notifyListeners();
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.fusionAuthBaseUrl}/api/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'loginId': email,
          'password': password,
          'applicationId':
              AppConfig.fusionAuthClientId, // TODO: Set real app/client ID
        }),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Save token and user info as needed
        await authService.loginWithToken(data['token']);
        await _syncUserProfile();
        return true;
      } else {
        _error = 'FusionAuth login failed: ${response.body}';
        return false;
      }
    } catch (e) {
      _error = 'Error logging in with FusionAuth: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Register with FusionAuth
  Future<bool> registerWithFusionAuth(
      String name, String email, String password) async {
    _isLoading = true;
    _error = '';
    notifyListeners();
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.fusionAuthBaseUrl}/api/user/registration'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user': {
            'email': email,
            'password': password,
            'fullName': name,
          },
          'registration': {
            'applicationId':
                AppConfig.fusionAuthClientId, // TODO: Set real app/client ID
          }
        }),
      );
      if (response.statusCode == 200) {
        // After registration, log in
        return await loginWithFusionAuth(email, password);
      } else {
        _error = 'FusionAuth registration failed: ${response.body}';
        return false;
      }
    } catch (e) {
      _error = 'Error registering with FusionAuth: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Update login and register to use FusionAuth
  Future<bool> login(String email, String password) async {
    return await loginWithFusionAuth(email, password);
  }

  Future<bool> register(String name, String email, String password) async {
    return await registerWithFusionAuth(name, email, password);
  }

  // Logout the current user
  Future<void> logout() async {
    _isLoading = true;
    _error = '';
    notifyListeners();
    try {
      await authService.logout();
    } catch (e) {
      _error = 'Error logging out: $e';
      debugPrint(_error); // Use debugPrint
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Validate the current token
  Future<void> validateToken() async {
    if (!isAuthenticated) return;
    try {
      final isValid = await authService.validateToken();
      if (!isValid) {
        // Token is invalid, logout
        await logout();
      }
    } catch (e) {
      _error = 'Error validating token: $e';
      debugPrint(_error); // Use debugPrint
      // Optionally logout on validation error
      // await logout();
    }
  }

  // Update user profile
  Future<bool> updateUserProfile(User updatedUser) async {
    if (!isAuthenticated) return false;
    _isLoading = true;
    _error = '';
    notifyListeners();
    try {
      // Update on cloud
      final success = await cloudService.updateUserProfile(updatedUser);
      if (success) {
        // Save locally
        await storageService.saveUser(updatedUser);
      }
      return success;
    } catch (e) {
      _error = 'Error updating profile: $e';
      debugPrint(_error); // Use debugPrint
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Sync user profile from cloud
  Future<void> _syncUserProfile() async {
    if (!isAuthenticated) return;
    try {
      // Get profile from cloud
      final cloudProfile = await cloudService.getUserProfile();
      if (cloudProfile != null) {
        // Save locally
        await storageService.saveUser(cloudProfile);
      }
    } catch (e) {
      // Log error but don't block login/registration
      debugPrint('Error syncing user profile: $e'); // Use debugPrint
    }
  }

  // Handle authentication changes
  void _onAuthChanged() {
    notifyListeners();
    if (isAuthenticated) {
      // Sync profile when user logs in
      _syncUserProfile();
    }
  }

  @override
  void dispose() {
    authService.isAuthenticated.removeListener(_onAuthChanged);
    super.dispose();
  }
}
