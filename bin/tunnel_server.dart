import 'dart:io';
import 'dart:convert';

// Simple server that forwards requests to a local LLM
void main() async {
  final server = await HttpServer.bind(InternetAddress.anyIPv4, 8080);
  print('Tunnel server listening on port ${server.port}');

  await for (HttpRequest request in server) {
    try {
      if (request.method == 'OPTIONS') {
        handleCors(request);
        continue;
      }

      handleCors(request);

      // Process requests
      if (request.uri.path == '/api/health') {
        request.response.write(jsonEncode(
            {'status': 'ok', 'timestamp': DateTime.now().toIso8601String()}));
        await request.response.close();
      } else if (request.uri.path == '/api/v1/tunnel') {
        final body = await utf8.decoder.bind(request).join();
        final Map<String, dynamic> requestData = jsonDecode(body);

        // Log the request
        print('Received tunnel request: ${requestData['prompt']}');

        // Simulate processing time
        await Future.delayed(Duration(milliseconds: 500));

        // Return a sample response
        final Map<String, dynamic> responseData = {
          'id': 'tunnel-${DateTime.now().millisecondsSinceEpoch}',
          'response': 'This is a sample response from the tunnel service.',
          'model': 'sample-tunnel-model',
          'timestamp': DateTime.now().toIso8601String(),
        };

        request.response.write(jsonEncode(responseData));
        await request.response.close();
      } else {
        request.response.statusCode = 404;
        request.response.write('Not found');
        await request.response.close();
      }
    } catch (e) {
      print('Error handling request: $e');
      request.response.statusCode = 500;
      request.response.write('Internal server error');
      await request.response.close();
    }
  }
}

void handleCors(HttpRequest request) {
  request.response.headers.add('Access-Control-Allow-Origin', '*');
  request.response.headers
      .add('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  request.response.headers
      .add('Access-Control-Allow-Headers', 'Origin, Content-Type, Accept');

  if (request.method == 'OPTIONS') {
    request.response.statusCode = 204; // No content
    request.response.close();
  }
}
