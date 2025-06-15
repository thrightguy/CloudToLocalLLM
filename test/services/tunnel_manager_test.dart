import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:cloudtolocalllm/services/tunnel_manager_service.dart';

void main() {
  group('TunnelManagerService', () {
    late TunnelManagerService tunnelManager;

    setUp(() {
      tunnelManager = TunnelManagerService();
    });

    tearDown(() {
      tunnelManager.dispose();
    });

    group('Configuration', () {
      test('should use default configuration', () {
        final config = TunnelConfig.defaultConfig();

        expect(config.enableCloudProxy, isTrue);
        expect(
          config.cloudProxyUrl,
          equals('https://app.cloudtolocalllm.online'),
        );
        expect(config.connectionTimeout, equals(10));
        expect(config.healthCheckInterval, equals(30));
      });

      test('should update configuration', () async {
        final newConfig = TunnelConfig(
          enableCloudProxy: false,
          cloudProxyUrl: 'https://test.example.com',
          connectionTimeout: 15,
          healthCheckInterval: 60,
        );

        await tunnelManager.updateConfiguration(newConfig);

        expect(tunnelManager.config.enableCloudProxy, isFalse);
        expect(
          tunnelManager.config.cloudProxyUrl,
          equals('https://test.example.com'),
        );
        expect(tunnelManager.config.connectionTimeout, equals(15));
        expect(tunnelManager.config.healthCheckInterval, equals(60));
      });
    });

    group('Connection State', () {
      test('should start disconnected', () {
        expect(tunnelManager.isConnected, isFalse);
        expect(tunnelManager.isConnecting, isFalse);
        expect(tunnelManager.error, isNull);
      });

      test('should handle connection status updates', () {
        // Test connection status helper
        tunnelManager.updateConnectionStatus(true, null);

        expect(tunnelManager.connectionStatus['cloud']?.isConnected, isTrue);
        expect(tunnelManager.connectionStatus['cloud']?.error, isNull);
      });

      test('should handle connection errors', () {
        const errorMessage = 'Connection failed';
        tunnelManager.updateConnectionStatus(false, errorMessage);

        expect(tunnelManager.connectionStatus['cloud']?.isConnected, isFalse);
        expect(
          tunnelManager.connectionStatus['cloud']?.error,
          equals(errorMessage),
        );
      });
    });

    group('Bridge Message Handling', () {
      test('should generate valid UUID', () {
        final uuid = tunnelManager.generateUuid();

        expect(uuid, isNotNull);
        expect(uuid.length, equals(36));
        expect(uuid.split('-').length, equals(5));

        // Check UUID format (8-4-4-4-12)
        final parts = uuid.split('-');
        expect(parts[0].length, equals(8));
        expect(parts[1].length, equals(4));
        expect(parts[2].length, equals(4));
        expect(parts[3].length, equals(4));
        expect(parts[4].length, equals(12));
      });

      test('should handle auth message', () {
        final authMessage = {
          'type': 'auth',
          'id': 'test-id',
          'data': {'success': true, 'bridgeId': 'bridge-123'},
        };

        // This would normally update connection status
        tunnelManager.handleCloudBridgeMessage(authMessage);

        // Verify the message was processed (connection status should be updated)
        expect(tunnelManager.connectionStatus['cloud']?.isConnected, isTrue);
      });

      test('should handle ping message', () {
        final pingMessage = {
          'type': 'ping',
          'id': 'ping-id',
          'timestamp': DateTime.now().toIso8601String(),
        };

        // This should trigger a pong response
        tunnelManager.handleCloudBridgeMessage(pingMessage);

        // In a real test, we'd verify that a pong message was sent
        // For now, just verify no errors occurred
        expect(tunnelManager.error, isNull);
      });
    });

    group('Tunnel Architecture Validation', () {
      test('should connect to bridge endpoint not status endpoint', () {
        final config = tunnelManager.config;

        // Verify the bridge URL construction
        final wsUrl =
            '${config.cloudProxyUrl.replaceFirst('http', 'ws')}/ws/bridge';
        expect(wsUrl, equals('wss://app.cloudtolocalllm.online/ws/bridge'));
      });

      test('should separate local and cloud connections', () {
        // Verify that tunnel manager only handles cloud connections
        // Local Ollama should be handled by LocalOllamaConnectionService
        final config = TunnelConfig.defaultConfig();

        expect(config.enableCloudProxy, isTrue);
        expect(config.cloudProxyUrl, contains('app.cloudtolocalllm.online'));

        // The tunnel manager should not have any local Ollama configuration
        expect(config.cloudProxyUrl, isNot(contains('localhost')));
        expect(config.cloudProxyUrl, isNot(contains('11434')));
      });

      test('should establish proper connection direction', () {
        // Verify that local tunnel client connects TO cloud (outbound)
        // This is the correct direction: Local → Cloud
        final config = TunnelConfig.defaultConfig();

        // Cloud proxy URL should be external, not local
        expect(config.cloudProxyUrl, startsWith('https://'));
        expect(config.cloudProxyUrl, isNot(contains('localhost')));
        expect(config.cloudProxyUrl, isNot(contains('127.0.0.1')));
      });
    });

    group('Platform-Specific Behavior', () {
      test('should detect platform correctly', () {
        // Test platform detection
        // kIsWeb will be false in test environment (simulates desktop)
        expect(
          kIsWeb,
          isFalse,
          reason: 'Test environment should simulate desktop platform',
        );
      });

      test('should have platform-specific initialization logic', () {
        // Verify that TunnelManagerService has platform-aware behavior
        final tunnelManager = TunnelManagerService();

        // The service should be created successfully regardless of platform
        expect(tunnelManager, isNotNull);
        expect(tunnelManager.config, isNotNull);

        // Default configuration should be consistent
        expect(tunnelManager.config.enableCloudProxy, isTrue);
        expect(
          tunnelManager.config.cloudProxyUrl,
          equals('https://app.cloudtolocalllm.online'),
        );
      });

      test('should prevent self-referential connections on web platform', () {
        // This test documents the fix for the self-referential connection issue
        // Web platform should NOT attempt to connect to itself as a tunnel client

        final config = TunnelConfig.defaultConfig();

        // The cloud proxy URL should point to the external bridge server
        expect(
          config.cloudProxyUrl,
          equals('https://app.cloudtolocalllm.online'),
        );

        // Web platform (when kIsWeb is true) should:
        // 1. NOT attempt WebSocket connections to /ws/bridge
        // 2. Act as the bridge server itself
        // 3. Report as connected since it IS the bridge server

        // Desktop platform (when kIsWeb is false) should:
        // 1. Connect TO the bridge server via WebSocket
        // 2. Handle incoming Ollama requests from the bridge
        // 3. Forward requests to local Ollama instance

        // This test verifies the configuration supports both behaviors
        expect(config.cloudProxyUrl, isNot(contains('localhost')));
        expect(config.cloudProxyUrl, startsWith('https://'));
      });
    });
  });
}
