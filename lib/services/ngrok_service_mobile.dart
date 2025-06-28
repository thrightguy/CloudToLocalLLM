// Mobile-specific ngrok service implementation
import 'package:flutter/foundation.dart';
import 'ngrok_service.dart';
import 'auth_service.dart';

/// Mobile ngrok service implementation
/// Ngrok is not typically used on mobile platforms
class NgrokServiceMobile extends NgrokService {
  NgrokConfig _config = NgrokConfig.defaultConfig();

  NgrokServiceMobile({AuthService? authService}) {
    debugPrint(
      '📱 [NgrokService] Mobile service initialized (limited support)',
    );
  }

  @override
  NgrokConfig get config => _config;

  @override
  NgrokTunnel? get activeTunnel => null;

  @override
  bool get isRunning => false;

  @override
  bool get isStarting => false;

  @override
  String? get lastError => null;

  @override
  bool get isSupported => false; // Limited support on mobile

  @override
  Future<void> initialize() async {
    debugPrint('📱 [NgrokService] Mobile platform - limited ngrok support');
  }

  @override
  Future<NgrokTunnel?> startTunnel(NgrokConfig config) async {
    throw UnsupportedError(
      'Ngrok tunnels are not typically supported on mobile platforms. '
      'Mobile apps should use cloud proxy connections instead.',
    );
  }

  @override
  Future<void> stopTunnel() async {
    throw UnsupportedError(
      'Ngrok tunnels are not supported on mobile platforms.',
    );
  }

  @override
  Future<bool> isNgrokInstalled() async {
    return false; // Ngrok not typically installed on mobile
  }

  @override
  Future<String?> getNgrokVersion() async {
    return null; // No version on mobile
  }

  @override
  Future<void> updateConfiguration(NgrokConfig newConfig) async {
    _config = newConfig;
    debugPrint('📱 [NgrokService] Configuration updated (no-op on mobile)');
    notifyListeners();
  }

  @override
  Future<Map<String, dynamic>> getTunnelStatus() async {
    return {
      'supported': false,
      'platform': 'mobile',
      'message': 'Ngrok tunnels are not supported on mobile platforms',
      'config': _config.toString(),
    };
  }

  @override
  void dispose() {
    super.dispose();
  }
}
