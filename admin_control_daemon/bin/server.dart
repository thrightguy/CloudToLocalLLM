import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:http/http.dart' as http;

const String projectRoot = '/opt/cloudtolocalllm';

// Configure routes
final _router = Router()
  ..get('/admin/health', _healthHandler)
  ..post('/admin/create-user', _createUserHandler)
  ..post('/admin/deploy/auth', _deployAuthHandler)
  ..post('/admin/deploy/web', _deployWebHandler)
  ..post('/admin/git/pull', _gitPullHandler);

// === Handlers ===

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

Future<Response> _deployAuthHandler(Request request) async {
  return await _runShellCommand(
    'docker-compose',
    ['-f', 'config/docker/docker-compose.auth.yml', 'up', '-d'],
    'deploy auth service',
  );
}

Future<Response> _deployWebHandler(Request request) async {
  return await _runShellCommand(
    'docker-compose',
    ['-f', 'config/docker/docker-compose.web.yml', 'up', '-d', '--build'],
    'deploy web service',
  );
}

Future<Response> _gitPullHandler(Request request) async {
  return await _runShellCommand(
    'git',
    ['pull', 'origin', 'master'],
    'git pull',
  );
}

// === Helper to run shell commands ===
Future<Response> _runShellCommand(
    String command, List<String> arguments, String actionName) async {
  try {
    print('Running command: $command ${arguments.join(' ')}');
    final result = await Process.run(
      command,
      arguments,
      workingDirectory: projectRoot,
      runInShell: true, // Useful for commands like git pull?
    );

    print('Command "$actionName" finished with exit code ${result.exitCode}');
    print('stdout:\n${result.stdout}');
    print('stderr:\n${result.stderr}');

    if (result.exitCode == 0) {
      return Response.ok(
        jsonEncode({
          'status': 'Success',
          'action': actionName,
          'stdout': result.stdout
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } else {
      return Response.internalServerError(
        body: jsonEncode({
          'status': 'Failed',
          'action': actionName,
          'exitCode': result.exitCode,
          'stdout': result.stdout,
          'stderr': result.stderr,
        }),
        headers: {'Content-Type': 'application/json'},
      );
    }
  } catch (e) {
    print('Error running command for $actionName: $e');
    return Response.internalServerError(
      body: jsonEncode(
          {'status': 'Error', 'action': actionName, 'error': e.toString()}),
      headers: {'Content-Type': 'application/json'},
    );
  }
}

// === Main Server Setup ===
void main(List<String> args) async {
  final port = int.tryParse(Platform.environment['PORT'] ?? '9001') ?? 9001;

  final handler = const Pipeline()
      .addMiddleware(logRequests()) // Optional: Log requests
      .addHandler(_router.call);

  final server = await shelf_io.serve(handler, InternetAddress.anyIPv4, port);
  print('Admin Control Daemon listening on port ${server.port}');
  print(
      'Auth Service URL target: ${Platform.environment['AUTH_SERVICE_URL'] ?? 'http://localhost:8000'}');
  print('Project Root for Commands: $projectRoot');
}
