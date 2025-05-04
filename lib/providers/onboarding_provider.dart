import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';
import '../services/api_service.dart';
import 'auth_provider.dart';

/// Provider that manages onboarding state, API key generation, and container status.
class OnboardingProvider with ChangeNotifier {
  bool _isOnboardingComplete = false;
  bool _isLoading = false;
  String? _apiKey;
  bool _containerCreated = false;
  bool _containerReady = false;
  String? _containerStatus;
  int _currentStep = 0;

  // Services
  final ApiService _apiService;
  late AuthProvider _authProvider;

  OnboardingProvider({
    required ApiService apiService,
    required AuthProvider authProvider,
  })  : _apiService = apiService,
        _authProvider = authProvider {
    _initialize();
  }

  // Getters
  bool get isOnboardingComplete => _isOnboardingComplete;
  bool get isLoading => _isLoading;
  String? get apiKey => _apiKey;
  bool get containerCreated => _containerCreated;
  bool get containerReady => _containerReady;
  String? get containerStatus => _containerStatus;
  int get currentStep => _currentStep;
  bool get isAuthenticated => _authProvider.isAuthenticated;

  /// Initialize the provider by loading saved state
  Future<void> _initialize() async {
    _loadOnboardingState();
  }

  /// Load onboarding state from shared preferences
  Future<void> _loadOnboardingState() async {
    if (!_authProvider.isAuthenticated) {
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();

      // Load onboarding completion status
      _isOnboardingComplete = prefs.getBool('onboarding_complete') ?? false;

      // Load API key (only stored locally)
      _apiKey = prefs.getString('api_key');

      // If we have an API key, we've at least started onboarding
      if (_apiKey != null) {
        _currentStep = 2; // Skip to client setup step
        await checkContainerStatus(); // Check container status
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error loading onboarding state: $e');
    }
  }

  /// Save onboarding state to shared preferences
  Future<void> _saveOnboardingState() async {
    if (!_authProvider.isAuthenticated) {
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('onboarding_complete', _isOnboardingComplete);
    } catch (e) {
      debugPrint('Error saving onboarding state: $e');
    }
  }

  /// Generate a secure API key
  Future<void> generateApiKey() async {
    if (_apiKey != null || !_authProvider.isAuthenticated) {
      return; // Don't regenerate if already exists or user not logged in
    }

    _isLoading = true;
    notifyListeners();

    try {
      // Generate a secure random key
      final random = Random.secure();
      final values = List<int>.generate(32, (i) => random.nextInt(256));
      final apiKey = base64Url.encode(values);

      // Store only in local storage, never send to server
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('api_key', apiKey);

      // Generate a hash to associate with user's container
      final keyHash = sha256.convert(utf8.encode(apiKey)).toString();

      // Associate key hash with user's container
      await _apiService.associateKeyHash(
          _authProvider.currentUser!.id, keyHash);

      _apiKey = apiKey;
      _currentStep = 2; // Move to client setup step

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow; // Let UI handle error display
    }
  }

  /// Reset API key (if user loses it)
  Future<void> resetApiKey() async {
    if (!_authProvider.isAuthenticated) {
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      // Clear current API key
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('api_key');

      // Reset container on server
      await _apiService.resetUserContainer(_authProvider.currentUser!.id);

      _apiKey = null;
      _containerCreated = false;
      _containerReady = false;
      _containerStatus = null;
      _currentStep = 1; // Back to API key generation step

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Check user's container status
  Future<void> checkContainerStatus() async {
    if (!_authProvider.isAuthenticated) {
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      // Get container status from server
      final status =
          await _apiService.getContainerStatus(_authProvider.currentUser!.id);

      _containerStatus = status;
      _containerCreated = status != 'not_created';
      _containerReady = status == 'running';

      // If container is ready and we're on the container status step, move to complete step
      if (_containerReady && _currentStep == 3) {
        _currentStep = 4;
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _containerStatus = 'error';
      notifyListeners();
      rethrow;
    }
  }

  /// Create a container for the user
  Future<void> createContainer() async {
    if (!_authProvider.isAuthenticated) {
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      // Create container on server
      await _apiService.createContainer(_authProvider.currentUser!.id);

      _containerCreated = true;

      // Check status after creation
      await checkContainerStatus();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Set the current onboarding step
  void setStep(int step) {
    if (step >= 0 && step < 5) {
      // 5 is the number of steps
      _currentStep = step;
      notifyListeners();

      // If we're at container status step, check status
      if (_currentStep == 3 && !_containerCreated) {
        createContainer();
      }
    }
  }

  /// Go to the next step
  void nextStep() {
    setStep(_currentStep + 1);
  }

  /// Go to the previous step
  void previousStep() {
    setStep(_currentStep - 1);
  }

  /// Complete the onboarding process
  void completeOnboarding() {
    _isOnboardingComplete = true;
    _saveOnboardingState();
    notifyListeners();
  }

  /// Set the auth provider
  void setAuthProvider(AuthProvider authProvider) {
    _authProvider = authProvider;
    _initialize();
  }
}
