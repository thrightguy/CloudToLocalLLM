import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:cloudtolocalllm/services/ngrok_service.dart';
import 'package:cloudtolocalllm/services/ngrok_service_desktop.dart';
import 'package:cloudtolocalllm/services/ngrok_service_mobile.dart';
import 'package:cloudtolocalllm/services/ngrok_service_platform_web.dart';
import 'package:cloudtolocalllm/services/auth_service.dart';

// Generate mocks
@GenerateMocks([AuthService])
import 'ngrok_platform_test.mocks.dart';

void main() {
  group('Platform-Specific Ngrok Tests', () {
    late MockAuthService mockAuthService;

    setUp(() {
      mockAuthService = MockAuthService();
    });

    group('Desktop Platform', () {
      late NgrokServiceDesktop desktopService;

      setUp(() {
        desktopService = NgrokServiceDesktop(authService: mockAuthService);
      });

      tearDown(() {
        desktopService.dispose();
      });

      test('should support ngrok on desktop platform', () {
        expect(desktopService.isSupported, true);
      });

      test('should initialize with default configuration', () {
        expect(desktopService.config.enabled, false);
        expect(desktopService.config.protocol, 'http');
        expect(desktopService.config.localPort, 11434);
        expect(desktopService.config.localHost, 'localhost');
      });

      test('should validate access with authenticated user', () async {
        when(mockAuthService.isAuthenticated).thenReturn(ValueNotifier(true));
        when(mockAuthService.getAccessToken()).thenReturn('valid-token');

        final isValid = await desktopService.validateTunnelAccess();
        expect(isValid, true);
      });

      test('should reject access without authentication', () async {
        when(mockAuthService.isAuthenticated).thenReturn(ValueNotifier(false));

        final isValid = await desktopService.validateTunnelAccess();
        expect(isValid, false);
      });

      test('should handle configuration updates', () async {
        final newConfig = NgrokConfig(
          enabled: true,
          authToken: 'test-token',
          protocol: 'https',
          localPort: 8080,
        );

        await desktopService.updateConfiguration(newConfig);

        expect(desktopService.config.enabled, true);
        expect(desktopService.config.authToken, 'test-token');
        expect(desktopService.config.protocol, 'https');
        expect(desktopService.config.localPort, 8080);
      });

      test('should provide detailed tunnel status', () async {
        when(mockAuthService.isAuthenticated).thenReturn(ValueNotifier(true));
        when(mockAuthService.getAccessToken()).thenReturn('valid-token');

        final status = await desktopService.getTunnelStatus();

        expect(status['supported'], true);
        expect(status['platform'], 'desktop');
        expect(status['security'], isA<Map<String, dynamic>>());

        final security = status['security'] as Map<String, dynamic>;
        expect(security['hasAuthService'], true);
        expect(security['isAuthenticated'], true);
        expect(security['accessValidated'], true);
      });

      test('should handle missing ngrok installation gracefully', () async {
        // This test would require mocking the shell execution
        // For now, we test that the method exists and returns a boolean
        final isInstalled = await desktopService.isNgrokInstalled();
        expect(isInstalled, isA<bool>());
      });
    });

    group('Mobile Platform', () {
      late NgrokServiceMobile mobileService;

      setUp(() {
        mobileService = NgrokServiceMobile(authService: mockAuthService);
      });

      tearDown(() {
        mobileService.dispose();
      });

      test('should not support ngrok on mobile platform', () {
        expect(mobileService.isSupported, false);
      });

      test('should throw error when starting tunnel on mobile', () async {
        final config = NgrokConfig.defaultConfig();

        expect(
          () => mobileService.startTunnel(config),
          throwsA(isA<UnsupportedError>()),
        );
      });

      test('should throw error when stopping tunnel on mobile', () async {
        expect(
          () => mobileService.stopTunnel(),
          throwsA(isA<UnsupportedError>()),
        );
      });

      test('should return false for ngrok installation check', () async {
        final isInstalled = await mobileService.isNgrokInstalled();
        expect(isInstalled, false);
      });

      test('should return null for ngrok version', () async {
        final version = await mobileService.getNgrokVersion();
        expect(version, null);
      });

      test('should handle configuration updates without error', () async {
        final newConfig = NgrokConfig(enabled: true);

        // Should not throw error, but also should not actually do anything
        await mobileService.updateConfiguration(newConfig);

        expect(mobileService.config.enabled, true);
      });

      test('should provide mobile-specific tunnel status', () async {
        final status = await mobileService.getTunnelStatus();

        expect(status['supported'], false);
        expect(status['platform'], 'mobile');
        expect(status['message'], contains('not supported on mobile'));
      });
    });

    group('Web Platform', () {
      late NgrokServicePlatform webService;

      setUp(() {
        webService = NgrokServicePlatform(authService: mockAuthService);
      });

      tearDown(() {
        webService.dispose();
      });

      test('should not support ngrok on web platform', () {
        expect(webService.isSupported, false);
      });

      test('should throw error when starting tunnel on web', () async {
        final config = NgrokConfig.defaultConfig();

        expect(
          () => webService.startTunnel(config),
          throwsA(isA<UnsupportedError>()),
        );
      });

      test('should throw error when stopping tunnel on web', () async {
        expect(
          () => webService.stopTunnel(),
          throwsA(isA<UnsupportedError>()),
        );
      });

      test('should return false for ngrok installation check', () async {
        final isInstalled = await webService.isNgrokInstalled();
        expect(isInstalled, false);
      });

      test('should return null for ngrok version', () async {
        final version = await webService.getNgrokVersion();
        expect(version, null);
      });

      test('should throw error when updating configuration on web', () async {
        final newConfig = NgrokConfig(enabled: true);

        expect(
          () => webService.updateConfiguration(newConfig),
          throwsA(isA<UnsupportedError>()),
        );
      });

      test('should provide web-specific tunnel status', () async {
        final status = await webService.getTunnelStatus();

        expect(status['supported'], false);
        expect(status['platform'], 'web');
        expect(status['message'], contains('not supported on web'));
      });
    });

    group('Platform Detection', () {
      test('should create appropriate service for each platform', () {
        // Note: These tests would need to be run on actual platforms
        // or with platform-specific test configurations
        
        // For now, we test that the services can be created
        final desktopService = NgrokServiceDesktop(authService: mockAuthService);
        final mobileService = NgrokServiceMobile(authService: mockAuthService);
        final webService = NgrokServicePlatform(authService: mockAuthService);

        expect(desktopService.isSupported, true);
        expect(mobileService.isSupported, false);
        expect(webService.isSupported, false);

        desktopService.dispose();
        mobileService.dispose();
        webService.dispose();
      });
    });

    group('Security Integration', () {
      test('should validate authentication across platforms', () async {
        final services = [
          NgrokServiceDesktop(authService: mockAuthService),
          NgrokServiceMobile(authService: mockAuthService),
        ];

        when(mockAuthService.isAuthenticated).thenReturn(ValueNotifier(true));
        when(mockAuthService.getAccessToken()).thenReturn('valid-token');

        for (final service in services) {
          if (service is NgrokServiceDesktop) {
            final isValid = await service.validateTunnelAccess();
            expect(isValid, true);
          }
          service.dispose();
        }
      });

      test('should handle missing auth service gracefully', () async {
        final services = [
          NgrokServiceDesktop(),
          NgrokServiceMobile(),
        ];

        for (final service in services) {
          if (service is NgrokServiceDesktop) {
            final isValid = await service.validateTunnelAccess();
            expect(isValid, false);
            expect(service.isTunnelSecure, false);
          }
          service.dispose();
        }
      });
    });

    group('Error Handling', () {
      test('should handle auth service errors gracefully', () async {
        when(mockAuthService.isAuthenticated).thenReturn(ValueNotifier(true));
        when(mockAuthService.getAccessToken()).thenThrow(Exception('Auth error'));

        final desktopService = NgrokServiceDesktop(authService: mockAuthService);

        final isValid = await desktopService.validateTunnelAccess();
        expect(isValid, false);

        desktopService.dispose();
      });

      test('should handle configuration errors gracefully', () async {
        final desktopService = NgrokServiceDesktop(authService: mockAuthService);

        // Test with invalid configuration
        final invalidConfig = NgrokConfig(
          enabled: true,
          localPort: -1, // Invalid port
        );

        // Should not throw error during configuration update
        await desktopService.updateConfiguration(invalidConfig);
        expect(desktopService.config.localPort, -1);

        desktopService.dispose();
      });
    });
  });
}
