// IO platform detection and ngrok service factory (mobile + desktop)
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'ngrok_service.dart';
import 'ngrok_service_desktop.dart';
import 'ngrok_service_mobile.dart';
import 'auth_service.dart';

/// IO platform ngrok service factory (handles mobile and desktop)
class NgrokServicePlatform extends NgrokService {
  late final NgrokService _platformService;
  final AuthService? _authService;

  // Platform detection using dart:io
  static bool get isWeb => false;
  static bool get isMobile => Platform.isAndroid || Platform.isIOS;
  static bool get isDesktop =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  NgrokServicePlatform({AuthService? authService})
    : _authService = authService {
    _initialize();
  }

  void _initialize() {
    // Create platform-specific service
    if (isMobile) {
      _platformService = NgrokServiceMobile(authService: _authService);
      debugPrint('📱 Initialized Mobile Ngrok Service');
    } else if (isDesktop) {
      _platformService = NgrokServiceDesktop(authService: _authService);
      debugPrint('🖥️ Initialized Desktop Ngrok Service');
    } else {
      // Fallback to desktop service for unknown platforms
      _platformService = NgrokServiceDesktop(authService: _authService);
      debugPrint('⚠️ Unknown platform, falling back to Desktop Ngrok Service');
    }

    // Listen to platform service changes
    _platformService.addListener(() {
      notifyListeners();
    });
  }

  // Delegate all properties to platform service
  @override
  NgrokConfig get config => _platformService.config;

  @override
  NgrokTunnel? get activeTunnel => _platformService.activeTunnel;

  @override
  bool get isRunning => _platformService.isRunning;

  @override
  bool get isStarting => _platformService.isStarting;

  @override
  String? get lastError => _platformService.lastError;

  @override
  bool get isSupported => _platformService.isSupported;

  // Delegate all methods to platform service
  @override
  Future<void> initialize() async {
    return await _platformService.initialize();
  }

  @override
  Future<NgrokTunnel?> startTunnel(NgrokConfig config) async {
    return await _platformService.startTunnel(config);
  }

  @override
  Future<void> stopTunnel() async {
    return await _platformService.stopTunnel();
  }

  @override
  Future<bool> isNgrokInstalled() async {
    return await _platformService.isNgrokInstalled();
  }

  @override
  Future<String?> getNgrokVersion() async {
    return await _platformService.getNgrokVersion();
  }

  @override
  Future<void> updateConfiguration(NgrokConfig newConfig) async {
    return await _platformService.updateConfiguration(newConfig);
  }

  @override
  Future<Map<String, dynamic>> getTunnelStatus() async {
    return await _platformService.getTunnelStatus();
  }

  /// Get platform-specific information for debugging
  Map<String, dynamic> getPlatformInfo() {
    return {
      'platform': getPlatformName(),
      'isWeb': false,
      'isMobile': isMobile,
      'isDesktop': isDesktop,
      'serviceType': _platformService.runtimeType.toString(),
      'isSupported': isSupported,
      'isRunning': isRunning,
      'isStarting': isStarting,
      'hasActiveTunnel': activeTunnel != null,
    };
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
  bool get supportsNgrok => isDesktop; // Only desktop supports ngrok for now

  @override
  void dispose() {
    _platformService.dispose();
    super.dispose();
  }
}
