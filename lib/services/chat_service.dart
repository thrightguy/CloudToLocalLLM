import 'package:flutter/foundation.dart';
import '../models/conversation.dart';
import '../models/message.dart';
import 'ollama_service.dart';

/// Service for managing chat conversations and messages
class ChatService extends ChangeNotifier {
  final OllamaService _ollamaService;
  
  List<Conversation> _conversations = [];
  Conversation? _currentConversation;
  String? _selectedModel;
  bool _isLoading = false;

  ChatService(this._ollamaService) {
    _initializeService();
  }

  // Getters
  List<Conversation> get conversations => List.unmodifiable(_conversations);
  Conversation? get currentConversation => _currentConversation;
  String? get selectedModel => _selectedModel;
  bool get isLoading => _isLoading;
  bool get hasConversations => _conversations.isNotEmpty;

  /// Initialize the service
  void _initializeService() {
    // Load conversations from local storage (placeholder)
    _loadConversations();
    
    // Listen to Ollama service changes
    _ollamaService.addListener(_onOllamaServiceChanged);
  }

  /// Handle Ollama service changes
  void _onOllamaServiceChanged() {
    // Auto-select first available model if none selected
    if (_selectedModel == null && _ollamaService.models.isNotEmpty) {
      _selectedModel = _ollamaService.models.first.name;
      notifyListeners();
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
        content: 'Welcome to CloudToLocalLLM! I\'m ready to help you with any questions or tasks. What would you like to talk about?',
      );
      
      _conversations = [sampleConversation.addMessage(welcomeMessage)];
      _currentConversation = _conversations.first;
    }
  }

  /// Save conversations to storage (placeholder implementation)
  void _saveConversations() {
    // TODO: Implement actual storage saving
    debugPrint('Saving ${_conversations.length} conversations');
  }

  /// Create a new conversation
  Conversation createConversation({String? title, String? model}) {
    final conversation = Conversation.create(
      title: title,
      model: model ?? _selectedModel,
    );
    
    _conversations.insert(0, conversation);
    _currentConversation = conversation;
    _saveConversations();
    notifyListeners();
    
    return conversation;
  }

  /// Select a conversation
  void selectConversation(String conversationId) {
    final conversation = _conversations.firstWhere(
      (c) => c.id == conversationId,
      orElse: () => throw ArgumentError('Conversation not found: $conversationId'),
    );
    
    _currentConversation = conversation;
    notifyListeners();
  }

  /// Delete a conversation
  void deleteConversation(String conversationId) {
    _conversations.removeWhere((c) => c.id == conversationId);
    
    // If deleted conversation was current, select another or create new
    if (_currentConversation?.id == conversationId) {
      if (_conversations.isNotEmpty) {
        _currentConversation = _conversations.first;
      } else {
        _currentConversation = createConversation();
      }
    }
    
    _saveConversations();
    notifyListeners();
  }

  /// Update conversation title
  void updateConversationTitle(String conversationId, String newTitle) {
    final index = _conversations.indexWhere((c) => c.id == conversationId);
    if (index != -1) {
      _conversations[index] = _conversations[index].updateTitle(newTitle);
      
      if (_currentConversation?.id == conversationId) {
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
      final index = _conversations.indexWhere((c) => c.id == _currentConversation!.id);
      if (index != -1) {
        _conversations[index] = _conversations[index].updateModel(model);
        _currentConversation = _conversations[index];
      }
    }
    
    notifyListeners();
  }

  /// Send a message in the current conversation
  Future<void> sendMessage(String content) async {
    if (_currentConversation == null || content.trim().isEmpty) return;
    if (_selectedModel == null) {
      throw StateError('No model selected');
    }

    _setLoading(true);

    try {
      // Add user message
      final userMessage = Message.user(content: content.trim());
      _addMessageToCurrentConversation(userMessage);

      // Add loading message for assistant
      final loadingMessage = Message.loading(model: _selectedModel!);
      _addMessageToCurrentConversation(loadingMessage);

      // Get conversation history for context
      final history = _buildMessageHistory();

      // Send to Ollama
      final response = await _ollamaService.chat(
        model: _selectedModel!,
        message: content.trim(),
        history: history,
      );

      // Remove loading message and add response
      _removeLastMessage();

      if (response != null) {
        final assistantMessage = Message.assistant(
          content: response,
          model: _selectedModel!,
        );
        _addMessageToCurrentConversation(assistantMessage);
      } else {
        final errorMessage = Message.assistant(
          content: 'Sorry, I encountered an error while processing your request.',
          model: _selectedModel!,
          status: MessageStatus.error,
          error: _ollamaService.error ?? 'Unknown error',
        );
        _addMessageToCurrentConversation(errorMessage);
      }
    } catch (e) {
      // Remove loading message and add error
      _removeLastMessage();
      
      final errorMessage = Message.assistant(
        content: 'Sorry, I encountered an error: ${e.toString()}',
        model: _selectedModel!,
        status: MessageStatus.error,
        error: e.toString(),
      );
      _addMessageToCurrentConversation(errorMessage);
    } finally {
      _setLoading(false);
    }
  }

  /// Add message to current conversation
  void _addMessageToCurrentConversation(Message message) {
    if (_currentConversation == null) return;
    
    final index = _conversations.indexWhere((c) => c.id == _currentConversation!.id);
    if (index != -1) {
      _conversations[index] = _conversations[index].addMessage(message);
      _currentConversation = _conversations[index];
      _saveConversations();
      notifyListeners();
    }
  }

  /// Remove the last message from current conversation
  void _removeLastMessage() {
    if (_currentConversation == null || _currentConversation!.messages.isEmpty) return;
    
    final lastMessage = _currentConversation!.messages.last;
    final index = _conversations.indexWhere((c) => c.id == _currentConversation!.id);
    if (index != -1) {
      _conversations[index] = _conversations[index].removeMessage(lastMessage.id);
      _currentConversation = _conversations[index];
      notifyListeners();
    }
  }

  /// Build message history for Ollama API
  List<Map<String, String>> _buildMessageHistory() {
    if (_currentConversation == null) return [];
    
    return _currentConversation!.messages
        .where((m) => m.role != MessageRole.system && m.status == MessageStatus.sent)
        .map((m) => {
              'role': m.role == MessageRole.user ? 'user' : 'assistant',
              'content': m.content,
            })
        .toList();
  }

  /// Set loading state
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  /// Clear all conversations
  void clearAllConversations() {
    _conversations.clear();
    _currentConversation = null;
    _saveConversations();
    notifyListeners();
  }

  @override
  void dispose() {
    _ollamaService.removeListener(_onOllamaServiceChanged);
    super.dispose();
  }
}
