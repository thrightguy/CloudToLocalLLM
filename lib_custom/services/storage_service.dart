import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import '../models/conversation.dart';
import '../models/llm_model.dart';
import '../models/user.dart';

// Keys for SharedPreferences
const String _preferredLlmProviderKey = 'preferred_llm_provider';
const String _userSubscriptionKey = 'user_subscription_status';
const String _recommendedModelsKey = 'recommended_models';

class StorageService {
  late SharedPreferences _prefs;
  late Directory _appDocDir;
  bool _initialized = false;

  // Initialize the storage service
  Future<void> initialize() async {
    if (_initialized) return;

    _prefs = await SharedPreferences.getInstance();
    _appDocDir = await getApplicationDocumentsDirectory();

    // Create necessary directories
    final conversationsDir = Directory('${_appDocDir.path}/conversations');
    final modelsDir = Directory('${_appDocDir.path}/models');

    if (!await conversationsDir.exists()) {
      await conversationsDir.create(recursive: true);
    }

    if (!await modelsDir.exists()) {
      await modelsDir.create(recursive: true);
    }

    _initialized = true;
  }

  // Save preferred LLM provider
  Future<void> savePreferredLlmProvider(String provider) async {
    await _ensureInitialized();
    await _prefs.setString(_preferredLlmProviderKey, provider);
  }

  // Get preferred LLM provider
  Future<String?> getPreferredLlmProvider() async {
    await _ensureInitialized();
    return _prefs.getString(_preferredLlmProviderKey);
  }

  // Save user subscription status
  Future<void> saveUserSubscriptionStatus(bool isPremium) async {
    await _ensureInitialized();
    await _prefs.setBool(_userSubscriptionKey, isPremium);
  }

  // Get user subscription status
  Future<bool> getUserSubscriptionStatus() async {
    await _ensureInitialized();
    return _prefs.getBool(_userSubscriptionKey) ?? false;
  }

  // Save app settings
  Future<void> saveSettings(Map<String, dynamic> settings) async {
    await _ensureInitialized();
    await _prefs.setString(AppConfig.settingsStorageKey, jsonEncode(settings));
  }

  // Get app settings
  Future<Map<String, dynamic>> getSettings() async {
    await _ensureInitialized();
    final settingsJson = _prefs.getString(AppConfig.settingsStorageKey);
    if (settingsJson == null) return {};
    return jsonDecode(settingsJson) as Map<String, dynamic>;
  }

  // Save a conversation
  Future<void> saveConversation(Conversation conversation) async {
    await _ensureInitialized();
    final file =
        File('${_appDocDir.path}/conversations/${conversation.id}.json');
    await file.writeAsString(jsonEncode(conversation.toJson()));
  }

  // Get a conversation
  Future<Conversation?> getConversation(String conversationId) async {
    await _ensureInitialized();
    final file = File('${_appDocDir.path}/conversations/$conversationId.json');
    if (!await file.exists()) return null;

    final json = jsonDecode(await file.readAsString());
    return Conversation.fromJson(json);
  }

  // Delete a conversation
  Future<void> deleteConversation(String conversationId) async {
    await _ensureInitialized();
    final file = File('${_appDocDir.path}/conversations/$conversationId.json');
    if (await file.exists()) {
      await file.delete();
    }
  }

  // Get all conversations
  Future<List<Conversation>> getAllConversations() async {
    await _ensureInitialized();
    final dir = Directory('${_appDocDir.path}/conversations');
    final List<Conversation> conversations = [];

    final files = await dir
        .list()
        .where((entity) => entity is File && entity.path.endsWith('.json'))
        .toList();

    for (final file in files) {
      try {
        final json = jsonDecode(await File(file.path).readAsString());
        conversations.add(Conversation.fromJson(json));
      } catch (e) {
        debugPrint('Error reading conversation file: $e');
      }
    }

    // Sort by last updated
    conversations.sort((a, b) => b.lastUpdated.compareTo(a.lastUpdated));
    return conversations;
  }

  // Save LLM model info
  Future<void> saveLlmModel(LlmModel model) async {
    await _ensureInitialized();
    final file = File('${_appDocDir.path}/models/${model.id}.json');
    await file.writeAsString(jsonEncode(model.toJson()));
  }

  // Get LLM model info
  Future<LlmModel?> getLlmModel(String modelId) async {
    await _ensureInitialized();
    final file = File('${_appDocDir.path}/models/$modelId.json');
    if (!await file.exists()) return null;

    final json = jsonDecode(await file.readAsString());
    return LlmModel.fromJson(json);
  }

  // Delete LLM model info
  Future<void> deleteLlmModel(String modelId) async {
    await _ensureInitialized();
    final file = File('${_appDocDir.path}/models/$modelId.json');
    if (await file.exists()) {
      await file.delete();
    }
  }

  // Get all LLM models
  Future<List<LlmModel>> getAllLlmModels() async {
    await _ensureInitialized();
    final dir = Directory('${_appDocDir.path}/models');
    final List<LlmModel> models = [];

    final files = await dir
        .list()
        .where((entity) => entity is File && entity.path.endsWith('.json'))
        .toList();

    for (final file in files) {
      try {
        final json = jsonDecode(await File(file.path).readAsString());
        models.add(LlmModel.fromJson(json));
      } catch (e) {
        debugPrint('Error reading model file: $e');
      }
    }

    // Sort by name
    models.sort((a, b) => a.name.compareTo(b.name));
    return models;
  }

  // Save user data
  Future<void> saveUser(User user) async {
    await _ensureInitialized();
    await _prefs.setString(AppConfig.userStorageKey, jsonEncode(user.toJson()));
  }

  // Get user data
  Future<User?> getUser() async {
    await _ensureInitialized();
    final userJson = _prefs.getString(AppConfig.userStorageKey);
    if (userJson == null) return null;
    return User.fromJson(jsonDecode(userJson));
  }

  // Clear all data
  Future<void> clearAllData() async {
    await _ensureInitialized();

    // Clear preferences
    await _prefs.clear();

    // Clear conversations
    final conversationsDir = Directory('${_appDocDir.path}/conversations');
    if (await conversationsDir.exists()) {
      await conversationsDir.delete(recursive: true);
      await conversationsDir.create();
    }

    // Clear models
    final modelsDir = Directory('${_appDocDir.path}/models');
    if (await modelsDir.exists()) {
      await modelsDir.delete(recursive: true);
      await modelsDir.create();
    }
  }

  // Save recommended models list
  Future<void> saveRecommendedModels(List<String> models) async {
    await _ensureInitialized();
    await _prefs.setStringList(_recommendedModelsKey, models);
  }

  // Get recommended models list
  Future<List<String>> getRecommendedModels() async {
    await _ensureInitialized();
    return _prefs.getStringList(_recommendedModelsKey) ?? [];
  }

  // Ensure the service is initialized
  Future<void> _ensureInitialized() async {
    if (!_initialized) {
      await initialize();
    }
  }
}
