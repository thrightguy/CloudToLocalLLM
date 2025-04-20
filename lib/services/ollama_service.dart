import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/llm_model.dart';
import '../models/message.dart';

class OllamaService {
  final String baseUrl;
  
  OllamaService({String? baseUrl}) : baseUrl = baseUrl ?? AppConfig.ollamaBaseUrl;
  
  // Check if Ollama is running
  Future<bool> isRunning() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/tags'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 5));
      
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
  
  // Get available models
  Future<List<LlmModel>> getModels() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/tags'),
        headers: {'Content-Type': 'application/json'},
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final models = (data['models'] as List? ?? []).map((model) {
          return LlmModel(
            id: model['name'],
            name: model['name'],
            provider: 'ollama',
            size: model['size'] != null ? (model['size'] as int) ~/ (1024 * 1024) : null, // Convert to MB
            isInstalled: true,
          );
        }).toList();
        
        return models;
      } else {
        throw Exception('Failed to get models: ${response.statusCode}');
      }
    } catch (e) {
      return [];
    }
  }
  
  // Generate a response
  Future<String> generateResponse(String prompt, String modelId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/generate'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'model': modelId,
          'prompt': prompt,
          'stream': false,
        }),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['response'] ?? 'No response';
      } else {
        throw Exception('Failed to generate response: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error generating response: $e');
    }
  }
  
  // Generate a streaming response
  Stream<String> generateStreamingResponse(String prompt, String modelId) async* {
    try {
      final request = http.Request('POST', Uri.parse('$baseUrl/api/generate'));
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode({
        'model': modelId,
        'prompt': prompt,
        'stream': true,
      });
      
      final streamedResponse = await http.Client().send(request);
      
      await for (final chunk in streamedResponse.stream.transform(utf8.decoder)) {
        // Ollama returns each chunk as a JSON object with a 'response' field
        try {
          final lines = chunk.split('\n').where((line) => line.isNotEmpty);
          for (final line in lines) {
            final data = jsonDecode(line);
            if (data.containsKey('response')) {
              yield data['response'] as String;
            }
          }
        } catch (e) {
          // If we can't parse the chunk as JSON, just yield it as-is
          yield chunk;
        }
      }
    } catch (e) {
      yield '[Error: $e]';
    }
  }
  
  // Pull (download) a model
  Future<void> pullModel(String modelId, {Function(double)? onProgress}) async {
    try {
      final request = http.Request('POST', Uri.parse('$baseUrl/api/pull'));
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode({
        'name': modelId,
        'stream': true,
      });
      
      final streamedResponse = await http.Client().send(request);
      
      double progress = 0.0;
      await for (final chunk in streamedResponse.stream.transform(utf8.decoder)) {
        try {
          final lines = chunk.split('\n').where((line) => line.isNotEmpty);
          for (final line in lines) {
            final data = jsonDecode(line);
            if (data.containsKey('completed') && data.containsKey('total')) {
              final completed = data['completed'] as int;
              final total = data['total'] as int;
              progress = total > 0 ? completed / total : 0.0;
              if (onProgress != null) {
                onProgress(progress);
              }
            }
          }
        } catch (e) {
          // Ignore parsing errors
        }
      }
    } catch (e) {
      throw Exception('Error pulling model: $e');
    }
  }
  
  // Delete a model
  Future<void> deleteModel(String modelId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/api/delete'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': modelId,
        }),
      );
      
      if (response.statusCode != 200) {
        throw Exception('Failed to delete model: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error deleting model: $e');
    }
  }
}