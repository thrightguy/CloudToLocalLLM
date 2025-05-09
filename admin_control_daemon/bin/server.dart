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
  ..post('/admin/stop/fusionauth', _stopFusionAuthHandler)
  ..post('/admin/ssl/issue-renew', _issueRenewSslHandler)
  ..post('/admin/deploy/all', _deployAllHandler);

// === Handlers ===

Response _healthHandler(Request request) {
  return Response.ok('{"status": "OK"}',
      headers: {'Content-Type': 'application/json'});
}

Future<Response> _deployWebHandler(Request request) async {
  return await _runShellCommand(
    'docker',
    [
      'compose',
      '-f',
      'config/docker/docker-compose.web.yml',
      'up',
      '-d',
      '--build'
    ],
    'deploy web service',
  );
}

Future<Response> _deployFusionAuthHandler(Request request) async {
  return await _runShellCommand(
    'docker',
    [
      'compose',
      '-f',
      'config/docker/docker-compose-fusionauth.yml',
      'up',
      '-d'
    ],
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
    'docker',
    ['compose', '-f', 'config/docker/docker-compose.web.yml', 'down'],
    'stop web service',
  );
}

Future<Response> _stopFusionAuthHandler(Request request) async {
  return await _runShellCommand(
    'docker',
    ['compose', '-f', 'config/docker/docker-compose-fusionauth.yml', 'down'],
    'stop fusionauth service',
  );
}

// New handler for SSL issuance/renewal
Future<Response> _issueRenewSslHandler(Request request) async {
  // Ensure the script is executable: chmod +x scripts/ssl/manage_ssl.sh on the VPS
  return await _runShellCommand(
    './scripts/ssl/manage_ssl.sh', // Assumes execution from projectRoot
    [],
    'issue or renew SSL certificate',
  );
}

Future<void> _composeDown(String composeFile) async {
  await Process.run(
    'docker',
    ['compose', '-f', composeFile, 'down', '--remove-orphans'],
    workingDirectory: projectRoot,
    runInShell: true,
  );
}

Future<void> _composeUp(String composeFile) async {
  await Process.run(
    'docker',
    ['compose', '-f', composeFile, 'up', '-d', '--build'],
    workingDirectory: projectRoot,
    runInShell: true,
  );
}

Future<bool> _waitForHealthy(String serviceName,
    {int timeoutSeconds = 120}) async {
  final deadline = DateTime.now().add(Duration(seconds: timeoutSeconds));
  while (DateTime.now().isBefore(deadline)) {
    final result = await Process.run(
      'docker',
      ['inspect', '--format', '{{.State.Health.Status}}', serviceName],
      runInShell: true,
    );
    if (result.exitCode == 0) {
      final status = result.stdout.toString().trim();
      if (status == 'healthy') return true;
      if (status == 'unhealthy') return false;
    } else {
      // No healthcheck or container not found
      return true;
    }
    await Future.delayed(Duration(seconds: 3));
  }
  return false;
}

Future<String> _listContainers() async {
  final result = await Process.run(
    'docker',
    ['ps', '--format', 'table {{.Names}}\t{{.Status}}\t{{.Image}}'],
    runInShell: true,
  );
  return result.stdout.toString();
}

Future<Response> _deployAllHandler(Request request) async {
  final results = <String, dynamic>{};
  // Exclude the admin daemon compose file from being brought down
  final composeFilesToDown = [
    'config/docker/docker-compose-fusionauth.yml',
    'config/docker/docker-compose.web.yml',
    'config/docker/docker-compose.monitoring.yml',
    'config/docker/docker-compose.yml',
  ];
  // Only bring up the admin daemon if needed (not in this handler)
  final composeFilesToUp = composeFilesToDown;
  final serviceNames = [
    'cloudtolocalllm-fusionauth-app',
    'cloudtolocalllm-fusionauth-postgres',
    'docker-webapp-1',
    'cloudtolocalllm_monitor',
    // Add more as needed
  ];

  // 1. Stop and remove all service containers (not admin daemon)
  for (final file in composeFilesToDown) {
    await _composeDown(file);
  }

  // 2. Start and check each service
  for (final file in composeFilesToUp) {
    await _composeUp(file);
    // Wait for health if possible (for known services)
    for (final name in serviceNames) {
      await _waitForHealthy(name);
    }
  }

  // 3. List all running containers
  final containers = await _listContainers();
  results['containers'] = containers;

  return Response.ok(
    jsonEncode({
      'status': 'All services deployed and checked',
      'results': results,
    }),
    headers: {'Content-Type': 'application/json'},
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
