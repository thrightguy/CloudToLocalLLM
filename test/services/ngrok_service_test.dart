import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:cloudtolocalllm/services/ngrok_service.dart';
import 'package:cloudtolocalllm/services/ngrok_service_desktop.dart';
import 'package:cloudtolocalllm/services/auth_service.dart';

// Generate mocks
@GenerateMocks([AuthService])
import 'ngrok_service_test.mocks.dart';

void main() {
  group('NgrokConfig', () {
    test('should create default config', () {
      final config = NgrokConfig.defaultConfig();

      expect(config.enabled, false);
      expect(config.protocol, 'http');
      expect(config.localPort, 11434);
      expect(config.localHost, 'localhost');
      expect(config.authToken, null);
      expect(config.subdomain, null);
    });

    test('should create config with custom values', () {
      final config = NgrokConfig(
        enabled: true,
        authToken: 'test-token',
        subdomain: 'test-subdomain',
        protocol: 'https',
        localPort: 8080,
        localHost: '127.0.0.1',
      );

      expect(config.enabled, true);
      expect(config.authToken, 'test-token');
      expect(config.subdomain, 'test-subdomain');
      expect(config.protocol, 'https');
      expect(config.localPort, 8080);
      expect(config.localHost, '127.0.0.1');
    });

    test('should copy config with updated values', () {
      final original = NgrokConfig.defaultConfig();
      final updated = original.copyWith(
        enabled: true,
        authToken: 'new-token',
        localPort: 9000,
      );

      expect(updated.enabled, true);
      expect(updated.authToken, 'new-token');
      expect(updated.localPort, 9000);
      expect(updated.protocol, original.protocol); // unchanged
      expect(updated.localHost, original.localHost); // unchanged
    });

    test('should have proper toString representation', () {
      final config = NgrokConfig(
        enabled: true,
        protocol: 'https',
        localPort: 8080,
        authToken: 'secret',
      );

      final str = config.toString();
      expect(str, contains('enabled: true'));
      expect(str, contains('protocol: https'));
      expect(str, contains('localPort: 8080'));
      expect(str, contains('hasAuthToken: true'));
    });
  });

  group('NgrokTunnel', () {
    test('should create tunnel from JSON', () {
      final json = {
        'public_url': 'https://test.ngrok.io',
        'config': {'addr': 'localhost:11434', 'subdomain': 'test'},
        'proto': 'https',
        'created_at': '2023-01-01T00:00:00Z',
      };

      final tunnel = NgrokTunnel.fromJson(json);

      expect(tunnel.publicUrl, 'https://test.ngrok.io');
      expect(tunnel.localUrl, 'localhost:11434');
      expect(tunnel.protocol, 'https');
      expect(tunnel.subdomain, 'test');
      expect(tunnel.isActive, true);
    });

    test('should convert tunnel to JSON', () {
      final tunnel = NgrokTunnel(
        publicUrl: 'https://test.ngrok.io',
        localUrl: 'localhost:11434',
        protocol: 'https',
        subdomain: 'test',
        createdAt: DateTime.parse('2023-01-01T00:00:00Z'),
        isActive: true,
      );

      final json = tunnel.toJson();

      expect(json['public_url'], 'https://test.ngrok.io');
      expect(json['local_url'], 'localhost:11434');
      expect(json['protocol'], 'https');
      expect(json['subdomain'], 'test');
      expect(json['active'], true);
    });

    test('should have proper toString representation', () {
      final tunnel = NgrokTunnel(
        publicUrl: 'https://test.ngrok.io',
        localUrl: 'localhost:11434',
        protocol: 'https',
        createdAt: DateTime.now(),
        isActive: true,
      );

      final str = tunnel.toString();
      expect(str, contains('https://test.ngrok.io'));
      expect(str, contains('localhost:11434'));
      expect(str, contains('https'));
    });
  });

  group('NgrokServiceDesktop', () {
    late MockAuthService mockAuthService;
    late NgrokServiceDesktop ngrokService;

    setUp(() {
      mockAuthService = MockAuthService();
      ngrokService = NgrokServiceDesktop(authService: mockAuthService);
    });

    tearDown(() {
      ngrokService.dispose();
    });

    test('should initialize with correct default values', () {
      expect(ngrokService.isSupported, true);
      expect(ngrokService.isRunning, false);
      expect(ngrokService.isStarting, false);
      expect(ngrokService.activeTunnel, null);
      expect(ngrokService.lastError, null);
    });

    test('should validate tunnel access with authenticated user', () async {
      // Mock authenticated user
      when(mockAuthService.isAuthenticated).thenReturn(ValueNotifier(true));
      when(mockAuthService.getAccessToken()).thenReturn('valid-token');

      final isValid = await ngrokService.validateTunnelAccess();

      expect(isValid, true);
      verify(mockAuthService.isAuthenticated).called(1);
      verify(mockAuthService.getAccessToken()).called(1);
    });

    test('should reject tunnel access with unauthenticated user', () async {
      // Mock unauthenticated user
      when(mockAuthService.isAuthenticated).thenReturn(ValueNotifier(false));

      final isValid = await ngrokService.validateTunnelAccess();

      expect(isValid, false);
      verify(mockAuthService.isAuthenticated).called(1);
      verifyNever(mockAuthService.getAccessToken());
    });

    test('should reject tunnel access with no access token', () async {
      // Mock authenticated user but no token
      when(mockAuthService.isAuthenticated).thenReturn(ValueNotifier(true));
      when(mockAuthService.getAccessToken()).thenReturn(null);

      final isValid = await ngrokService.validateTunnelAccess();

      expect(isValid, false);
      verify(mockAuthService.isAuthenticated).called(1);
      verify(mockAuthService.getAccessToken()).called(1);
    });

    test('should return null secure tunnel URL when no active tunnel', () {
      final url = ngrokService.getSecureTunnelUrl();
      expect(url, null);
    });

    test('should check tunnel security based on auth service', () {
      // Test with authenticated user
      when(mockAuthService.isAuthenticated).thenReturn(ValueNotifier(true));
      expect(ngrokService.isTunnelSecure, true);

      // Test with unauthenticated user
      when(mockAuthService.isAuthenticated).thenReturn(ValueNotifier(false));
      expect(ngrokService.isTunnelSecure, false);
    });

    test('should handle missing auth service gracefully', () async {
      final serviceWithoutAuth = NgrokServiceDesktop();

      final isValid = await serviceWithoutAuth.validateTunnelAccess();
      expect(isValid, false);
      expect(serviceWithoutAuth.isTunnelSecure, false);

      serviceWithoutAuth.dispose();
    });

    test('should include security information in tunnel status', () async {
      when(mockAuthService.isAuthenticated).thenReturn(ValueNotifier(true));
      when(mockAuthService.getAccessToken()).thenReturn('valid-token');

      final status = await ngrokService.getTunnelStatus();

      expect(status['supported'], true);
      expect(status['platform'], 'desktop');
      expect(status['security'], isA<Map<String, dynamic>>());

      final security = status['security'] as Map<String, dynamic>;
      expect(security['hasAuthService'], true);
      expect(security['isAuthenticated'], true);
      expect(security['isTunnelSecure'], true);
      expect(security['accessValidated'], true);
    });

    test('should update configuration correctly', () async {
      final newConfig = NgrokConfig(
        enabled: true,
        authToken: 'test-token',
        protocol: 'https',
        localPort: 8080,
      );

      await ngrokService.updateConfiguration(newConfig);

      expect(ngrokService.config.enabled, true);
      expect(ngrokService.config.authToken, 'test-token');
      expect(ngrokService.config.protocol, 'https');
      expect(ngrokService.config.localPort, 8080);
    });
  });
}
