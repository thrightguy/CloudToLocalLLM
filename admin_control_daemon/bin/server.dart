import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

const String projectRoot = '/opt/cloudtolocalllm';

// Configure routes
final _router = Router()
  ..get('/admin/health', _healthHandler)
  ..post('/admin/deploy/web', _deployWebHandler)
  ..post('/admin/deploy/fusionauth', _deployFusionAuthHandler)
  ..post('/admin/git/pull', _gitPullHandler)
  ..post('/admin/stop/web', _stopWebHandler)
  ..post('/admin/stop/fusionauth', _stopFusionAuthHandler);

// === Handlers ===

Response _healthHandler(Request request) {
  return Response.ok('{"status": "OK"}',
      headers: {'Content-Type': 'application/json'});
}

Future<Response> _deployWebHandler(Request request) async {
  return await _runShellCommand(
    'docker-compose',
    ['-f', 'config/docker/docker-compose.web.yml', 'up', '-d', '--build'],
    'deploy web service',
  );
}

Future<Response> _deployFusionAuthHandler(Request request) async {
  return await _runShellCommand(
    'docker-compose',
    ['-f', 'config/docker/docker-compose-fusionauth.yml', 'up', '-d'],
    'deploy fusionauth service',
  );
}

Future<Response> _gitPullHandler(Request request) async {
  return await _runShellCommand(
    'git',
    ['pull', 'origin', 'master'],
    'git pull',
  );
}

Future<Response> _stopWebHandler(Request request) async {
  return await _runShellCommand(
    'docker-compose',
    ['-f', 'config/docker/docker-compose.web.yml', 'down'],
    'stop web service',
  );
}

Future<Response> _stopFusionAuthHandler(Request request) async {
  return await _runShellCommand(
    'docker-compose',
    ['-f', 'config/docker/docker-compose-fusionauth.yml', 'down'],
    'stop fusionauth service',
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
  print('Project Root for Commands: $projectRoot');
}
