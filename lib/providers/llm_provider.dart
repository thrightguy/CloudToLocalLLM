import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../config/app_config.dart';
import '../models/conversation.dart';
import '../models/llm_model.dart';
import '../models/message.dart';
import '../services/ollama_service.dart';
import '../services/storage_service.dart';
import '../services/installation_service.dart';

class LlmProvider extends ChangeNotifier {
  final OllamaService ollamaService;
  final StorageService storageService;
  final InstallationService installationService;

  List<LlmModel> _models = [];
  List<Conversation> _conversations = [];
  Conversation? _currentConversation;
  bool _isLoading = false;
  String _error = '';
  bool _isOllamaInstalled = false;
  bool _isOllamaRunning = false;
  bool _isLmStudioInstalled = false;
  bool _isLmStudioRunning = false;

  LlmProvider({
    required this.ollamaService,
    required this.storageService,
    InstallationService? installationService,
  }) : installationService = installationService ?? InstallationService();

  // Provider status getters
  bool get isOllamaInstalled => _isOllamaInstalled;
  bool get isOllamaRunning => _isOllamaRunning;
  bool get isLmStudioInstalled => _isLmStudioInstalled;
  bool get isLmStudioRunning => _isLmStudioRunning;

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
      // Check provider installation status
      await _checkProviderStatus();

      // Load models
      await _loadModels();

      // Load conversations
      await _loadConversations();

      _error = '';
    } catch (e) {
      _error = 'Error initializing LLM provider: $e';
      print(_error);
    } finally {
      _setLoading(false);
    }
  }

  // Check if providers are installed and running
  Future<void> _checkProviderStatus() async {
    try {
      // Check Ollama status
      _isOllamaInstalled = await installationService.isOllamaInstalled();
      _isOllamaRunning = await installationService.isOllamaRunning();

      // Check LM Studio status
      _isLmStudioInstalled = await installationService.isLmStudioInstalled();
      _isLmStudioRunning = await installationService.isLmStudioRunning();

      notifyListeners();
    } catch (e) {
      print('Error checking provider status: $e');
    }
  }

  // Load models from providers
  Future<void> _loadModels() async {
    try {
      // Get locally stored model info
      final storedModels = await storageService.getAllLlmModels();
      List<LlmModel> providerModels = [];

      // Get models from Ollama if it's running
      if (_isOllamaRunning) {
        try {
          final ollamaModels = await ollamaService.getModels();

          // Merge with stored models, preferring Ollama data but keeping additional info
          providerModels.addAll(ollamaModels.map((ollamaModel) {
            final storedModel = storedModels.firstWhere(
              (m) => m.id == ollamaModel.id && m.provider == 'ollama',
              orElse: () => ollamaModel,
            );

            return ollamaModel.copyWith(
              description: storedModel.description ?? ollamaModel.description,
              lastUsed: storedModel.lastUsed ?? ollamaModel.lastUsed,
            );
          }));
        } catch (e) {
          print('Error loading Ollama models: $e');
        }
      }

      // TODO: Add LM Studio models when API is available
      // For now, just add stored LM Studio models if LM Studio is running
      if (_isLmStudioRunning) {
        final lmStudioModels = storedModels.where((m) => m.provider == 'lmstudio').toList();
        providerModels.addAll(lmStudioModels);
      }

      // Add any other stored models
      final otherModels = storedModels.where(
        (m) => !providerModels.any((pm) => pm.id == m.id && pm.provider == m.provider)
      ).toList();

      // Set final models list
      _models = [...providerModels, ...otherModels];

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
      print('Error loading models: $e');
      _models = [];
    }
  }

  // Load conversations from storage
  Future<void> _loadConversations() async {
    try {
      _conversations = await storageService.getAllConversations();
      notifyListeners();
    } catch (e) {
      print('Error loading conversations: $e');
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

      // Get model ID and determine provider
      final modelId = _currentConversation!.modelId;
      final modelIndex = _models.indexWhere((m) => m.id == modelId);
      String provider = 'ollama'; // Default to ollama

      if (modelIndex >= 0) {
        // Update model last used time
        _models[modelIndex] = _models[modelIndex].copyWith(
          lastUsed: DateTime.now(),
        );
        await storageService.saveLlmModel(_models[modelIndex]);

        // Get provider from model
        provider = _models[modelIndex].provider;
      }

      // Ensure provider is ready
      final isProviderReady = await ensureCurrentProviderReady(provider);
      if (!isProviderReady) {
        throw Exception('LLM provider is not ready. ${_error}');
      }

      // Get response from LLM
      String response;
      if (provider == 'ollama') {
        response = await ollamaService.generateResponse(content, modelId);
      } else if (provider == 'lmstudio') {
        // TODO: Implement LM Studio API integration
        throw Exception('LM Studio API integration not implemented yet');
      } else {
        throw Exception('Unknown provider: $provider');
      }

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
      print(_error);

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
      _currentConversation = _conversations.isNotEmpty ? _conversations.first : null;
    }

    await storageService.deleteConversation(conversationId);
    notifyListeners();
  }

  // Refresh models
  Future<void> refreshModels() async {
    await _checkProviderStatus();
    await _loadModels();
  }

  // Refresh provider status
  Future<void> refreshProviderStatus() async {
    await _checkProviderStatus();
  }

  // Start a provider if it's installed but not running
  Future<bool> startProvider(String provider) async {
    bool success = false;

    _setLoading(true);
    try {
      if (provider == 'ollama') {
        if (_isOllamaInstalled && !_isOllamaRunning) {
          success = await installationService.startOllama();
          if (success) {
            _isOllamaRunning = true;
            await _loadModels();
          }
        }
      } else if (provider == 'lmstudio') {
        if (_isLmStudioInstalled && !_isLmStudioRunning) {
          success = await installationService.startLmStudio();
          if (success) {
            _isLmStudioRunning = true;
            await _loadModels();
          }
        }
      }
    } catch (e) {
      print('Error starting provider: $e');
      success = false;
    } finally {
      _setLoading(false);
      notifyListeners();
    }

    return success;
  }

  // Check if the current provider is installed and running
  Future<bool> ensureCurrentProviderReady(String provider) async {
    await refreshProviderStatus();

    if (provider == 'ollama') {
      if (!_isOllamaInstalled) {
        _error = 'Ollama is not installed. Please install it from the Settings screen.';
        notifyListeners();
        return false;
      }

      if (!_isOllamaRunning) {
        _error = 'Ollama is not running. Attempting to start...';
        notifyListeners();

        final started = await startProvider('ollama');
        if (!started) {
          _error = 'Failed to start Ollama. Please start it manually or check the installation.';
          notifyListeners();
          return false;
        }
      }

      return true;
    } else if (provider == 'lmstudio') {
      if (!_isLmStudioInstalled) {
        _error = 'LM Studio is not installed. Please install it from the Settings screen.';
        notifyListeners();
        return false;
      }

      if (!_isLmStudioRunning) {
        _error = 'LM Studio is not running. Attempting to start...';
        notifyListeners();

        final started = await startProvider('lmstudio');
        if (!started) {
          _error = 'Failed to start LM Studio. Please start it manually and enable the local inference server.';
          notifyListeners();
          return false;
        }
      }

      return true;
    }

    return false;
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
      print(_error);
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
      print(_error);
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
