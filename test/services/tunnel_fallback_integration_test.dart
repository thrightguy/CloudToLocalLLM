import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:cloudtolocalllm/services/connection_manager_service.dart';
import 'package:cloudtolocalllm/services/tunnel_manager_service.dart';
import 'package:cloudtolocalllm/services/local_ollama_connection_service.dart';
import 'package:cloudtolocalllm/services/auth_service.dart';

// Generate mocks
@GenerateMocks([
  TunnelManagerService,
  LocalOllamaConnectionService,
  AuthService,
])
import 'tunnel_fallback_integration_test.mocks.dart';

void main() {
  group('Tunnel Fallback Integration Tests', () {
    late MockTunnelManagerService mockTunnelManager;
    late MockLocalOllamaConnectionService mockLocalOllama;
    late MockAuthService mockAuthService;

    late ConnectionManagerService connectionManager;

    setUp(() {
      mockTunnelManager = MockTunnelManagerService();
      mockLocalOllama = MockLocalOllamaConnectionService();
      mockAuthService = MockAuthService();

      connectionManager = ConnectionManagerService(
        localOllama: mockLocalOllama,
        tunnelManager: mockTunnelManager,
        authService: mockAuthService,
      );
    });

    tearDown(() {
      connectionManager.dispose();
    });

    test('should prefer local connection when available and preferred', () {
      // Setup: Local connection available and preferred
      when(mockLocalOllama.isConnected).thenReturn(true);
      when(mockTunnelManager.isConnected).thenReturn(true);

      final connectionType = connectionManager.getBestConnectionType();

      expect(connectionType, ConnectionType.local);
    });

    test('should fallback to cloud proxy when local unavailable', () {
      // Setup: Local connection unavailable, cloud available
      when(mockLocalOllama.isConnected).thenReturn(false);
      when(mockTunnelManager.isConnected).thenReturn(true);

      final connectionType = connectionManager.getBestConnectionType();

      expect(connectionType, ConnectionType.cloud);
    });

    test('should return none when local and cloud unavailable', () {
      // Setup: No connections available (zrok is now standalone)
      when(mockLocalOllama.isConnected).thenReturn(false);
      when(mockTunnelManager.isConnected).thenReturn(false);

      final connectionType = connectionManager.getBestConnectionType();

      expect(connectionType, ConnectionType.none);
    });

    test('should fallback to local when preferred but cloud available', () {
      // Setup: Local preferred but unavailable initially, cloud available
      when(mockLocalOllama.isConnected).thenReturn(false);
      when(mockTunnelManager.isConnected).thenReturn(true);

      var connectionType = connectionManager.getBestConnectionType();
      expect(connectionType, ConnectionType.cloud);

      // Local becomes available
      when(mockLocalOllama.isConnected).thenReturn(true);

      connectionType = connectionManager.getBestConnectionType();
      expect(connectionType, ConnectionType.local); // Should prefer local now
    });

    test('should return none when no connections available', () {
      // Setup: All connections unavailable
      when(mockLocalOllama.isConnected).thenReturn(false);
      when(mockTunnelManager.isConnected).thenReturn(false);

      final connectionType = connectionManager.getBestConnectionType();

      expect(connectionType, ConnectionType.none);
    });

    test('should report correct connection availability', () {
      // Test hasAnyConnection with different scenarios

      // No connections
      when(mockLocalOllama.isConnected).thenReturn(false);
      when(mockTunnelManager.isConnected).thenReturn(false);
      expect(connectionManager.hasAnyConnection, false);

      // Only local
      when(mockLocalOllama.isConnected).thenReturn(true);
      expect(connectionManager.hasAnyConnection, true);

      // Only cloud
      when(mockLocalOllama.isConnected).thenReturn(false);
      when(mockTunnelManager.isConnected).thenReturn(true);
      expect(connectionManager.hasAnyConnection, true);

      // All connections
      when(mockLocalOllama.isConnected).thenReturn(true);
      when(mockTunnelManager.isConnected).thenReturn(true);
      expect(connectionManager.hasAnyConnection, true);
    });

    test('should handle connection failures gracefully', () async {
      // Setup: No connections available
      when(mockLocalOllama.isConnected).thenReturn(false);
      when(mockTunnelManager.isConnected).thenReturn(false);

      // Mock local ollama failure
      when(
        mockLocalOllama.chat(
          model: anyNamed('model'),
          message: anyNamed('message'),
          history: anyNamed('history'),
        ),
      ).thenThrow(Exception('Connection failed'));

      expect(
        () => connectionManager.sendChatMessage(
          model: 'test-model',
          message: 'test message',
        ),
        throwsException,
      );
    });

    test('should initialize all connections properly', () async {
      // Mock initialization methods
      when(mockLocalOllama.initialize()).thenAnswer((_) async {});
      when(mockTunnelManager.initialize()).thenAnswer((_) async {});

      await connectionManager.initialize();

      verify(mockLocalOllama.initialize()).called(1);
      verify(mockTunnelManager.initialize()).called(1);
    });

    test('should reconnect all services', () async {
      // Mock reconnection methods
      when(mockLocalOllama.reconnect()).thenAnswer((_) async {});
      when(mockTunnelManager.reconnect()).thenAnswer((_) async {});

      await connectionManager.reconnectAll();

      verify(mockLocalOllama.reconnect()).called(1);
      verify(mockTunnelManager.reconnect()).called(1);
    });
  });
}
