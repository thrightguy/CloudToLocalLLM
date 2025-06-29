// Stub implementation for platforms that don't support zrok
import 'package:flutter/foundation.dart';
import 'zrok_service.dart';
import 'auth_service.dart';

/// Stub zrok service implementation for unsupported platforms
class ZrokServiceStub extends ZrokService {
  final ZrokConfig _config = ZrokConfig.defaultConfig();

  ZrokServiceStub({AuthService? authService}) {
    debugPrint(
      '🚫 [ZrokService] Stub service initialized (platform not supported)',
    );
  }

  @override
  ZrokConfig get config => _config;

  @override
  ZrokTunnel? get activeTunnel => null;

  @override
  bool get isRunning => false;

  @override
  bool get isStarting => false;

  @override
  String? get lastError => 'Platform not supported';

  @override
  bool get isSupported => false;

  @override
  Future<void> initialize() async {
    debugPrint('🚫 [ZrokService] Stub initialization (no-op)');
  }

  @override
  Future<ZrokTunnel?> startTunnel(ZrokConfig config) async {
    debugPrint('🚫 [ZrokService] Tunnel start not supported on this platform');
    return null;
  }

  @override
  Future<void> stopTunnel() async {
    debugPrint('🚫 [ZrokService] Tunnel stop not supported on this platform');
  }

  @override
  Future<bool> isZrokInstalled() async {
    return false;
  }

  @override
  Future<String?> getZrokVersion() async {
    return null;
  }

  @override
  Future<void> updateConfiguration(ZrokConfig newConfig) async {
    debugPrint(
      '🚫 [ZrokService] Configuration update not supported on this platform',
    );
  }

  @override
  Future<Map<String, dynamic>> getTunnelStatus() async {
    return {
      'supported': false,
      'platform': 'stub',
      'isRunning': false,
      'isStarting': false,
      'lastError': 'Platform not supported',
      'config': _config.toString(),
    };
  }

  @override
  Future<bool> enableEnvironment(String accountToken) async {
    debugPrint(
      '🚫 [ZrokService] Environment enable not supported on this platform',
    );
    return false;
  }

  @override
  Future<bool> isEnvironmentEnabled() async {
    return false;
  }

  @override
  Future<String?> createReservedShare(ZrokConfig config) async {
    debugPrint(
      '🚫 [ZrokService] Reserved share creation not supported on this platform',
    );
    return null;
  }

  @override
  Future<void> releaseReservedShare(String shareToken) async {
    debugPrint(
      '🚫 [ZrokService] Reserved share release not supported on this platform',
    );
  }

  @override
  void dispose() {
    debugPrint('🚫 [ZrokService] Stub service disposed');
    super.dispose();
  }
}
