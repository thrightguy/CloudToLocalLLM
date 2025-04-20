import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:http/http.dart' as http;
void main() async {
  final handler = const Pipeline().addHandler(_handleRequest);
  final server = await io.serve(handler, '0.0.0.0', 8080);
  print('HTTP server started on port ');
}
Future<Response> _handleRequest(Request request) async {
  if (request.method != 'POST' || request.url.path != '/api/llm') {
    return Response(405, body: 'Method Not Allowed');
  }
  try {
    final body = await request.readAsString();
    final json = jsonDecode(body);
    final prompt = json['prompt'] as String?;
    final model = json['model'] as String? ?? 'tinyllama';
    if (prompt == null || prompt.isEmpty) {
      return Response(400, body: 'Missing or empty prompt');
    }
    final response = await _sendRequest(prompt, model);
    return Response.ok(
      jsonEncode({'response': response}),
      headers: {'Content-Type': 'application/json'},
    );
  } catch (e) {
    return Response(500, body: 'Error: ');
  }
}
Future<String> _sendRequest(String prompt, String model) async {
  final url = Uri.parse('http://ollama:11434/api/generate');
  final body = jsonEncode({'model': model, 'prompt': prompt});
  final response = await http.post(
    url,
    headers: {'Content-Type': 'application/json'},
    body: body,
  );
  if (response.statusCode == 200) {
    final json = jsonDecode(response.body);
    return json['response'] as String? ?? 'No response';
  } else {
    throw Exception('Request failed: ');
  }
}
