import 'package:flutter/foundation.dart';

// Local model imports using relative paths
// Note: In the modular architecture, we use local models for app-specific functionality
// and shared models (via package imports) for cross-app compatibility
import '../models/conversation.dart';
import '../models/message.dart';

/// Chat service for managing conversations and messages
///
/// This service is part of the modular architecture and handles:
/// - Conversation management (create, select, delete, rename)
/// - Message handling within conversations
/// - State management using ChangeNotifier pattern
/// - Integration with local models for type safety
///
/// Architecture Notes:
/// - Uses local models (../models/) for app-specific data structures
/// - Provides methods compatible with UI components
/// - Maintains conversation state for the chat application
/// - Designed to work with Provider for state management
class ChatService extends ChangeNotifier {
  final List<Conversation> _conversations = [];
  Conversation? _currentConversation;
  String _selectedModel = 'llama2';
  bool _isLoading = false;
  String? _error;

  ChatService() {
    _initializeService();
  }

  // Getters
  List<Conversation> get conversations => List.unmodifiable(_conversations);
  Conversation? get currentConversation => _currentConversation;
  String get selectedModel => _selectedModel;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasMessages => _currentConversation?.messages.isNotEmpty ?? false;

  // Conversation management methods
  void Function(Conversation) get selectConversation => _selectConversation;
  void Function(Conversation) get deleteConversation => _deleteConversation;
  void Function(Conversation, String) get updateConversationTitle =>
      _updateConversationTitle;

  /// Initialize the service
  void _initializeService() {
    // Create a welcome conversation
    createConversation('Welcome to CloudToLocalLLM');
  }

  /// Create a new conversation
  Conversation createConversation([String? title]) {
    final conversation = Conversation(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title ?? 'New Conversation',
      messages: [],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      model: _selectedModel,
    );

    _conversations.add(conversation);
    _currentConversation = conversation;

    // Add welcome message if it's the first conversation
    if (_conversations.length == 1) {
      final welcomeMessage = Message.assistant(
        content:
            'Welcome to CloudToLocalLLM Chat! This is a demo of the three-application architecture.',
        model: _selectedModel,
      );
      _currentConversation = _currentConversation!.addMessage(welcomeMessage);
      _conversations[_conversations.length - 1] = _currentConversation!;
    }

    notifyListeners();
    return conversation;
  }

  /// Select a conversation
  void _selectConversation(Conversation conversation) {
    _currentConversation = conversation;
    notifyListeners();
  }

  /// Delete a conversation
  void _deleteConversation(Conversation conversation) {
    _conversations.removeWhere((c) => c.id == conversation.id);
    if (_currentConversation?.id == conversation.id) {
      _currentConversation = _conversations.isNotEmpty
          ? _conversations.first
          : null;
    }
    notifyListeners();
  }

  /// Update conversation title
  void _updateConversationTitle(Conversation conversation, String newTitle) {
    final index = _conversations.indexWhere((c) => c.id == conversation.id);
    if (index != -1) {
      _conversations[index] = conversation.copyWith(title: newTitle);
      if (_currentConversation?.id == conversation.id) {
        _currentConversation = _conversations[index];
      }
      notifyListeners();
    }
  }

  /// Set selected model
  void setSelectedModel(String model) {
    _selectedModel = model;
    notifyListeners();
  }

  /// Send a message
  Future<void> sendMessage(String content) async {
    if (content.trim().isEmpty) return;
    if (_currentConversation == null) {
      createConversation();
    }

    _setLoading(true);
    _clearError();

    try {
      // Add user message
      final userMessage = Message.user(content: content.trim());
      _currentConversation = _currentConversation!.addMessage(userMessage);
      _updateConversationInList(_currentConversation!);
      notifyListeners();

      // Simulate processing delay
      await Future.delayed(const Duration(seconds: 1));

      // Add bot response (placeholder)
      final assistantMessage = Message.assistant(
        content:
            'Thank you for your message: "$content". This is a demo response from the chat application using model $_selectedModel.',
        model: _selectedModel,
      );
      _currentConversation = _currentConversation!.addMessage(assistantMessage);
      _updateConversationInList(_currentConversation!);
    } catch (e) {
      _setError('Failed to send message: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Update conversation in the list
  void _updateConversationInList(Conversation conversation) {
    final index = _conversations.indexWhere((c) => c.id == conversation.id);
    if (index != -1) {
      _conversations[index] = conversation;
    }
  }

  /// Set loading state
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  /// Set error state
  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  /// Clear error
  void _clearError() {
    _error = null;
    notifyListeners();
  }
}
