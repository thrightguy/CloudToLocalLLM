import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import 'auth_service_platform.dart';

/// Production-ready authentication service with comprehensive platform support
/// Automatically detects platform and uses appropriate authentication method:
/// - Web: Direct Auth0 redirect flow
/// - Mobile (iOS/Android): Auth0 Flutter SDK with native authentication
/// - Desktop (Windows/Linux/macOS): OpenID Connect with PKCE
class AuthService extends ChangeNotifier {
  late final AuthServicePlatform _platformService;

  // Getters that delegate to platform service
  ValueNotifier<bool> get isAuthenticated => _platformService.isAuthenticated;
  ValueNotifier<bool> get isLoading => _platformService.isLoading;
  UserModel? get currentUser => _platformService.currentUser;

  // Platform detection (delegated to platform service)
  bool get isWeb => AuthServicePlatform.isWeb;
  bool get isMobile => AuthServicePlatform.isMobile;
  bool get isDesktop => AuthServicePlatform.isDesktop;

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
        '🔐 AuthService initialized for platform: ${platformInfo['platform']}');
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
  String? getAccessToken() {
    return _platformService.getAccessToken();
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
