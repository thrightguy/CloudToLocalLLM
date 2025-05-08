import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:http/http.dart' as http;

// Configure routes
final _router = Router()
  ..get('/admin/health', _healthHandler)
  ..post('/admin/create-user', _createUserHandler);

Response _healthHandler(Request request) {
  return Response.ok('{"status": "OK"}',
      headers: {'Content-Type': 'application/json'});
}

Future<Response> _createUserHandler(Request request) async {
  try {
    final requestBody = await request.readAsString();
    final decodedBody = jsonDecode(requestBody);

    // Validate required fields (simple validation)
    if (decodedBody['username'] == null ||
        decodedBody['email'] == null ||
        decodedBody['password'] == null) {
      return Response.badRequest(
        body: '{"error": "Missing username, email, or password"}',
        headers: {'Content-Type': 'application/json'},
      );
    }

    final authServiceUrl =
        Platform.environment['AUTH_SERVICE_URL'] ?? 'http://localhost:8000';

    final response = await http.post(
      Uri.parse('$authServiceUrl/register'),
      headers: {'Content-Type': 'application/json'},
      body: requestBody, // Forward the original JSON body
    );

    return Response(response.statusCode, body: response.body, headers: {
      'Content-Type': response.headers['content-type'] ?? 'application/json'
    });
  } catch (e) {
    print('Error in _createUserHandler: $e');
    return Response.internalServerError(
      body: '{"error": "Internal server error processing create-user request"}',
      headers: {'Content-Type': 'application/json'},
    );
  }
}

void main(List<String> args) async {
  final port = int.tryParse(Platform.environment['PORT'] ?? '9001') ?? 9001;

  final handler = const Pipeline()
      .addMiddleware(logRequests()) // Optional: Log requests
      .addHandler(_router.call);

  final server = await shelf_io.serve(handler, InternetAddress.anyIPv4, port);
  print('Admin Control Daemon listening on port ${server.port}');
  print(
      'Auth Service URL target: ${Platform.environment['AUTH_SERVICE_URL'] ?? 'http://localhost:8000'}');
}
