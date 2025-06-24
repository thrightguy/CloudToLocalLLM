import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage_x/flutter_secure_storage_x.dart';
import '../models/user_model.dart';
import 'auth_service_platform.dart';

/// Production-ready authentication service with comprehensive platform support
/// Automatically detects platform and uses appropriate authentication method:
/// - Web: Direct Auth0 redirect flow
/// - Mobile (iOS/Android): Auth0 Flutter SDK with native authentication
/// - Desktop (Windows/Linux/macOS): OpenID Connect with PKCE
///
/// Enhanced with persistent authentication and automatic token validation
class AuthService extends ChangeNotifier {
  late final AuthServicePlatform _platformService;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  // Enhanced authentication state tracking
  DateTime? _lastTokenValidation;
  bool _isValidatingToken = false;

  // Token validation interval (5 minutes)
  static const Duration _tokenValidationInterval = Duration(minutes: 5);

  // Getters that delegate to platform service
  ValueNotifier<bool> get isAuthenticated => _platformService.isAuthenticated;
  ValueNotifier<bool> get isLoading => _platformService.isLoading;
  UserModel? get currentUser => _platformService.currentUser;

  // Platform detection (delegated to platform service)
  bool get isWeb => AuthServicePlatform.isWeb;
  bool get isMobile => AuthServicePlatform.isMobile;
  bool get isDesktop => AuthServicePlatform.isDesktop;

  // Enhanced authentication state getters
  bool get isValidatingToken => _isValidatingToken;
  DateTime? get lastTokenValidation => _lastTokenValidation;

  AuthService() {
    _initialize();
  }

  void _initialize() {
    _platformService = AuthServicePlatform();

    // Listen to platform service changes
    _platformService.addListener(() {
      notifyListeners();
    });

    final platformInfo = _platformService.getPlatformInfo();
    debugPrint(
      '🔐 AuthService initialized for platform: ${platformInfo['platform']}',
    );

    // Start automatic token validation
    _startTokenValidationTimer();
  }

  /// Login using platform-specific implementation
  Future<void> login() async {
    return await _platformService.login();
  }

  /// Logout using platform-specific implementation
  Future<void> logout() async {
    return await _platformService.logout();
  }

  /// Handle Auth0 callback using platform-specific implementation
  Future<bool> handleCallback() async {
    return await _platformService.handleCallback();
  }

  /// Mobile-specific: Login with biometric authentication
  /// Only available on mobile platforms (iOS/Android)
  Future<void> loginWithBiometrics() async {
    return await _platformService.loginWithBiometrics();
  }

  /// Check if biometric authentication is available
  /// Returns true only on mobile platforms with biometric capabilities
  Future<bool> isBiometricAvailable() async {
    return await _platformService.isBiometricAvailable();
  }

  /// Mobile-specific: Refresh authentication token if needed
  /// Automatically handled on other platforms
  Future<void> refreshTokenIfNeeded() async {
    return await _platformService.refreshTokenIfNeeded();
  }

  /// Get comprehensive platform and authentication information
  /// Useful for debugging and feature detection
  Map<String, dynamic> getPlatformInfo() {
    return _platformService.getPlatformInfo();
  }

  /// Get the current access token for API authentication
  /// Returns null if not authenticated or token is not available
  /// For backward compatibility, this is synchronous
  String? getAccessToken() {
    return _platformService.getAccessToken();
  }

  /// Get the current access token with automatic validation
  /// Returns null if not authenticated or token is not available
  /// Automatically validates token freshness and triggers refresh if needed
  Future<String?> getValidatedAccessToken({bool forceRefresh = false}) async {
    if (!isAuthenticated.value) {
      debugPrint('🔐 Not authenticated, cannot get access token');
      return null;
    }

    // Check if we need to validate the token
    final now = DateTime.now();
    final shouldValidate =
        forceRefresh ||
        _lastTokenValidation == null ||
        now.difference(_lastTokenValidation!) > _tokenValidationInterval;

    if (shouldValidate && !_isValidatingToken) {
      await _validateAndRefreshToken();
    }

    return _platformService.getAccessToken();
  }

  /// Enhanced login with persistent authentication tracking
  Future<void> loginWithPersistence() async {
    try {
      await login();
      if (isAuthenticated.value) {
        await _storeAuthenticationState();
        _lastTokenValidation = DateTime.now();
        debugPrint('🔐 Login successful with persistence enabled');
      }
    } catch (e) {
      debugPrint('🔐 Login with persistence failed: $e');
      rethrow;
    }
  }

  /// Enhanced logout with complete cleanup
  Future<void> logoutWithCleanup() async {
    try {
      await logout();
      await _clearAuthenticationState();
      _lastTokenValidation = null;
      debugPrint('🔐 Logout completed with full cleanup');
    } catch (e) {
      debugPrint('🔐 Logout cleanup failed: $e');
      rethrow;
    }
  }

  /// Check if authentication is still valid and refresh if needed
  Future<bool> validateAuthentication() async {
    if (!isAuthenticated.value) {
      return false;
    }

    try {
      _isValidatingToken = true;
      notifyListeners();

      // Platform-specific token validation
      await refreshTokenIfNeeded();

      _lastTokenValidation = DateTime.now();
      await _storeAuthenticationState();

      debugPrint('🔐 Authentication validation successful');
      return isAuthenticated.value;
    } catch (e) {
      debugPrint('🔐 Authentication validation failed: $e');
      await _clearAuthenticationState();
      return false;
    } finally {
      _isValidatingToken = false;
      notifyListeners();
    }
  }

  /// Start automatic token validation timer
  void _startTokenValidationTimer() {
    // Validate authentication state on startup
    Future.delayed(const Duration(seconds: 2), () async {
      await _loadAuthenticationState();
      if (isAuthenticated.value) {
        await validateAuthentication();
      }
    });
  }

  /// Validate and refresh token if needed
  Future<void> _validateAndRefreshToken() async {
    try {
      _isValidatingToken = true;
      notifyListeners();

      await refreshTokenIfNeeded();
      _lastTokenValidation = DateTime.now();
      await _storeAuthenticationState();
    } catch (e) {
      debugPrint('🔐 Token validation/refresh failed: $e');
      await _clearAuthenticationState();
    } finally {
      _isValidatingToken = false;
      notifyListeners();
    }
  }

  /// Store authentication state for persistence
  Future<void> _storeAuthenticationState() async {
    try {
      if (_lastTokenValidation != null) {
        await _secureStorage.write(
          key: 'cloudtolocalllm_last_validation',
          value: _lastTokenValidation!.toIso8601String(),
        );
      }
      await _secureStorage.write(
        key: 'cloudtolocalllm_auth_persistent',
        value: 'true',
      );
    } catch (e) {
      debugPrint('🔐 Failed to store authentication state: $e');
    }
  }

  /// Load authentication state from storage
  Future<void> _loadAuthenticationState() async {
    try {
      final lastValidationStr = await _secureStorage.read(
        key: 'cloudtolocalllm_last_validation',
      );
      if (lastValidationStr != null) {
        _lastTokenValidation = DateTime.tryParse(lastValidationStr);
      }
    } catch (e) {
      debugPrint('🔐 Failed to load authentication state: $e');
    }
  }

  /// Clear authentication state from storage
  Future<void> _clearAuthenticationState() async {
    try {
      await _secureStorage.delete(key: 'cloudtolocalllm_last_validation');
      await _secureStorage.delete(key: 'cloudtolocalllm_auth_persistent');
    } catch (e) {
      debugPrint('🔐 Failed to clear authentication state: $e');
    }
  }

  /// Platform capability checks
  bool get supportsBiometrics => _platformService.supportsBiometrics;
  bool get supportsDeepLinking => _platformService.supportsDeepLinking;
  bool get supportsSecureStorage => _platformService.supportsSecureStorage;
  String get recommendedAuthMethod => _platformService.recommendedAuthMethod;

  @override
  void dispose() {
    _platformService.dispose();
    super.dispose();
  }
}
