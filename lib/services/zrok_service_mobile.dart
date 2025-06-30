import 'package:flutter/foundation.dart';
import 'zrok_service.dart';
import 'auth_service.dart';

/// Mobile zrok service implementation
/// Limited functionality on mobile platforms - primarily for status monitoring
class ZrokServiceMobile extends ZrokService {
  final ZrokConfig _config = ZrokConfig.defaultConfig();
  final AuthService? _authService;

  ZrokServiceMobile({AuthService? authService}) : _authService = authService {
    debugPrint(
      '📱 [ZrokService] Mobile service initialized (limited functionality)',
    );
  }

  @override
  ZrokConfig get config => _config;

  @override
  ZrokTunnel? get activeTunnel => null; // No active tunnels on mobile

  @override
  bool get isRunning => false; // Mobile doesn't run tunnels

  @override
  bool get isStarting => false;

  @override
  String? get lastError => null;

  @override
  bool get isSupported => false; // Limited support on mobile

  @override
  Future<void> initialize() async {
    debugPrint('🌐 [ZrokService] Mobile service initialized (read-only mode)');
  }

  @override
  Future<ZrokTunnel?> startTunnel(ZrokConfig config) async {
    debugPrint(
      '🌐 [ZrokService] Tunnel creation not supported on mobile platform',
    );
    return null;
  }

  @override
  Future<void> stopTunnel() async {
    debugPrint('🌐 [ZrokService] No tunnel to stop on mobile platform');
  }

  @override
  Future<bool> isZrokInstalled() async {
    return false; // Zrok not available on mobile
  }

  @override
  Future<String?> getZrokVersion() async {
    return null; // No zrok on mobile
  }

  @override
  Future<void> updateConfiguration(ZrokConfig newConfig) async {
    debugPrint('🌐 [ZrokService] Configuration update not supported on mobile');
  }

  @override
  Future<Map<String, dynamic>> getTunnelStatus() async {
    return {
      'supported': false,
      'platform': 'mobile',
      'isRunning': false,
      'isStarting': false,
      'lastError': 'Zrok tunnels not supported on mobile platform',
      'config': _config.toString(),
      'security': {
        'hasAuthService': _authService != null,
        'isAuthenticated': _authService?.isAuthenticated.value ?? false,
        'isTunnelSecure': false,
        'accessValidated': false,
      },
    };
  }

  @override
  Future<bool> enableEnvironment(String accountToken) async {
    debugPrint('🌐 [ZrokService] Environment enable not supported on mobile');
    return false;
  }

  @override
  Future<bool> isEnvironmentEnabled() async {
    return false; // No environment on mobile
  }

  @override
  Future<String?> createReservedShare(ZrokConfig config) async {
    debugPrint(
      '🌐 [ZrokService] Reserved share creation not supported on mobile',
    );
    return null;
  }

  @override
  Future<void> releaseReservedShare(String shareToken) async {
    debugPrint(
      '🌐 [ZrokService] Reserved share release not supported on mobile',
    );
  }

  @override
  Future<bool> validateTunnelAccess() async {
    // Mobile doesn't support tunnels, so access is always denied
    return false;
  }

  @override
  void dispose() {
    debugPrint('🌐 [ZrokService] Mobile service disposed');
    super.dispose();
  }
}
