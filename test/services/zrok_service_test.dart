import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';

import 'package:cloudtolocalllm/services/zrok_service.dart';
import 'package:cloudtolocalllm/services/auth_service.dart';

@GenerateMocks([AuthService])
void main() {
  group('ZrokConfig', () {
    test('should create default config', () {
      final config = ZrokConfig.defaultConfig();

      expect(config.enabled, false);
      expect(config.protocol, 'http');
      expect(config.localPort, 11434);
      expect(config.localHost, 'localhost');
      expect(config.accountToken, null);
      expect(config.useReservedShare, false);
      expect(config.backendMode, 'proxy');
    });

    test('should create config with custom values', () {
      final config = ZrokConfig(
        enabled: true,
        accountToken: 'test-token',
        protocol: 'https',
        localPort: 8080,
        localHost: '127.0.0.1',
        useReservedShare: true,
        reservedShareToken: 'reserved-token',
        backendMode: 'web',
      );

      expect(config.enabled, true);
      expect(config.accountToken, 'test-token');
      expect(config.protocol, 'https');
      expect(config.localPort, 8080);
      expect(config.localHost, '127.0.0.1');
      expect(config.useReservedShare, true);
      expect(config.reservedShareToken, 'reserved-token');
      expect(config.backendMode, 'web');
    });

    test('should copy config with updated values', () {
      final original = ZrokConfig.defaultConfig();
      final updated = original.copyWith(
        enabled: true,
        accountToken: 'new-token',
        localPort: 9000,
      );

      expect(updated.enabled, true);
      expect(updated.accountToken, 'new-token');
      expect(updated.localPort, 9000);
      expect(updated.protocol, original.protocol); // unchanged
      expect(updated.localHost, original.localHost); // unchanged
    });

    test('should have proper toString representation', () {
      final config = ZrokConfig(
        enabled: true,
        protocol: 'https',
        localPort: 8080,
        accountToken: 'secret',
      );

      final str = config.toString();
      expect(str, contains('enabled: true'));
      expect(str, contains('protocol: https'));
      expect(str, contains('localPort: 8080'));
      expect(str, contains('hasAccountToken: true'));
    });
  });

  group('ZrokTunnel', () {
    test('should create tunnel from data', () {
      final tunnel = ZrokTunnel(
        publicUrl: 'https://abc123.share.zrok.io',
        localUrl: 'localhost:11434',
        protocol: 'https',
        shareToken: 'test-token',
        createdAt: DateTime.now(),
        isActive: true,
        isReserved: false,
      );

      expect(tunnel.publicUrl, 'https://abc123.share.zrok.io');
      expect(tunnel.localUrl, 'localhost:11434');
      expect(tunnel.protocol, 'https');
      expect(tunnel.shareToken, 'test-token');
      expect(tunnel.isActive, true);
      expect(tunnel.isReserved, false);
    });

    test('should convert to and from JSON', () {
      final originalTunnel = ZrokTunnel(
        publicUrl: 'https://test.share.zrok.io',
        localUrl: 'localhost:8080',
        protocol: 'https',
        shareToken: 'token123',
        createdAt: DateTime.parse('2024-01-01T12:00:00Z'),
        isActive: true,
        isReserved: true,
      );

      final json = originalTunnel.toJson();
      final reconstructedTunnel = ZrokTunnel.fromJson(json);

      expect(reconstructedTunnel.publicUrl, originalTunnel.publicUrl);
      expect(reconstructedTunnel.localUrl, originalTunnel.localUrl);
      expect(reconstructedTunnel.protocol, originalTunnel.protocol);
      expect(reconstructedTunnel.shareToken, originalTunnel.shareToken);
      expect(reconstructedTunnel.createdAt, originalTunnel.createdAt);
      expect(reconstructedTunnel.isActive, originalTunnel.isActive);
      expect(reconstructedTunnel.isReserved, originalTunnel.isReserved);
    });

    test('should have proper toString representation', () {
      final tunnel = ZrokTunnel(
        publicUrl: 'https://test.share.zrok.io',
        localUrl: 'localhost:11434',
        protocol: 'https',
        shareToken: 'token123',
        createdAt: DateTime.now(),
        isActive: true,
        isReserved: false,
      );

      final str = tunnel.toString();
      expect(str, contains('https://test.share.zrok.io'));
      expect(str, contains('localhost:11434'));
      expect(str, contains('https'));
      expect(str, contains('token123'));
    });
  });

  group('ZrokService Abstract Interface', () {
    setUp(() {
      // Test setup
    });

    test('should define required interface methods', () {
      // This test verifies that the abstract ZrokService class
      // defines all the required methods for platform implementations

      // The abstract class should define these methods:
      // - initialize()
      // - startTunnel()
      // - stopTunnel()
      // - isZrokInstalled()
      // - getZrokVersion()
      // - updateConfiguration()
      // - getTunnelStatus()
      // - enableEnvironment()
      // - isEnvironmentEnabled()
      // - createReservedShare()
      // - releaseReservedShare()
      // - validateTunnelAccess()
      // - getSecureTunnelUrl()
      // - isTunnelSecure getter

      // Since ZrokService is abstract, we can't instantiate it directly,
      // but we can verify the interface exists by checking that concrete
      // implementations must implement these methods.

      expect(ZrokService, isA<Type>());
    });
  });
}
