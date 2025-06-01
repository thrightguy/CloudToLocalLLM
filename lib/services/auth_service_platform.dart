// Conditional import for Platform class - only available on non-web platforms
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';

// Platform-specific imports with conditional compilation
import 'auth_service_desktop.dart';
import 'auth_service_mobile.dart';

// Conditional import: real web service on web, stub on other platforms
import 'auth_service_web.dart'
    if (dart.library.io) 'auth_service_web_stub.dart';

/// Platform detection and service factory for authentication
/// Automatically selects the appropriate authentication service based on platform
class AuthServicePlatform extends ChangeNotifier {
  late final dynamic _platformService;

  // Platform detection - safe for web
  static bool get isWeb => kIsWeb;
  static bool get isMobile {
    if (kIsWeb) return false;
    try {
      return Platform.isAndroid || Platform.isIOS;
    } catch (e) {
      return false;
    }
  }

  static bool get isDesktop {
    if (kIsWeb) return false;
    try {
      return Platform.isWindows || Platform.isLinux || Platform.isMacOS;
    } catch (e) {
      return false;
    }
  }

  // Getters that delegate to platform service
  ValueNotifier<bool> get isAuthenticated => _platformService.isAuthenticated;
  ValueNotifier<bool> get isLoading => _platformService.isLoading;
  UserModel? get currentUser => _platformService.currentUser;

  AuthServicePlatform() {
    _initialize();
  }

  void _initialize() {
    // Create platform-specific service
    if (isWeb) {
      _platformService = AuthServiceWeb();
      debugPrint('🌐 Initialized Web Authentication Service');
    } else if (isMobile) {
      _platformService = AuthServiceMobile();
      debugPrint('📱 Initialized Mobile Authentication Service');
    } else if (isDesktop) {
      _platformService = AuthServiceDesktop();
      debugPrint('🖥️ Initialized Desktop Authentication Service');
    } else {
      // Fallback to desktop service for unknown platforms
      _platformService = AuthServiceDesktop();
      debugPrint(
          '⚠️ Unknown platform, falling back to Desktop Authentication Service');
    }

    // Listen to platform service changes
    _platformService.addListener(() {
      notifyListeners();
    });
  }

  /// Login using platform-specific implementation
  Future<void> login() async {
    return await _platformService.login();
  }

  /// Logout using platform-specific implementation
  Future<void> logout() async {
    return await _platformService.logout();
  }

  /// Handle authentication callback using platform-specific implementation
  Future<bool> handleCallback() async {
    return await _platformService.handleCallback();
  }

  /// Mobile-specific: Login with biometric authentication
  /// Only available on mobile platforms
  Future<void> loginWithBiometrics() async {
    if (isMobile && _platformService is AuthServiceMobile) {
      return await _platformService.loginWithBiometrics();
    } else {
      throw UnsupportedError(
          'Biometric authentication is only available on mobile platforms');
    }
  }

  /// Mobile-specific: Check if biometric authentication is available
  /// Returns false for non-mobile platforms
  Future<bool> isBiometricAvailable() async {
    if (isMobile && _platformService is AuthServiceMobile) {
      return await _platformService.isBiometricAvailable();
    }
    return false;
  }

  /// Mobile-specific: Refresh token if needed
  /// Only available on mobile platforms
  Future<void> refreshTokenIfNeeded() async {
    if (isMobile && _platformService is AuthServiceMobile) {
      return await _platformService.refreshTokenIfNeeded();
    }
    // For other platforms, this is handled automatically or not needed
  }

  /// Get platform-specific information for debugging
  Map<String, dynamic> getPlatformInfo() {
    return {
      'platform': getPlatformName(),
      'isWeb': isWeb,
      'isMobile': isMobile,
      'isDesktop': isDesktop,
      'serviceType': _platformService.runtimeType.toString(),
      'isAuthenticated': isAuthenticated.value,
      'isLoading': isLoading.value,
      'hasUser': currentUser != null,
    };
  }

  /// Get the current access token for API authentication
  /// Returns null if not authenticated or token is not available
  String? getAccessToken() {
    // Check if the platform service has an accessToken getter
    final service = _platformService;
    if (service is AuthServiceWeb) {
      return service.accessToken;
    }
    // For other platforms, implement as needed
    return null;
  }

  String getPlatformName() {
    if (isWeb) return 'Web';
    if (isMobile) {
      if (!kIsWeb) {
        try {
          if (Platform.isAndroid) return 'Android';
          if (Platform.isIOS) return 'iOS';
        } catch (e) {
          // Platform access failed, return generic
        }
      }
      return 'Mobile';
    }
    if (isDesktop) {
      if (!kIsWeb) {
        try {
          if (Platform.isWindows) return 'Windows';
          if (Platform.isLinux) return 'Linux';
          if (Platform.isMacOS) return 'macOS';
        } catch (e) {
          // Platform access failed, return generic
        }
      }
      return 'Desktop';
    }
    return 'Unknown';
  }

  /// Platform capability checks
  bool get supportsBiometrics => isMobile;
  bool get supportsDeepLinking => isMobile || isDesktop;
  bool get supportsSecureStorage => isMobile || isDesktop;

  /// Get recommended authentication method for current platform
  String get recommendedAuthMethod {
    if (isWeb) return 'redirect';
    if (isMobile) return 'universal_login';
    if (isDesktop) return 'authorization_code_pkce';
    return 'redirect';
  }

  @override
  void dispose() {
    _platformService.dispose();
    super.dispose();
  }
}
