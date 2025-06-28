// Web-specific platform detection and ngrok service factory
import 'package:flutter/foundation.dart';
import 'ngrok_service.dart';
import 'auth_service.dart';

/// Web platform ngrok service factory
/// Ngrok is not supported on web platform since web acts as bridge server
class NgrokServicePlatform extends NgrokService {
  // Platform detection - always web
  static bool get isWeb => true;
  static bool get isMobile => false;
  static bool get isDesktop => false;

  NgrokServicePlatform({AuthService? authService}) {
    debugPrint('🌐 Initialized Web Ngrok Service (stub)');
  }

  @override
  NgrokConfig get config => NgrokConfig.defaultConfig();

  @override
  NgrokTunnel? get activeTunnel => null;

  @override
  bool get isRunning => false;

  @override
  bool get isStarting => false;

  @override
  String? get lastError => null;

  @override
  bool get isSupported => false; // Ngrok not supported on web

  @override
  Future<void> initialize() async {
    debugPrint('🌐 [NgrokService] Web platform - ngrok not supported');
  }

  @override
  Future<NgrokTunnel?> startTunnel(NgrokConfig config) async {
    throw UnsupportedError(
      'Ngrok tunnels are not supported on web platform. '
      'Web platform acts as the bridge server and does not need tunneling.',
    );
  }

  @override
  Future<void> stopTunnel() async {
    throw UnsupportedError('Ngrok tunnels are not supported on web platform.');
  }

  @override
  Future<bool> isNgrokInstalled() async {
    return false; // Never installed on web
  }

  @override
  Future<String?> getNgrokVersion() async {
    return null; // No version on web
  }

  @override
  Future<void> updateConfiguration(NgrokConfig newConfig) async {
    throw UnsupportedError(
      'Ngrok configuration is not supported on web platform.',
    );
  }

  @override
  Future<Map<String, dynamic>> getTunnelStatus() async {
    return {
      'supported': false,
      'platform': 'web',
      'message': 'Ngrok tunnels are not supported on web platform',
    };
  }

  /// Get platform-specific information for debugging
  Map<String, dynamic> getPlatformInfo() {
    return {
      'platform': 'Web',
      'isWeb': true,
      'isMobile': false,
      'isDesktop': false,
      'serviceType': 'NgrokServiceWeb',
      'isSupported': false,
      'isRunning': false,
      'isStarting': false,
      'hasActiveTunnel': false,
    };
  }

  String getPlatformName() => 'Web';

  /// Platform capability checks
  bool get supportsNgrok => false;

  @override
  void dispose() {
    super.dispose();
  }
}
