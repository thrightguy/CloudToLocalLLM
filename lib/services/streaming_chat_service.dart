import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:rxdart/rxdart.dart';
import '../models/conversation.dart';
import '../models/message.dart';
import '../models/streaming_message.dart';

import 'streaming_service.dart';

import 'connection_manager_service.dart';

/// Enhanced chat service with real-time streaming support
///
/// Provides progressive message streaming, real-time UI updates,
/// and integration with the tunnel manager for connection routing.
class StreamingChatService extends ChangeNotifier {
  final ConnectionManagerService _connectionManager;

  List<Conversation> _conversations = [];
  Conversation? _currentConversation;
  String? _selectedModel;
  bool _isLoading = false;
  bool _isStreaming = false;

  // Streaming state
  final BehaviorSubject<String> _streamingContentSubject =
      BehaviorSubject<String>.seeded('');
  StreamSubscription<StreamingMessage>? _currentStreamSubscription;
  String _currentStreamingMessageId = '';

  StreamingChatService(this._connectionManager) {
    _initializeService();
  }

  // Getters
  List<Conversation> get conversations => List.unmodifiable(_conversations);
  Conversation? get currentConversation => _currentConversation;
  String? get selectedModel => _selectedModel;
  bool get isLoading => _isLoading;
  bool get isStreaming => _isStreaming;
  bool get hasConversations => _conversations.isNotEmpty;

  /// Stream of current streaming content for real-time UI updates
  Stream<String> get streamingContentStream => _streamingContentSubject.stream;

  /// Initialize the service
  void _initializeService() {
    // Load conversations from local storage (placeholder)
    _loadConversations();

    // Listen to connection manager changes
    _connectionManager.addListener(_onConnectionManagerChanged);
  }

  /// Handle connection manager changes
  void _onConnectionManagerChanged() {
    // Update available models when connections change
    final availableModels = _connectionManager.availableModels;
    if (availableModels.isNotEmpty) {
      // Auto-select first model if none selected
      if (_selectedModel == null) {
        _selectedModel = availableModels.first;
        debugPrint('💬 [StreamingChat] Auto-selected model: $_selectedModel');
        notifyListeners();
      }
    }
  }

  /// Load conversations from storage (placeholder implementation)
  void _loadConversations() {
    // TODO: Implement actual storage loading
    // For now, create a sample conversation if none exist
    if (_conversations.isEmpty) {
      final sampleConversation = Conversation.create(
        title: 'Welcome Chat',
        model: _selectedModel,
      );

      final welcomeMessage = Message.system(
        content:
            'Welcome to CloudToLocalLLM! I\'m ready to help you with any questions or tasks. What would you like to talk about?',
      );

      _conversations = [sampleConversation.addMessage(welcomeMessage)];
      _currentConversation = _conversations.first;
    }
  }

  /// Save conversations to storage (placeholder implementation)
  void _saveConversations() {
    // TODO: Implement actual storage saving
    debugPrint(
      '💾 [StreamingChat] Saving ${_conversations.length} conversations',
    );
  }

  /// Create a new conversation
  void createConversation() {
    final newConversation = Conversation.create(
      title: 'New Chat',
      model: _selectedModel,
    );

    _conversations.insert(0, newConversation);
    _currentConversation = newConversation;
    _saveConversations();
    notifyListeners();
  }

  /// Select a conversation
  void selectConversation(Conversation conversation) {
    _currentConversation = conversation;

    // Cancel any ongoing streaming
    _cancelCurrentStream();

    notifyListeners();
  }

  /// Delete a conversation
  void deleteConversation(Conversation conversation) {
    _conversations.removeWhere((c) => c.id == conversation.id);

    if (_currentConversation?.id == conversation.id) {
      _currentConversation = _conversations.isNotEmpty
          ? _conversations.first
          : null;
    }

    _saveConversations();
    notifyListeners();
  }

  /// Update conversation title
  void updateConversationTitle(Conversation conversation, String newTitle) {
    final index = _conversations.indexWhere((c) => c.id == conversation.id);
    if (index != -1) {
      _conversations[index] = _conversations[index].updateTitle(newTitle);
      if (_currentConversation?.id == conversation.id) {
        _currentConversation = _conversations[index];
      }
      _saveConversations();
      notifyListeners();
    }
  }

  /// Set the selected model
  void setSelectedModel(String model) {
    _selectedModel = model;

    // Update current conversation's default model
    if (_currentConversation != null) {
      final index = _conversations.indexWhere(
        (c) => c.id == _currentConversation!.id,
      );
      if (index != -1) {
        _conversations[index] = _conversations[index].updateModel(model);
        _currentConversation = _conversations[index];
      }
    }

    notifyListeners();
  }

  /// Send a message with streaming support
  Future<void> sendMessage(String content) async {
    if (_currentConversation == null || content.trim().isEmpty) return;
    if (_selectedModel == null) {
      throw StateError('No model selected');
    }

    // Cancel any ongoing streaming
    _cancelCurrentStream();

    _setLoading(true);
    _setStreaming(false);

    try {
      // Add user message
      final userMessage = Message.user(content: content.trim());
      _addMessageToCurrentConversation(userMessage);

      // Add streaming message placeholder for assistant
      final streamingMessage = Message.streaming(model: _selectedModel!);
      _addMessageToCurrentConversation(streamingMessage);
      _currentStreamingMessageId = streamingMessage.id;

      // Get conversation history for context
      final history = _buildMessageHistory();

      // Get streaming service
      final streamingService = _getStreamingService();
      if (streamingService == null) {
        debugPrint(
          '💬 [StreamingChat] No streaming service available, falling back to non-streaming chat',
        );
        await _fallbackToNonStreamingChat(content.trim());
        return;
      }

      // Start streaming
      _setStreaming(true);
      _streamingContentSubject.add('');

      final conversationId = _currentConversation!.id;
      final messageStream = streamingService.streamResponse(
        prompt: content.trim(),
        model: _selectedModel!,
        conversationId: conversationId,
        history: history,
      );

      // Listen to streaming messages
      _currentStreamSubscription = messageStream.listen(
        (streamingMessage) => _handleStreamingMessage(streamingMessage),
        onError: (error) => _handleStreamingError(error),
        onDone: () => _handleStreamingComplete(),
      );
    } catch (e) {
      debugPrint('💬 [StreamingChat] Error in sendMessage: $e');

      // Remove streaming message if it was added
      if (_currentConversation != null &&
          _currentConversation!.messages.isNotEmpty) {
        final lastMessage = _currentConversation!.messages.last;
        if (lastMessage.isStreaming) {
          _removeLastMessage();
          debugPrint(
            '💬 [StreamingChat] Removed streaming message due to error',
          );
        }
      }

      final errorMessage = Message.assistant(
        content: 'Sorry, I encountered an error: ${e.toString()}',
        model: _selectedModel!,
        status: MessageStatus.error,
        error: e.toString(),
      );
      _addMessageToCurrentConversation(errorMessage);
    } finally {
      _setLoading(false);
      _setStreaming(false);
    }
  }

  /// Handle incoming streaming message chunks
  void _handleStreamingMessage(StreamingMessage streamingMessage) {
    if (streamingMessage.hasError) {
      _handleStreamingError(streamingMessage.error!);
      return;
    }

    if (streamingMessage.isComplete) {
      _handleStreamingComplete();
      return;
    }

    if (streamingMessage.isDataChunk) {
      // Update streaming content
      final currentContent = _streamingContentSubject.value;
      final newContent = currentContent + streamingMessage.chunk;
      _streamingContentSubject.add(newContent);

      // Update the streaming message in the conversation
      _updateStreamingMessage(newContent);
    }
  }

  /// Handle streaming error
  void _handleStreamingError(dynamic error) {
    debugPrint('💬 [StreamingChat] Streaming error: $error');

    _setStreaming(false);
    _removeLastMessage();

    final errorMessage = Message.assistant(
      content:
          'Sorry, I encountered an error while streaming: ${error.toString()}',
      model: _selectedModel!,
      status: MessageStatus.error,
      error: error.toString(),
    );
    _addMessageToCurrentConversation(errorMessage);
  }

  /// Handle streaming completion
  void _handleStreamingComplete() {
    debugPrint('💬 [StreamingChat] Streaming completed');

    _setStreaming(false);

    // Convert streaming message to final assistant message
    final finalContent = _streamingContentSubject.value;
    if (finalContent.isNotEmpty) {
      _removeLastMessage();

      final assistantMessage = Message.assistant(
        content: finalContent,
        model: _selectedModel!,
      );
      _addMessageToCurrentConversation(assistantMessage);
    }

    // Clear streaming content
    _streamingContentSubject.add('');
    _currentStreamingMessageId = '';
  }

  /// Update the streaming message content
  void _updateStreamingMessage(String content) {
    if (_currentConversation == null || _currentStreamingMessageId.isEmpty) {
      return;
    }

    final index = _conversations.indexWhere(
      (c) => c.id == _currentConversation!.id,
    );
    if (index != -1) {
      final conversation = _conversations[index];
      final messageIndex = conversation.messages.indexWhere(
        (m) => m.id == _currentStreamingMessageId,
      );

      if (messageIndex != -1) {
        final updatedMessage = conversation.messages[messageIndex].copyWith(
          content: content,
        );

        final updatedMessages = List<Message>.from(conversation.messages);
        updatedMessages[messageIndex] = updatedMessage;

        _conversations[index] = conversation.copyWith(
          messages: updatedMessages,
        );
        _currentConversation = _conversations[index];
        notifyListeners();
      }
    }
  }

  /// Get the appropriate streaming service
  StreamingService? _getStreamingService() {
    // Use connection manager to get the best streaming service
    return _connectionManager.getStreamingService();
  }

  /// Fallback to non-streaming chat when streaming is not available
  Future<void> _fallbackToNonStreamingChat(String content) async {
    try {
      debugPrint('💬 [StreamingChat] Using fallback non-streaming chat');

      // Add loading message for assistant
      final loadingMessage = Message.loading(model: _selectedModel!);
      _addMessageToCurrentConversation(loadingMessage);

      // Get conversation history for context
      final history = _buildMessageHistory();

      // Use connection manager for fallback chat
      final response = await _connectionManager.sendChatMessage(
        model: _selectedModel!,
        message: content,
        history: history,
      );

      // Remove loading message
      _removeLastMessage();

      if (response != null) {
        final assistantMessage = Message.assistant(
          content: response,
          model: _selectedModel!,
        );
        _addMessageToCurrentConversation(assistantMessage);
        debugPrint('💬 [StreamingChat] Fallback chat completed successfully');
      } else {
        final errorMessage = Message.assistant(
          content:
              'Sorry, I encountered an error while processing your request.',
          model: _selectedModel!,
          status: MessageStatus.error,
          error: 'Connection error',
        );
        _addMessageToCurrentConversation(errorMessage);
      }
    } catch (e) {
      debugPrint('💬 [StreamingChat] Fallback chat error: $e');

      // Remove loading message if it exists
      if (_currentConversation != null &&
          _currentConversation!.messages.isNotEmpty) {
        final lastMessage = _currentConversation!.messages.last;
        if (lastMessage.isLoading) {
          _removeLastMessage();
        }
      }

      final errorMessage = Message.assistant(
        content: 'Sorry, I encountered an error: ${e.toString()}',
        model: _selectedModel!,
        status: MessageStatus.error,
        error: e.toString(),
      );
      _addMessageToCurrentConversation(errorMessage);
    }
  }

  /// Cancel current streaming
  void _cancelCurrentStream() {
    _currentStreamSubscription?.cancel();
    _currentStreamSubscription = null;
    _setStreaming(false);
    _streamingContentSubject.add('');
  }

  /// Add message to current conversation
  void _addMessageToCurrentConversation(Message message) {
    try {
      if (_currentConversation == null) {
        debugPrint('Warning: Attempted to add message to null conversation');
        return;
      }

      final index = _conversations.indexWhere(
        (c) => c.id == _currentConversation!.id,
      );
      if (index != -1) {
        _conversations[index] = _conversations[index].addMessage(message);
        _currentConversation = _conversations[index];
        _saveConversations();
        notifyListeners();
      } else {
        debugPrint(
          'Warning: Current conversation not found in conversations list',
        );
      }
    } catch (e) {
      debugPrint('Error adding message to conversation: $e');
    }
  }

  /// Remove the last message from current conversation
  void _removeLastMessage() {
    try {
      if (_currentConversation == null ||
          _currentConversation!.messages.isEmpty) {
        return;
      }

      final index = _conversations.indexWhere(
        (c) => c.id == _currentConversation!.id,
      );
      if (index != -1) {
        final messages = List<Message>.from(_currentConversation!.messages);
        messages.removeLast();

        _conversations[index] = _conversations[index].copyWith(
          messages: messages,
        );
        _currentConversation = _conversations[index];
        _saveConversations();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error removing last message: $e');
    }
  }

  /// Build message history for API
  List<Map<String, String>> _buildMessageHistory() {
    if (_currentConversation == null) return [];

    return _currentConversation!.messages
        .where(
          (m) =>
              m.role != MessageRole.system &&
              m.status == MessageStatus.sent &&
              !m.isStreaming,
        )
        .map(
          (m) => {
            'role': m.role == MessageRole.user ? 'user' : 'assistant',
            'content': m.content,
          },
        )
        .toList();
  }

  /// Set loading state
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  /// Set streaming state
  void _setStreaming(bool streaming) {
    _isStreaming = streaming;
    notifyListeners();
  }

  /// Clear all conversations
  void clearAllConversations() {
    _cancelCurrentStream();
    _conversations.clear();
    _currentConversation = null;
    _saveConversations();
    notifyListeners();
  }

  @override
  void dispose() {
    debugPrint('💬 [StreamingChat] Disposing service');

    _cancelCurrentStream();
    _streamingContentSubject.close();
    _connectionManager.removeListener(_onConnectionManagerChanged);

    super.dispose();
  }
}
