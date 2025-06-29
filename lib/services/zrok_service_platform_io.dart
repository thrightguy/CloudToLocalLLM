// Platform-specific zrok service factory for mobile/desktop platforms
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'zrok_service.dart';
import 'zrok_service_desktop.dart';
import 'zrok_service_mobile.dart';
import 'auth_service.dart';

/// IO platform zrok service factory (handles mobile and desktop)
class ZrokServicePlatform extends ZrokService {
  late final ZrokService _platformService;
  final AuthService? _authService;

  // Platform detection using dart:io
  static bool get isWeb => false;
  static bool get isMobile => Platform.isAndroid || Platform.isIOS;
  static bool get isDesktop =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  ZrokServicePlatform({AuthService? authService}) : _authService = authService {
    _initialize();
  }

  void _initialize() {
    // Create platform-specific service
    if (isMobile) {
      _platformService = ZrokServiceMobile(authService: _authService);
      debugPrint('📱 Initialized Mobile Zrok Service');
    } else if (isDesktop) {
      _platformService = ZrokServiceDesktop(authService: _authService);
      debugPrint('🖥️ Initialized Desktop Zrok Service');
    } else {
      // Fallback to desktop service for unknown platforms
      _platformService = ZrokServiceDesktop(authService: _authService);
      debugPrint('⚠️ Unknown platform, falling back to Desktop Zrok Service');
    }

    // Listen to platform service changes
    _platformService.addListener(() {
      notifyListeners();
    });
  }

  // Delegate all properties to platform service
  @override
  ZrokConfig get config => _platformService.config;

  @override
  ZrokTunnel? get activeTunnel => _platformService.activeTunnel;

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
  Future<ZrokTunnel?> startTunnel(ZrokConfig config) async {
    return await _platformService.startTunnel(config);
  }

  @override
  Future<void> stopTunnel() async {
    return await _platformService.stopTunnel();
  }

  @override
  Future<bool> isZrokInstalled() async {
    return await _platformService.isZrokInstalled();
  }

  @override
  Future<String?> getZrokVersion() async {
    return await _platformService.getZrokVersion();
  }

  @override
  Future<void> updateConfiguration(ZrokConfig newConfig) async {
    return await _platformService.updateConfiguration(newConfig);
  }

  @override
  Future<Map<String, dynamic>> getTunnelStatus() async {
    return await _platformService.getTunnelStatus();
  }

  @override
  Future<bool> enableEnvironment(String accountToken) async {
    return await _platformService.enableEnvironment(accountToken);
  }

  @override
  Future<bool> isEnvironmentEnabled() async {
    return await _platformService.isEnvironmentEnabled();
  }

  @override
  Future<String?> createReservedShare(ZrokConfig config) async {
    return await _platformService.createReservedShare(config);
  }

  @override
  Future<void> releaseReservedShare(String shareToken) async {
    return await _platformService.releaseReservedShare(shareToken);
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
  bool get supportsZrok => _platformService.isSupported;

  @override
  void dispose() {
    _platformService.dispose();
    super.dispose();
  }
}
