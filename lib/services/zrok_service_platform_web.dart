// Platform-specific zrok service factory for web platform
import 'package:flutter/foundation.dart';
import 'zrok_service.dart';
import 'zrok_service_web.dart';
import 'auth_service.dart';

/// Web platform zrok service factory
/// Zrok is not supported on web platform since web acts as bridge server
class ZrokServicePlatform extends ZrokService {
  late final ZrokServiceWeb _platformService;

  // Platform detection - always web
  static bool get isWeb => true;
  static bool get isMobile => false;
  static bool get isDesktop => false;

  ZrokServicePlatform({AuthService? authService}) {
    _platformService = ZrokServiceWeb(authService: authService);
    debugPrint('🌐 [ZrokService] Initialized Web Zrok Service (stub)');
  }

  // Delegate all properties to web service
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

  // Delegate all methods to web service
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
      'platform': 'Web',
      'isWeb': true,
      'isMobile': false,
      'isDesktop': false,
      'serviceType': 'ZrokServiceWeb',
      'isSupported': false,
      'isRunning': false,
      'isStarting': false,
      'hasActiveTunnel': false,
    };
  }

  String getPlatformName() => 'Web';

  /// Platform capability checks
  bool get supportsZrok => false;

  @override
  void dispose() {
    _platformService.dispose();
    super.dispose();
  }
}
