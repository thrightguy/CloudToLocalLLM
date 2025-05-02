import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../config/app_config.dart';
import 'settings_provider.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/cloud_service.dart';
import '../services/storage_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService authService;
  final CloudService cloudService;
  final StorageService storageService;
  
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
    
    _setLoading(true);
    
    try {
      // Initialize auth service
      await authService.initialize();
      
      // Listen for authentication changes
      authService.isAuthenticated.addListener(_onAuthChanged);
      
      _isInitialized = true;
      _error = '';
    } catch (e) {
      _error = 'Error initializing auth provider: $e';
      print(_error);
    } finally {
      _setLoading(false);
    }
  }
  
  // Login with Auth0
  Future<bool> loginWithAuth0() async {
    _setLoading(true);
    _error = '';
    
    try {
      final success = await authService.loginWithAuth0();
      if (success) {
        // Sync user profile with cloud
        await _syncUserProfile();
      }
      return success;
    } catch (e) {
      _error = 'Error logging in with Auth0: $e';
      print(_error);
      return false;
    } finally {
      _setLoading(false);
    }
  }
  
  // Login with email and password
  Future<bool> login(String email, String password) async {
    _setLoading(true);
    _error = '';
    
    try {
      final success = await authService.login(email, password);
      if (success) {
        // Sync user profile with cloud
        await _syncUserProfile();
      }
      return success;
    } catch (e) {
      _error = 'Error logging in: $e';
      print(_error);
      return false;
    } finally {
      _setLoading(false);
    }
  }
  
  // Register a new user
  Future<bool> register(String name, String email, String password) async {
    _setLoading(true);
    _error = '';
    
    try {
      final success = await authService.register(name, email, password);
      if (success) {
        // Login with the new credentials
        return await login(email, password);
      }
      return success;
    } catch (e) {
      _error = 'Error registering: $e';
      print(_error);
      return false;
    } finally {
      _setLoading(false);
    }
  }
  
  // Logout
  Future<void> logout() async {
    _setLoading(true);
    _error = '';
    
    try {
      await authService.logout();
    } catch (e) {
      _error = 'Error logging out: $e';
      print(_error);
    } finally {
      _setLoading(false);
    }
  }
  
  // Validate the current token
  Future<bool> validateToken() async {
    if (!isAuthenticated) return false;
    
    _setLoading(true);
    
    try {
      final isValid = await authService.validateToken();
      if (!isValid) {
        // Token is invalid, logout
        await logout();
      }
      return isValid;
    } catch (e) {
      _error = 'Error validating token: $e';
      print(_error);
      return false;
    } finally {
      _setLoading(false);
    }
  }
  
  // Update user profile
  Future<bool> updateUserProfile(User updatedUser) async {
    if (!isAuthenticated) return false;
    
    _setLoading(true);
    _error = '';
    
    try {
      // Update on cloud
      final success = await cloudService.updateUserProfile(updatedUser);
      if (success) {
        // Save locally
        await storageService.saveUser(updatedUser);
      }
      return success;
    } catch (e) {
      _error = 'Error updating user profile: $e';
      print(_error);
      return false;
    } finally {
      _setLoading(false);
    }
  }
  
  // Sync user profile with cloud
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
      print('Error syncing user profile: $e');
    }
  }
  
  // Handle authentication changes
  void _onAuthChanged() {
    notifyListeners();
  }
  
  // Helper to set loading state
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
  
  @override
  void dispose() {
    authService.isAuthenticated.removeListener(_onAuthChanged);
    super.dispose();
  }
}