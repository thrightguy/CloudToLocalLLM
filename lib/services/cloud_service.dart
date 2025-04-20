import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/conversation.dart';
import '../models/llm_model.dart';
import '../models/message.dart';
import '../models/user.dart';
import 'auth_service.dart';

class CloudService {
  final String baseUrl;
  final AuthService authService;
  
  CloudService({
    String? baseUrl,
    required this.authService,
  }) : baseUrl = baseUrl ?? AppConfig.cloudBaseUrl;
  
  // Get user profile
  Future<User?> getUserProfile() async {
    if (!authService.isAuthenticated.value) return null;
    
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/user/profile'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${authService.token}',
        },
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return User.fromJson(data);
      } else {
        return null;
      }
    } catch (e) {
      print('Error getting user profile: $e');
      return null;
    }
  }
  
  // Update user profile
  Future<bool> updateUserProfile(User user) async {
    if (!authService.isAuthenticated.value) return false;
    
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/api/user/profile'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${authService.token}',
        },
        body: jsonEncode(user.toJson()),
      );
      
      return response.statusCode == 200;
    } catch (e) {
      print('Error updating user profile: $e');
      return false;
    }
  }
  
  // Get available models
  Future<List<LlmModel>> getAvailableModels() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/models'),
        headers: {
          'Content-Type': 'application/json',
          if (authService.isAuthenticated.value)
            'Authorization': 'Bearer ${authService.token}',
        },
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;
        return data.map((model) => LlmModel.fromJson(model)).toList();
      } else {
        return [];
      }
    } catch (e) {
      print('Error getting available models: $e');
      return [];
    }
  }
  
  // Get user conversations
  Future<List<Conversation>> getUserConversations() async {
    if (!authService.isAuthenticated.value) return [];
    
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/conversations'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${authService.token}',
        },
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;
        return data.map((conv) => Conversation.fromJson(conv)).toList();
      } else {
        return [];
      }
    } catch (e) {
      print('Error getting user conversations: $e');
      return [];
    }
  }
  
  // Get a specific conversation
  Future<Conversation?> getConversation(String conversationId) async {
    if (!authService.isAuthenticated.value) return null;
    
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/conversations/$conversationId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${authService.token}',
        },
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return Conversation.fromJson(data);
      } else {
        return null;
      }
    } catch (e) {
      print('Error getting conversation: $e');
      return null;
    }
  }
  
  // Create a new conversation
  Future<Conversation?> createConversation(String title, String modelId) async {
    if (!authService.isAuthenticated.value) return null;
    
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/conversations'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${authService.token}',
        },
        body: jsonEncode({
          'title': title,
          'modelId': modelId,
        }),
      );
      
      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return Conversation.fromJson(data);
      } else {
        return null;
      }
    } catch (e) {
      print('Error creating conversation: $e');
      return null;
    }
  }
  
  // Update a conversation
  Future<bool> updateConversation(Conversation conversation) async {
    if (!authService.isAuthenticated.value) return false;
    
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/api/conversations/${conversation.id}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${authService.token}',
        },
        body: jsonEncode(conversation.toJson()),
      );
      
      return response.statusCode == 200;
    } catch (e) {
      print('Error updating conversation: $e');
      return false;
    }
  }
  
  // Delete a conversation
  Future<bool> deleteConversation(String conversationId) async {
    if (!authService.isAuthenticated.value) return false;
    
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/api/conversations/$conversationId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${authService.token}',
        },
      );
      
      return response.statusCode == 200;
    } catch (e) {
      print('Error deleting conversation: $e');
      return false;
    }
  }
  
  // Send a message to a conversation
  Future<Message?> sendMessage(String conversationId, String content) async {
    if (!authService.isAuthenticated.value) return null;
    
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/conversations/$conversationId/messages'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${authService.token}',
        },
        body: jsonEncode({
          'content': content,
          'role': 'user',
        }),
      );
      
      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return Message.fromJson(data);
      } else {
        return null;
      }
    } catch (e) {
      print('Error sending message: $e');
      return null;
    }
  }
  
  // Get LLM response for a message
  Future<Message?> getLlmResponse(String conversationId, String messageId) async {
    if (!authService.isAuthenticated.value) return null;
    
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/conversations/$conversationId/messages/$messageId/response'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${authService.token}',
        },
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return Message.fromJson(data);
      } else {
        return null;
      }
    } catch (e) {
      print('Error getting LLM response: $e');
      return null;
    }
  }
}