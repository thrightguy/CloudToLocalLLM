import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

const String projectRoot = '/opt/cloudtolocalllm';
const String mainProjectName = 'ctl_services';

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
  final baseArgs = ['compose', '-p', mainProjectName];
  print('Attempting to bring down services from: $composeFile');
  final result = await Process.run(
    'docker',
    [...baseArgs, '-f', composeFile, 'down', '--remove-orphans'],
    workingDirectory: projectRoot,
    runInShell: true,
  );
  print('docker compose down for $composeFile exited with ${result.exitCode}');
  if (result.stdout.toString().isNotEmpty) {
    print('STDOUT for $composeFile down:\n${result.stdout}');
  }
  if (result.stderr.toString().isNotEmpty) {
    print('STDERR for $composeFile down:\n${result.stderr}');
  }
}

Future<ProcessResult> _composeUp(String composeFile) async {
  final baseArgs = ['compose', '-p', mainProjectName];
  print('Attempting to bring up services from: $composeFile');
  final result = await Process.run(
    'docker',
    [...baseArgs, '-f', composeFile, 'up', '-d', '--build', '--remove-orphans'],
    workingDirectory: projectRoot,
    runInShell: true,
  );
  print('docker compose up for $composeFile exited with ${result.exitCode}');
  if (result.stdout.toString().isNotEmpty) {
    print('STDOUT for $composeFile up:\n${result.stdout}');
  }
  if (result.stderr.toString().isNotEmpty) {
    print('STDERR for $composeFile up:\n${result.stderr}');
  }
  return result;
}

Future<bool> _waitForHealthy(String serviceName,
    {int timeoutSeconds = 120}) async {
  print('Checking health for $serviceName...');
  final deadline = DateTime.now().add(Duration(seconds: timeoutSeconds));
  while (DateTime.now().isBefore(deadline)) {
    final result = await Process.run(
      'docker',
      [
        'inspect',
        '--format',
        '{{if .State.Health}}{{.State.Health.Status}}{{else}}nohealthcheck{{end}}',
        serviceName
      ],
      runInShell: true,
    );

    if (result.exitCode == 0) {
      final status = result.stdout.toString().trim();
      print('Health status for $serviceName: $status');
      if (status == 'healthy') return true;
      if (status == 'unhealthy') return false;
      if (status == 'nohealthcheck') {
        // If no healthcheck, check if container is simply running
        // Use exact name matching for ps filter
        final psResult = await Process.run(
            'docker', ['ps', '-q', '--filter', 'name=^/${serviceName}\$'],
            runInShell: true);
        if (psResult.stdout.toString().trim().isNotEmpty) {
          print('$serviceName has no healthcheck but is running.');
          return true; // Container exists and is running
        } else {
          print(
              '$serviceName has no healthcheck and is NOT running (or not found by name).');
          return false; // Container with no healthcheck is not running or doesn't exist by this name
        }
      }
      // If status is 'starting' or empty, the loop will continue after the delay.
    } else {
      // Container not found by inspect, or inspect command failed.
      print(
          'Failed to inspect $serviceName (exit code ${result.exitCode}), assuming not healthy or not found.');
      if (result.stderr.toString().isNotEmpty) {
        print('Inspect stderr for $serviceName: ${result.stderr}');
      }
      return false; // Could not inspect, so not healthy.
    }
    await Future.delayed(Duration(seconds: 3));
  }
  print('Timeout waiting for $serviceName to become healthy.');
  return false; // Timeout
}

Future<String> _listContainers() async {
  final result = await Process.run(
    'docker',
    ['ps', '--format', 'table {{.Names}}\t{{.Status}}\t{{.Image}}'],
    runInShell: true,
  );
  return result.stdout.toString();
}

Future<String> _getContainerLogs(String containerName, {int lines = 50}) async {
  final result = await Process.run(
    'docker',
    ['logs', '--tail', lines.toString(), containerName],
    runInShell: true,
  );
  return result.stdout.toString();
}

Future<void> _removeUnhealthyOrExitedContainers() async {
  // List all containers that are unhealthy or exited
  final result = await Process.run(
    'docker',
    [
      'ps',
      '-a',
      '--filter',
      'status=exited',
      '--filter',
      'health=unhealthy',
      '--format',
      '{{.ID}}'
    ],
    runInShell: true,
  );
  final ids = result.stdout
      .toString()
      .split('\n')
      .where((id) => id.trim().isNotEmpty)
      .toList();
  for (final id in ids) {
    await Process.run('docker', ['rm', '-f', id], runInShell: true);
  }
}

Future<Response> _deployAllHandler(Request request) async {
  final results = <String, dynamic>{};
  // Order for 'up': main (defines network), then fusionauth, then monitoring (uses network)
  final composeFilesToUp = [
    'config/docker/docker-compose.yml', // Defines cloudllm-network
    'config/docker/docker-compose-fusionauth.yml',
    'config/docker/docker-compose.monitoring.yml', // Uses cloudllm-network
  ];
  // Order for 'down': reverse of 'up' is a safe default
  // final composeFilesToDown = composeFilesToUp.reversed.toList(); // Removed for less aggressive cleanup

  final serviceNames = [
    'cloudtolocalllm-fusionauth-app',
    'cloudtolocalllm-fusionauth-postgres',
    'cloudtolocalllm-webapp',
    'cloudtolocalllm-nginx',
    'cloudtolocalllm-tunnel',
    'cloudtolocalllm_monitor',
    'cloudtolocalllm-certbot'
  ];
  final unhealthy = <String, dynamic>{};
  final failedComposeFiles =
      <String, String>{}; // To store stderr of failed compose up

  // 1. Remove any unhealthy or exited containers from previous runs.
  print(
      'Attempting to remove any unhealthy or exited containers from previous runs...');
  await _removeUnhealthyOrExitedContainers();
  print('Finished removing unhealthy/exited containers.');

  // Removed initial loop that called _composeDown for all files.
  // // 1. Stop and remove all service containers (not admin daemon)
  // for (final file in composeFilesToDown) {
  //   await _composeDown(file);
  // }

  // 2. Start and check each service
  for (final file in composeFilesToUp) {
    // Specific pre-up step for main compose file to ensure webapp is rebuilt cleanly
    if (file == 'config/docker/docker-compose.yml') {
      print(
          'Attempting to remove existing cloudtolocalllm-webapp image to ensure fresh build...');
      final rmiResult = await Process.run(
          'docker', ['rmi', '-f', 'cloudtolocalllm-webapp'],
          workingDirectory: projectRoot, runInShell: true);
      if (rmiResult.exitCode == 0) {
        print(
            'Successfully removed cloudtolocalllm-webapp image (or it did not exist).');
      } else {
        print(
            'Warning: Failed to remove cloudtolocalllm-webapp image. Stderr: ${rmiResult.stderr}');
      }
    }

    final composeUpResult = await _composeUp(file);
    if (composeUpResult.exitCode != 0) {
      print(
          'ERROR: docker compose up for $file failed with exit code ${composeUpResult.exitCode}');
      failedComposeFiles[file] = composeUpResult.stderr.toString();
    }

    for (final name in serviceNames) {
      if (unhealthy.containsKey(name)) continue;

      final healthy = await _waitForHealthy(name);
      if (!healthy) {
        if (!unhealthy.containsKey(name)) {
          final logs = await _getContainerLogs(name, lines: 20);
          unhealthy[name] = {
            'status': 'unhealthy_or_not_found',
            'logs': logs,
            'checked_after_compose_file': file
          };
        }
      }
    }
    await _removeUnhealthyOrExitedContainers();
  }

  // 3. List all running containers
  final containers = await _listContainers();
  results['containers'] = containers;

  if (failedComposeFiles.isNotEmpty) {
    results['failed_compose_files'] = failedComposeFiles;
  }

  if (unhealthy.isNotEmpty || failedComposeFiles.isNotEmpty) {
    results['unhealthy_services'] = unhealthy;
    return Response.internalServerError(
      body: jsonEncode({
        'status':
            'Some services failed to start, compose files failed, or services are unhealthy/not_found',
        'results': results,
      }),
      headers: {'Content-Type': 'application/json'},
    );
  }

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
