import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../config/app_config.dart';
import '../models/conversation.dart';
import '../models/llm_model.dart';
import '../models/message.dart';
import '../services/ollama_service.dart';
import '../services/storage_service.dart';

enum LlmApiType {
  free, // Local installations (Ollama, LM Studio, etc.)
  premium // API services (OpenAI, Anthropic, etc.)
}

class LlmProvider extends ChangeNotifier {
  final OllamaService ollamaService;
  final StorageService storageService;

  List<LlmModel> _models = [];
  List<Conversation> _conversations = [];
  Conversation? _currentConversation;
  bool _isLoading = false;
  String _error = '';
  String _currentProvider = AppConfig.defaultLlmProvider;
  LlmApiType _apiType = LlmApiType.free;

  LlmProvider({
    required this.ollamaService,
    required this.storageService,
  });

  // Get the current provider
  String get currentProvider => _currentProvider;

  // Get the current API type
  LlmApiType get apiType => _apiType;

  // Set the current provider
  void setCurrentProvider(String provider) {
    _currentProvider = provider;

    // Update base URL based on provider
    switch (provider) {
      case 'ollama':
        ollamaService.updateBaseUrl(AppConfig.ollamaBaseUrl);
        _apiType = LlmApiType.free;
        break;
      case 'lmstudio':
        ollamaService.updateBaseUrl(AppConfig.lmStudioBaseUrl);
        _apiType = LlmApiType.free;
        break;
      case 'openai':
        // For premium services, set flag but don't update URL yet
        _apiType = LlmApiType.premium;
        break;
      case 'anthropic':
        _apiType = LlmApiType.premium;
        break;
      default:
        // Default to Ollama
        _currentProvider = 'ollama';
        ollamaService.updateBaseUrl(AppConfig.ollamaBaseUrl);
        _apiType = LlmApiType.free;
    }

    debugPrint('LLM provider changed to: $provider (API type: $_apiType)');
    refreshModels(); // Refresh models when provider changes
    notifyListeners();
  }

  // Check if user has premium access
  Future<bool> hasPremiumAccessAsync() async {
    // During testing phase, all premium features are available
    if (AppConfig.freePremiumFeaturesDuringTesting) {
      return true;
    }

    try {
      return await storageService.getUserSubscriptionStatus();
    } catch (e) {
      debugPrint('Error checking premium access: $e');
      return false;
    }
  }

  // Synchronous version that uses cached value
  bool get hasPremiumAccess {
    // During testing phase, all users have premium access
    // This will be updated later when premium features are monetized
    return true; // Free access during testing
  }

  // Set user premium status
  Future<void> setUserPremiumStatus(bool isPremium) async {
    await storageService.saveUserSubscriptionStatus(isPremium);
    // Refresh models to reflect subscription change
    refreshModels();
  }

  // Check hardware compatibility for models
  Future<Map<String, dynamic>> checkHardwareCompatibility() async {
    // Default values if detection fails
    int availableRamMB = 4 * 1024; // Assume 4GB by default
    bool hasGPU = false;
    String gpuName = '';
    int vramMB = 0;

    try {
      // Attempt to get system information
      if (Platform.isWindows) {
        // Get total RAM
        final result = await Process.run(
            'wmic', ['OS', 'get', 'TotalVisibleMemorySize', '/Value']);
        if (result.exitCode == 0) {
          final output = result.stdout.toString();
          // Parse value from output format: "TotalVisibleMemorySize=16721736"
          final match =
              RegExp(r'TotalVisibleMemorySize=(\d+)').firstMatch(output);
          if (match != null) {
            final memoryKB = int.tryParse(match.group(1)!) ?? 0;
            availableRamMB = memoryKB ~/ 1024;
          }
        }

        // Check for GPU
        final gpuResult = await Process.run('wmic', [
          'path',
          'win32_VideoController',
          'get',
          'Name,AdapterRAM',
          '/Value'
        ]);
        if (gpuResult.exitCode == 0) {
          final output = gpuResult.stdout.toString();
          // Parse GPU name and VRAM
          final nameMatch = RegExp(r'Name=(.+)').firstMatch(output);
          if (nameMatch != null) {
            gpuName = nameMatch.group(1)!.trim();
            hasGPU = true;
          }

          final vramMatch = RegExp(r'AdapterRAM=(\d+)').firstMatch(output);
          if (vramMatch != null) {
            final vramBytes = int.tryParse(vramMatch.group(1)!) ?? 0;
            vramMB = vramBytes ~/ (1024 * 1024);
          }
        }
      } else if (Platform.isLinux) {
        // Get total RAM on Linux
        final result = await Process.run('free', ['-m']);
        if (result.exitCode == 0) {
          final output = result.stdout.toString();
          final lines = output.split('\n');
          if (lines.length > 1) {
            final memParts = lines[1].split(RegExp(r'\s+'));
            if (memParts.length > 1) {
              availableRamMB = int.tryParse(memParts[1]) ?? 4 * 1024;
            }
          }
        }

        // Check for GPU on Linux
        try {
          final gpuResult = await Process.run('lspci', []);
          if (gpuResult.exitCode == 0) {
            final output = gpuResult.stdout.toString();
            if (output.contains('NVIDIA') ||
                output.contains('AMD') ||
                output.contains('Radeon')) {
              hasGPU = true;
              // Extract GPU name (simplified)
              final gpuLines = output
                  .split('\n')
                  .where((line) =>
                      line.contains('VGA') ||
                      line.contains('3D') ||
                      line.contains('Display'))
                  .toList();
              if (gpuLines.isNotEmpty) {
                gpuName = gpuLines[0].split(':').last.trim();
              }
            }
          }
        } catch (e) {
          debugPrint('Error detecting GPU: $e');
        }
      } else if (Platform.isMacOS) {
        // Get total RAM on macOS
        final result = await Process.run('sysctl', ['-n', 'hw.memsize']);
        if (result.exitCode == 0) {
          final memBytes = int.tryParse(result.stdout.toString().trim()) ?? 0;
          availableRamMB = memBytes ~/ (1024 * 1024);
        }

        // Check for GPU on macOS
        final gpuResult =
            await Process.run('system_profiler', ['SPDisplaysDataType']);
        if (gpuResult.exitCode == 0) {
          final output = gpuResult.stdout.toString();
          // Check if it contains known GPU vendors
          if (output.contains('NVIDIA') ||
              output.contains('AMD') ||
              output.contains('Intel')) {
            hasGPU = true;

            // Extract GPU name (simplified)
            final match = RegExp(r'Chipset Model: (.+)').firstMatch(output);
            if (match != null) {
              gpuName = match.group(1)!.trim();
            }

            // Extract VRAM
            final vramMatch =
                RegExp(r'VRAM \((.+)\): (\d+) MB').firstMatch(output);
            if (vramMatch != null) {
              vramMB = int.tryParse(vramMatch.group(2)!) ?? 0;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error detecting hardware: $e');
    }

    return {
      'ram': availableRamMB,
      'hasGPU': hasGPU,
      'gpuName': gpuName,
      'vram': vramMB,
    };
  }

  // Get recommended models based on hardware
  Future<List<String>> getRecommendedModels() async {
    final hardware = await checkHardwareCompatibility();
    final int ram = hardware['ram'] as int;
    final bool hasGPU = hardware['hasGPU'] as bool;
    final int vram = hardware['vram'] as int;

    // Determine available memory for models
    // For GPU, use VRAM. For CPU-only, use a portion of RAM
    final int availableMemoryMB = hasGPU ? vram : (ram ~/ 2);

    // Model recommendations based on memory constraints
    // Using Ollama model sizing documentation
    List<String> recommendedModels = [];

    // Very small models (<2GB)
    recommendedModels.add('tinyllama');
    recommendedModels.add('phi3:mini');

    if (availableMemoryMB >= 2048) {
      // 2GB+
      recommendedModels.add('llama3:8b');
      recommendedModels.add('phi3:small');
      recommendedModels.add('gemma:2b');
    }

    if (availableMemoryMB >= 4096) {
      // 4GB+
      recommendedModels.add('llama3:70b-q4_0'); // Quantized
      recommendedModels.add('gemma:7b');
      recommendedModels.add('mistral:v1');
    }

    if (availableMemoryMB >= 8192) {
      // 8GB+
      recommendedModels.add('llama3:8b-instruct');
      recommendedModels.add('mistral:small3.1');
      recommendedModels.add('gemma3:8b-instruct');
    }

    if (availableMemoryMB >= 16384) {
      // 16GB+
      recommendedModels
          .add('llama3:70b-instruct-q4_1'); // Better quantized version
      recommendedModels.add('llama3:70b');
      recommendedModels.add('mixtral:8x7b');
    }

    if (availableMemoryMB >= 32768) {
      // 32GB+
      recommendedModels.add('llama3:70b-instruct');
      recommendedModels.add('gemma3:27b-instruct');
    }

    return recommendedModels;
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
      // Load saved provider preference
      final savedProvider = await storageService.getPreferredLlmProvider();
      if (savedProvider != null && savedProvider.isNotEmpty) {
        setCurrentProvider(savedProvider);
      }

      // Load models
      await _loadModels();

      // Load conversations
      await _loadConversations();

      // Check hardware compatibility in the background
      _checkHardwareAndRecommendModels();

      _error = '';
    } catch (e) {
      _error = 'Error initializing LLM provider: $e';
      debugPrint(_error);
    } finally {
      _setLoading(false);
    }
  }

  // Check hardware and recommend models in the background
  Future<void> _checkHardwareAndRecommendModels() async {
    try {
      final hardwareSpecs = await checkHardwareCompatibility();
      debugPrint('Hardware detected: $hardwareSpecs');

      final recommendedModels = await getRecommendedModels();
      debugPrint('Recommended models: $recommendedModels');

      // Save the list for future reference
      await storageService.saveRecommendedModels(recommendedModels);
    } catch (e) {
      debugPrint('Error checking hardware and recommending models: $e');
    }
  }

  // Pull a recommended model based on hardware capabilities
  Future<void> pullRecommendedModel({Function(double)? onProgress}) async {
    try {
      final recommendedModels = await getRecommendedModels();

      if (recommendedModels.isEmpty) {
        throw Exception('No recommended models found for your hardware');
      }

      // Choose a medium-sized model that balances capability and performance
      // Prefer instruction-tuned models as they're more useful
      String modelToPull = recommendedModels.firstWhere(
        (m) => m.contains('instruct'),
        orElse: () => recommendedModels[
            recommendedModels.length ~/ 2], // Get middle model as a fallback
      );

      // Pull the model
      _setLoading(true);
      debugPrint('Pulling recommended model: $modelToPull');

      await ollamaService.pullModel(
        modelToPull,
        onProgress: onProgress,
      );

      // Refresh models list after pulling
      await refreshModels();
    } catch (e) {
      _error = 'Error pulling recommended model: $e';
      debugPrint(_error);
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // Refresh models
  Future<void> refreshModels() async {
    await _loadModels();
  }

  // Load models based on current provider
  Future<void> _loadModels() async {
    try {
      List<LlmModel> providerModels = [];

      // For free providers (local installations)
      if (_apiType == LlmApiType.free) {
        // Check if service is running
        final isRunning = await ollamaService.isRunning();
        if (!isRunning) {
          _models = [];
          return;
        }

        // Get models from service
        providerModels = await ollamaService.getModels();
      }
      // For premium providers (API services)
      else if (_apiType == LlmApiType.premium) {
        if (!hasPremiumAccess) {
          // If user doesn't have premium access, show placeholder models
          providerModels = _getPremiumModelPlaceholders();
        } else {
          // If user has premium access, fetch actual models
          // This would connect to the actual API services
          providerModels = await _fetchPremiumModels();
        }
      }

      // Get locally stored model info
      final storedModels = await storageService.getAllLlmModels();

      // Merge the two lists, preferring current provider data but keeping additional info from stored models
      _models = providerModels.map((providerModel) {
        final storedModel = storedModels.firstWhere(
          (m) => m.id == providerModel.id && m.provider == _currentProvider,
          orElse: () => providerModel,
        );

        return providerModel.copyWith(
          description: storedModel.description ?? providerModel.description,
          lastUsed: storedModel.lastUsed ?? providerModel.lastUsed,
        );
      }).toList();

      // Add any stored models for the current provider that aren't in the fetched models
      final otherProviderModels = storedModels
          .where((m) =>
              m.provider == _currentProvider &&
              !_models.any((om) => om.id == m.id))
          .toList();

      _models.addAll(otherProviderModels);

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

  // Placeholder method for premium models when user doesn't have access
  List<LlmModel> _getPremiumModelPlaceholders() {
    if (_currentProvider == 'openai') {
      return [
        LlmModel(
          id: 'gpt-4o',
          name: 'GPT-4o',
          provider: 'openai',
          description: 'OpenAI\'s most advanced model (Premium feature)',
          isInstalled: false,
          isPremium: true,
        ),
        LlmModel(
          id: 'gpt-4-turbo',
          name: 'GPT-4 Turbo',
          provider: 'openai',
          description:
              'Advanced capabilities with faster performance (Premium feature)',
          isInstalled: false,
          isPremium: true,
        ),
        LlmModel(
          id: 'gpt-3.5-turbo',
          name: 'GPT-3.5 Turbo',
          provider: 'openai',
          description:
              'Fast and efficient model for most tasks (Premium feature)',
          isInstalled: false,
          isPremium: true,
        ),
      ];
    } else if (_currentProvider == 'anthropic') {
      return [
        LlmModel(
          id: 'claude-3-opus',
          name: 'Claude 3 Opus',
          provider: 'anthropic',
          description: 'Anthropic\'s most powerful model (Premium feature)',
          isInstalled: false,
          isPremium: true,
        ),
        LlmModel(
          id: 'claude-3-sonnet',
          name: 'Claude 3 Sonnet',
          provider: 'anthropic',
          description: 'Balanced performance and value (Premium feature)',
          isInstalled: false,
          isPremium: true,
        ),
        LlmModel(
          id: 'claude-3-haiku',
          name: 'Claude 3 Haiku',
          provider: 'anthropic',
          description: 'Fast and efficient model (Premium feature)',
          isInstalled: false,
          isPremium: true,
        ),
      ];
    }
    return [];
  }

  // Method to fetch premium models when user has access
  Future<List<LlmModel>> _fetchPremiumModels() async {
    // This would be implemented to actually connect to the services
    // For now, return the same placeholders
    return _getPremiumModelPlaceholders();
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
    // Check if this is a premium model but user doesn't have premium access
    final modelIndex = _models.indexWhere((m) => m.id == modelId);
    if (modelIndex >= 0 &&
        _models[modelIndex].isPremium == true &&
        !hasPremiumAccess) {
      throw Exception('Premium subscription required to use this model');
    }

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

      // Check if premium model and if user has access
      final model = _models.firstWhere((m) => m.id == modelId);
      if (model.isPremium == true && !hasPremiumAccess) {
        throw Exception('Premium subscription required to use this model');
      }

      // Get response from appropriate service
      String response;
      if (_apiType == LlmApiType.free) {
        response = await ollamaService.generateResponse(content, modelId);
      } else {
        // Use premium API service
        response = await _generatePremiumResponse(content, modelId);
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
        }
      }
    } finally {
      _setLoading(false);
      notifyListeners();
    }
  }

  // Method to generate response from premium API services
  Future<String> _generatePremiumResponse(String prompt, String modelId) async {
    // This would be implemented to connect to premium API services
    // For now, return a placeholder message
    return 'This is a premium feature. Please upgrade your subscription to use ${_currentProvider.toUpperCase()} models.';
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

  // Set loading state
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  // Get the best model for user's hardware
  Future<String> getBestModelForHardware() async {
    try {
      // Try to get cached recommendations first
      List<String> recommendedModels =
          await storageService.getRecommendedModels();

      // If no cached recommendations, generate them
      if (recommendedModels.isEmpty) {
        recommendedModels = await getRecommendedModels();
        await storageService.saveRecommendedModels(recommendedModels);
      }

      if (recommendedModels.isEmpty) {
        // Return a very small model as fallback
        return 'tinyllama';
      }

      // Get the most capable instruction-tuned model that's recommended
      for (final modelName in recommendedModels.reversed) {
        if (modelName.contains('instruct')) {
          return modelName;
        }
      }

      // If no instruction model found, return the most capable model
      return recommendedModels.last;
    } catch (e) {
      debugPrint('Error getting best model for hardware: $e');
      return 'tinyllama'; // Fallback to a very small model
    }
  }
}
