import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:cloudtolocalllm/services/tunnel_manager_service.dart';
import 'package:cloudtolocalllm/services/streaming_chat_service.dart';
import 'package:cloudtolocalllm/services/local_ollama_streaming_service.dart';
import 'package:cloudtolocalllm/services/streaming_service.dart';
import 'package:cloudtolocalllm/models/streaming_message.dart';

/// Mock classes for testing
class MockTunnelManagerService extends Mock implements TunnelManagerService {}

void main() {
  group('Streaming Integration Tests', () {
    late MockTunnelManagerService mockTunnelManager;
    late StreamingChatService streamingChatService;

    setUp(() {
      mockTunnelManager = MockTunnelManagerService();
      streamingChatService = StreamingChatService(mockTunnelManager);
    });

    tearDown(() {
      streamingChatService.dispose();
    });

    test('StreamingChatService initializes correctly', () {
      // Service creates a welcome conversation by default
      expect(streamingChatService.conversations, hasLength(1));
      expect(streamingChatService.currentConversation, isNotNull);
      expect(
        streamingChatService.currentConversation!.title,
        equals('Welcome Chat'),
      );
      expect(streamingChatService.isLoading, isFalse);
      expect(streamingChatService.isStreaming, isFalse);
    });

    test('StreamingChatService creates conversation', () {
      // Start with welcome conversation (1)
      expect(streamingChatService.conversations, hasLength(1));

      streamingChatService.createConversation();

      // Now should have 2 conversations (welcome + new)
      expect(streamingChatService.conversations, hasLength(2));
      expect(streamingChatService.currentConversation, isNotNull);
      expect(
        streamingChatService.currentConversation!.title,
        equals('New Chat'),
      );
    });

    test('StreamingMessage creates chunks correctly', () {
      final chunk = StreamingMessage.chunk(
        id: 'test-id',
        conversationId: 'conv-id',
        chunk: 'Hello',
        sequence: 1,
        model: 'test-model',
      );

      expect(chunk.id, equals('test-id'));
      expect(chunk.conversationId, equals('conv-id'));
      expect(chunk.chunk, equals('Hello'));
      expect(chunk.sequence, equals(1));
      expect(chunk.isComplete, isFalse);
      expect(chunk.isDataChunk, isTrue);
      expect(chunk.hasError, isFalse);
    });

    test('StreamingMessage creates completion correctly', () {
      final completion = StreamingMessage.complete(
        id: 'test-id',
        conversationId: 'conv-id',
        sequence: 5,
        model: 'test-model',
      );

      expect(completion.id, equals('test-id'));
      expect(completion.conversationId, equals('conv-id'));
      expect(completion.sequence, equals(5));
      expect(completion.isComplete, isTrue);
      expect(completion.isDataChunk, isFalse);
      expect(completion.hasError, isFalse);
    });

    test('StreamingMessage creates error correctly', () {
      final error = StreamingMessage.error(
        id: 'test-id',
        conversationId: 'conv-id',
        error: 'Test error',
        sequence: 3,
      );

      expect(error.id, equals('test-id'));
      expect(error.conversationId, equals('conv-id'));
      expect(error.error, equals('Test error'));
      expect(error.sequence, equals(3));
      expect(error.isComplete, isTrue);
      expect(error.hasError, isTrue);
      expect(error.isDataChunk, isFalse);
    });

    test('StreamingConnection states work correctly', () {
      final disconnected = StreamingConnection.disconnected();
      expect(disconnected.state, equals(StreamingConnectionState.disconnected));
      expect(disconnected.isActive, isFalse);
      expect(disconnected.hasError, isFalse);

      final connected = StreamingConnection.connected('http://localhost:11434');
      expect(connected.state, equals(StreamingConnectionState.connected));
      expect(connected.isActive, isTrue);
      expect(connected.hasError, isFalse);
      expect(connected.endpoint, equals('http://localhost:11434'));

      final error = StreamingConnection.error('Connection failed');
      expect(error.state, equals(StreamingConnectionState.error));
      expect(error.isActive, isFalse);
      expect(error.hasError, isTrue);
      expect(error.error, equals('Connection failed'));
    });

    test('StreamingConfig factory methods work correctly', () {
      final localConfig = StreamingConfig.local();
      expect(
        localConfig.connectionTimeout,
        equals(const Duration(seconds: 10)),
      );
      expect(localConfig.maxReconnectAttempts, equals(5));
      expect(localConfig.reconnectDelay, equals(const Duration(seconds: 1)));

      final cloudConfig = StreamingConfig.cloud();
      expect(
        cloudConfig.connectionTimeout,
        equals(const Duration(seconds: 30)),
      );
      expect(cloudConfig.maxReconnectAttempts, equals(3));
      expect(cloudConfig.enableHeartbeat, isTrue);
    });

    test('StreamingMessage JSON serialization works', () {
      final original = StreamingMessage.chunk(
        id: 'test-id',
        conversationId: 'conv-id',
        chunk: 'Hello world',
        sequence: 1,
        model: 'llama2',
      );

      final json = original.toJson();
      final deserialized = StreamingMessage.fromJson(json);

      expect(deserialized.id, equals(original.id));
      expect(deserialized.conversationId, equals(original.conversationId));
      expect(deserialized.chunk, equals(original.chunk));
      expect(deserialized.sequence, equals(original.sequence));
      expect(deserialized.model, equals(original.model));
      expect(deserialized.isComplete, equals(original.isComplete));
    });

    test('StreamingChatService handles model selection', () {
      // Test initial state
      expect(streamingChatService.selectedModel, isNull);

      // Test setting model
      streamingChatService.setSelectedModel('llama2');
      expect(streamingChatService.selectedModel, equals('llama2'));

      // Create conversation and verify model is set
      streamingChatService.createConversation();
      expect(streamingChatService.currentConversation?.model, equals('llama2'));
    });

    test('StreamingChatService conversation management', () {
      // Start with welcome conversation (1), then create 1 more
      streamingChatService.createConversation();

      expect(streamingChatService.conversations, hasLength(2));

      // Test conversation selection
      final firstConversation = streamingChatService.conversations[1];
      streamingChatService.selectConversation(firstConversation);
      expect(
        streamingChatService.currentConversation?.id,
        equals(firstConversation.id),
      );

      // Test title update on current conversation
      streamingChatService.updateConversationTitle(
        firstConversation,
        'Updated Title',
      );

      final updatedConversation = streamingChatService.conversations.firstWhere(
        (c) => c.id == firstConversation.id,
      );
      expect(updatedConversation.title, equals('Updated Title'));
    });

    test('StreamingChatService clears all conversations', () {
      // Start with welcome conversation (1), create 1 more
      streamingChatService.createConversation();
      expect(streamingChatService.conversations, hasLength(2));

      // Clear all
      streamingChatService.clearAllConversations();
      expect(streamingChatService.conversations, isEmpty);
      expect(streamingChatService.currentConversation, isNull);
    });
  });

  group('LocalOllamaStreamingService Tests', () {
    test('LocalOllamaStreamingService initializes with correct defaults', () {
      final service = LocalOllamaStreamingService();

      expect(
        service.connection.state,
        equals(StreamingConnectionState.disconnected),
      );
      expect(service.messageStream, isNotNull);
    });

    test('StreamingConfig copyWith works correctly', () {
      const original = StreamingConfig();
      final modified = original.copyWith(
        connectionTimeout: const Duration(seconds: 60),
        maxReconnectAttempts: 10,
      );

      expect(modified.connectionTimeout, equals(const Duration(seconds: 60)));
      expect(modified.maxReconnectAttempts, equals(10));
      expect(
        modified.streamTimeout,
        equals(original.streamTimeout),
      ); // unchanged
      expect(
        modified.enableHeartbeat,
        equals(original.enableHeartbeat),
      ); // unchanged
    });
  });
}
