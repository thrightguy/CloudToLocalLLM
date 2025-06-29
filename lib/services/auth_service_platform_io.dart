// IO platform detection and authentication service factory (mobile + desktop)
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import 'auth_service_mobile.dart';
import 'auth_service_desktop.dart';
import 'auth_service_desktop_windows.dart';

/// IO platform authentication service factory (handles mobile and desktop)
class AuthServicePlatform extends ChangeNotifier {
  late final dynamic _platformService;

  // Platform detection using dart:io
  static bool get isWeb => false;
  static bool get isMobile => Platform.isAndroid || Platform.isIOS;
  static bool get isDesktop =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  // Getters that delegate to platform service
  ValueNotifier<bool> get isAuthenticated => _platformService.isAuthenticated;
  ValueNotifier<bool> get isLoading => _platformService.isLoading;
  UserModel? get currentUser => _platformService.currentUser;

  AuthServicePlatform() {
    _initialize();
  }

  void _initialize() {
    // Create platform-specific service
    if (isMobile) {
      _platformService = AuthServiceMobile();
      debugPrint('📱 Initialized Mobile Authentication Service');
    } else if (isDesktop) {
      // Use Windows-specific authentication service for Windows
      if (Platform.isWindows) {
        _platformService = AuthServiceDesktopWindows();
        debugPrint('🖥️ Initialized Windows Desktop Authentication Service');
      } else {
        // Use flutter_appauth for macOS and Linux (supported platforms)
        _platformService = AuthServiceDesktop();
        debugPrint(
          '🖥️ Initialized Desktop Authentication Service (macOS/Linux)',
        );
      }
    } else {
      // Fallback to Windows service for unknown platforms
      _platformService = AuthServiceDesktopWindows();
      debugPrint(
        '⚠️ Unknown platform, falling back to Windows Desktop Authentication Service',
      );
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
  Future<void> loginWithBiometrics() async {
    if (isMobile && _platformService is AuthServiceMobile) {
      return await _platformService.loginWithBiometrics();
    } else {
      throw UnsupportedError(
        'Biometric authentication is only available on mobile platforms',
      );
    }
  }

  /// Mobile-specific: Check if biometric authentication is available
  Future<bool> isBiometricAvailable() async {
    if (isMobile && _platformService is AuthServiceMobile) {
      return await _platformService.isBiometricAvailable();
    }
    return false;
  }

  /// Mobile-specific: Refresh token if needed
  Future<void> refreshTokenIfNeeded() async {
    if (isMobile && _platformService is AuthServiceMobile) {
      return await _platformService.refreshTokenIfNeeded();
    }
    // For desktop, this is handled automatically or not needed
  }

  /// Get platform-specific information for debugging
  Map<String, dynamic> getPlatformInfo() {
    return {
      'platform': getPlatformName(),
      'isWeb': false,
      'isMobile': isMobile,
      'isDesktop': isDesktop,
      'serviceType': _platformService.runtimeType.toString(),
      'isAuthenticated': isAuthenticated.value,
      'isLoading': isLoading.value,
      'hasUser': currentUser != null,
    };
  }

  /// Get the current access token for API authentication
  String? getAccessToken() {
    // Delegate to platform-specific service
    if (_platformService.runtimeType.toString() == 'AuthServiceDesktop') {
      // For desktop, get token from credential
      return _platformService.credential?.accessToken;
    } else if (_platformService.runtimeType.toString() == 'AuthServiceMobile') {
      // For mobile, get token from stored credentials
      // Note: This is a stub implementation - actual mobile implementation
      // would need to access stored credentials from Auth0 CredentialsManager
      return _platformService.accessToken;
    }
    return null;
  }

  String getPlatformName() {
    if (Platform.isAndroid) return 'Android';
    if (Platform.isIOS) return 'iOS';
    if (Platform.isWindows) return 'Windows';
    if (Platform.isLinux) return 'Linux';
    if (Platform.isMacOS) return 'macOS';
    return 'Unknown';
  }

  /// Platform capability checks
  bool get supportsBiometrics => isMobile;
  bool get supportsDeepLinking => true; // Both mobile and desktop support this
  bool get supportsSecureStorage =>
      true; // Both mobile and desktop support this

  /// Get recommended authentication method for current platform
  String get recommendedAuthMethod {
    if (isMobile) return 'universal_login';
    if (isDesktop) return 'authorization_code_pkce';
    return 'authorization_code_pkce';
  }

  @override
  void dispose() {
    _platformService.dispose();
    super.dispose();
  }
}
