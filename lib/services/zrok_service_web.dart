import 'package:flutter/foundation.dart';
import 'zrok_service.dart';
import 'auth_service.dart';

/// Web zrok service implementation
/// Web platform acts as bridge server, not tunnel client
class ZrokServiceWeb extends ZrokService {
  final ZrokConfig _config = ZrokConfig.defaultConfig();
  final AuthService? _authService;

  ZrokServiceWeb({AuthService? authService}) : _authService = authService {
    debugPrint('🌐 [ZrokService] Web service initialized (bridge server mode)');
  }

  @override
  ZrokConfig get config => _config;

  @override
  ZrokTunnel? get activeTunnel => null; // Web acts as bridge, not tunnel client

  @override
  bool get isRunning => false; // Web doesn't run client tunnels

  @override
  bool get isStarting => false;

  @override
  String? get lastError => null;

  @override
  bool get isSupported => false; // Web acts as bridge server, not tunnel client

  @override
  Future<void> initialize() async {
    debugPrint('🌐 [ZrokService] Web service initialized (bridge server mode)');
  }

  @override
  Future<ZrokTunnel?> startTunnel(ZrokConfig config) async {
    debugPrint(
      '🌐 [ZrokService] Tunnel creation not supported on web platform (bridge server mode)',
    );
    return null;
  }

  @override
  Future<void> stopTunnel() async {
    debugPrint('🌐 [ZrokService] No tunnel to stop on web platform');
  }

  @override
  Future<bool> isZrokInstalled() async {
    return false; // Zrok not available in browser
  }

  @override
  Future<String?> getZrokVersion() async {
    return null; // No zrok in browser
  }

  @override
  Future<void> updateConfiguration(ZrokConfig newConfig) async {
    debugPrint('🌐 [ZrokService] Configuration update not supported on web');
  }

  @override
  Future<Map<String, dynamic>> getTunnelStatus() async {
    return {
      'supported': false,
      'platform': 'web',
      'isRunning': false,
      'isStarting': false,
      'lastError':
          'Zrok tunnels not supported on web platform (bridge server mode)',
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
    debugPrint('🌐 [ZrokService] Environment enable not supported on web');
    return false;
  }

  @override
  Future<bool> isEnvironmentEnabled() async {
    return false; // No environment on web
  }

  @override
  Future<String?> createReservedShare(ZrokConfig config) async {
    debugPrint('🌐 [ZrokService] Reserved share creation not supported on web');
    return null;
  }

  @override
  Future<void> releaseReservedShare(String shareToken) async {
    debugPrint('🌐 [ZrokService] Reserved share release not supported on web');
  }

  @override
  Future<bool> validateTunnelAccess() async {
    // Web platform acts as bridge server, so tunnel access validation
    // is handled differently (through WebSocket bridge authentication)
    if (_authService != null) {
      final isAuthenticated = _authService.isAuthenticated.value;
      debugPrint(
        '🌐 [ZrokService] Bridge server access validation: $isAuthenticated',
      );
      return isAuthenticated;
    }
    return false;
  }

  @override
  void dispose() {
    debugPrint('🌐 [ZrokService] Web service disposed');
    super.dispose();
  }
}
