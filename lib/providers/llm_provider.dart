import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../config/app_config.dart';
import '../models/conversation.dart';
import '../models/llm_model.dart';
import '../models/message.dart';
import '../services/ollama_service.dart';
import '../services/storage_service.dart';

class LlmProvider extends ChangeNotifier {
  final OllamaService ollamaService;
  final StorageService storageService;

  List<LlmModel> _models = [];
  List<Conversation> _conversations = [];
  Conversation? _currentConversation;
  bool _isLoading = false;
  String _error = '';
  String _currentProvider = AppConfig.defaultLlmProvider;

  LlmProvider({
    required this.ollamaService,
    required this.storageService,
  });

  // Get the current provider
  String get currentProvider => _currentProvider;

  // Set the current provider
  void setCurrentProvider(String provider) {
    _currentProvider = provider;
    // Update OllamaService base URL
    ollamaService.updateBaseUrl(provider == 'lmstudio'
        ? AppConfig.lmStudioBaseUrl
        : AppConfig.ollamaBaseUrl);
    debugPrint('LLM provider changed to: $provider');
    refreshModels(); // Refresh models when provider changes
  }

  // Getters
  List<LlmModel> get models => _models;
  List<Conversation> get conversations => _conversations;
  Conversation? get currentConversation => _currentConversation;
  bool get isLoading => _isLoading;
  String get error => _error;

  // Initialize the provider
  Future<void> initialize() async {
    _setLoading(true);

    try {
      // Load models
      await _loadModels();

      // Load conversations
      await _loadConversations();

      _error = '';
    } catch (e) {
      _error = 'Error initializing LLM provider: $e';
      debugPrint(_error);
    } finally {
      _setLoading(false);
    }
  }

  // Load models from Ollama
  Future<void> _loadModels() async {
    try {
      // Check if Ollama is running
      final isRunning = await ollamaService.isRunning();
      if (!isRunning) {
        _models = [];
        return;
      }

      // Get models from Ollama
      final ollamaModels = await ollamaService.getModels();

      // Get locally stored model info
      final storedModels = await storageService.getAllLlmModels();

      // Merge the two lists, preferring Ollama data but keeping additional info from stored models
      _models = ollamaModels.map((ollamaModel) {
        final storedModel = storedModels.firstWhere(
          (m) => m.id == ollamaModel.id && m.provider == 'ollama',
          orElse: () => ollamaModel,
        );

        return ollamaModel.copyWith(
          description: storedModel.description ?? ollamaModel.description,
          lastUsed: storedModel.lastUsed ?? ollamaModel.lastUsed,
        );
      }).toList();

      // Add any stored models that aren't in Ollama (e.g., LM Studio models)
      final nonOllamaModels = storedModels
          .where((m) =>
              m.provider != 'ollama' || !_models.any((om) => om.id == m.id))
          .toList();

      _models.addAll(nonOllamaModels);

      // Sort models by last used, then by name
      _models.sort((a, b) {
        if (a.lastUsed != null && b.lastUsed != null) {
          return b.lastUsed!.compareTo(a.lastUsed!);
        } else if (a.lastUsed != null) {
          return -1;
        } else if (b.lastUsed != null) {
          return 1;
        } else {
          return a.name.compareTo(b.name);
        }
      });

      notifyListeners();
    } catch (e) {
      debugPrint('Error loading models: $e');
      _models = [];
    }
  }

  // Load conversations from storage
  Future<void> _loadConversations() async {
    try {
      _conversations = await storageService.getAllConversations();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading conversations: $e');
      _conversations = [];
    }
  }

  // Create a new conversation
  Future<Conversation> createConversation(String title, String modelId) async {
    final uuid = const Uuid().v4();
    final conversation = Conversation.create(
      id: uuid,
      title: title,
      modelId: modelId,
    );

    _conversations.insert(0, conversation);
    await storageService.saveConversation(conversation);

    _currentConversation = conversation;
    notifyListeners();

    return conversation;
  }

  // Set the current conversation
  void setCurrentConversation(String conversationId) {
    _currentConversation = _conversations.firstWhere(
      (c) => c.id == conversationId,
      orElse: () => _currentConversation!,
    );
    notifyListeners();
  }

  // Send a message to the current conversation
  Future<void> sendMessage(String content) async {
    if (_currentConversation == null) {
      _error = 'No active conversation';
      notifyListeners();
      return;
    }

    _setLoading(true);

    try {
      // Create user message
      final userMessageId = const Uuid().v4();
      final userMessage = Message(
        id: userMessageId,
        role: MessageRole.user,
        content: content,
      );

      // Add user message to conversation
      _currentConversation = _currentConversation!.addMessage(userMessage);
      await storageService.saveConversation(_currentConversation!);
      notifyListeners();

      // Create pending assistant message
      final assistantMessageId = const Uuid().v4();
      final pendingMessage = Message(
        id: assistantMessageId,
        role: MessageRole.assistant,
        content: '',
        isPending: true,
      );

      // Add pending message to conversation
      _currentConversation = _currentConversation!.addMessage(pendingMessage);
      notifyListeners();

      // Get model ID
      final modelId = _currentConversation!.modelId;

      // Update model last used time
      final modelIndex = _models.indexWhere((m) => m.id == modelId);
      if (modelIndex >= 0) {
        _models[modelIndex] = _models[modelIndex].copyWith(
          lastUsed: DateTime.now(),
        );
        await storageService.saveLlmModel(_models[modelIndex]);
      }

      // Get response from LLM
      final response = await ollamaService.generateResponse(content, modelId);

      // Update assistant message
      final assistantMessage = Message(
        id: assistantMessageId,
        role: MessageRole.assistant,
        content: response,
        isPending: false,
      );

      // Update conversation with assistant message
      _currentConversation = _currentConversation!.updateMessage(
        assistantMessageId,
        assistantMessage,
      );

      // Save conversation
      await storageService.saveConversation(_currentConversation!);

      _error = '';
    } catch (e) {
      _error = 'Error sending message: $e';
      debugPrint(_error);

      // If there's a pending message, mark it as error
      if (_currentConversation != null) {
        final pendingMessage = _currentConversation!.messages.lastOrNull;
        if (pendingMessage != null && pendingMessage.isPending) {
          final errorMessage = pendingMessage.copyWith(
            content: 'Error: $e',
            isPending: false,
            isError: true,
          );

          _currentConversation = _currentConversation!.updateMessage(
            pendingMessage.id,
            errorMessage,
          );

          await storageService.saveConversation(_currentConversation!);
        }
      }
    } finally {
      _setLoading(false);
      notifyListeners();
    }
  }

  // Delete a conversation
  Future<void> deleteConversation(String conversationId) async {
    _conversations.removeWhere((c) => c.id == conversationId);

    if (_currentConversation?.id == conversationId) {
      _currentConversation =
          _conversations.isNotEmpty ? _conversations.first : null;
    }

    await storageService.deleteConversation(conversationId);
    notifyListeners();
  }

  // Refresh models
  Future<void> refreshModels() async {
    await _loadModels();
  }

  // Pull (download) a model
  Future<void> pullModel(String modelId, {Function(double)? onProgress}) async {
    _setLoading(true);

    try {
      // Find the model
      final modelIndex = _models.indexWhere((m) => m.id == modelId);
      if (modelIndex < 0) {
        throw Exception('Model not found');
      }

      // Update model status
      _models[modelIndex] = _models[modelIndex].copyWith(
        isDownloading: true,
        downloadProgress: 0.0,
      );
      notifyListeners();

      // Pull the model
      await ollamaService.pullModel(
        modelId,
        onProgress: (progress) {
          _models[modelIndex] = _models[modelIndex].copyWith(
            downloadProgress: progress,
          );
          notifyListeners();

          if (onProgress != null) {
            onProgress(progress);
          }
        },
      );

      // Update model status
      _models[modelIndex] = _models[modelIndex].copyWith(
        isDownloading: false,
        isInstalled: true,
        downloadProgress: 1.0,
      );

      // Save model info
      await storageService.saveLlmModel(_models[modelIndex]);

      _error = '';
    } catch (e) {
      _error = 'Error pulling model: $e';
      debugPrint(_error);
    } finally {
      _setLoading(false);
      notifyListeners();
    }
  }

  // Delete a model
  Future<void> deleteModel(String modelId) async {
    _setLoading(true);

    try {
      // Delete from Ollama
      await ollamaService.deleteModel(modelId);

      // Remove from models list
      _models.removeWhere((m) => m.id == modelId);

      // Delete model info
      await storageService.deleteLlmModel(modelId);

      _error = '';
    } catch (e) {
      _error = 'Error deleting model: $e';
      debugPrint(_error);
    } finally {
      _setLoading(false);
      notifyListeners();
    }
  }

  // Helper to set loading state
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
}
