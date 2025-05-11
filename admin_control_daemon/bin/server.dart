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

Future<void> _composeDown(String composeFile, {String? projectName}) async {
  final List<String> baseArgs = ['compose'];
  if (projectName != null && projectName.isNotEmpty) {
    baseArgs.addAll(['-p', projectName]);
  }
  print(
      'Attempting to bring down services from: $composeFile using project name: ${projectName ?? 'default'}');
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

Future<ProcessResult> _composeUp(String composeFile,
    {String? projectName}) async {
  final List<String> baseArgs = ['compose'];
  if (projectName != null && projectName.isNotEmpty) {
    baseArgs.addAll(['-p', projectName]);
  }
  print(
      'Attempting to bring up services from: $composeFile using project name: ${projectName ?? 'default'}');
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

Future<Map<String, dynamic>> _getContainerHealth(
    String containerNameOrId) async {
  // Try to get the specific health status first
  // Uses Go template to extract health status. Docker inspect might return an array of containers.
  // Format: {{json .State.Health}} will give the Health sub-object as JSON.
  // If no health check is defined, .State.Health might be null.
  final result = await Process.run('docker', [
    'inspect',
    '--format={{json .State.Health}}',
    containerNameOrId
  ]); // MODIFIED: Removed extra single quotes from --format argument
  if (result.exitCode == 0) {
    try {
      // The output from {{json .State.Health}} might be 'null' (a string) if no health check,
      // or a JSON string like '{\"Status\":\"starting\",\"FailingStreak\":0,\"Log\":[]}'
      final healthJson = result.stdout.toString().trim();
      if (healthJson.isNotEmpty && healthJson != "null") {
        return jsonDecode(healthJson) as Map<String, dynamic>;
      } else if (healthJson == "null") {
        // If healthJson is "null", it means .State.Health was null (e.g. no healthcheck defined).
        // We treat this as 'unknown' or implicitly 'healthy' if the container is running.
        // For _waitForHealthy, we need a definite 'healthy' status.
        // Let\'s check basic running state if health status is null.
        final runningCheck = await Process.run('docker',
            ['inspect', '--format={{.State.Running}}', containerNameOrId]);
        if (runningCheck.exitCode == 0 &&
            runningCheck.stdout.toString().trim() == 'true') {
          // If no healthcheck but container is running, consider it healthy for basic checks.
          // However, our _waitForHealthy specifically looks for Docker\'s health status.
          // So, returning \'unknown\' here is more accurate if .State.Health was null.
          return {
            'Status': 'healthy_but_no_check'
          }; // Special status if running but no healthcheck configured
        }
      }
    } catch (e) {
      print(
          'Error decoding health status for $containerNameOrId: $e. stdout: "${result.stdout}"');
    }
  } else {
    print(
        'Docker inspect failed for $containerNameOrId with exit code ${result.exitCode}. stderr: ${result.stderr}');
  }
  return {'Status': 'unknown'}; // Default if inspect fails or no health info
}

Future<bool> _waitForHealthy(
    String serviceKey, // Renamed from serviceName to serviceKey for clarity
    String composeFilePath,
    String projectName,
    Map<String, dynamic> serviceData, // Added serviceData parameter
    {int retries = 18,
    Duration interval = const Duration(seconds: 10)}) async {
  String containerNameToInspect;

  if (serviceData.containsKey('container_name')) {
    containerNameToInspect = serviceData['container_name'] as String;
    print(
        'Using explicit container_name for $serviceKey: $containerNameToInspect');
  } else {
    containerNameToInspect = '${projectName}-${serviceKey}-1';
    print('Using default pattern for $serviceKey: $containerNameToInspect');
  }

  print('Waiting for $containerNameToInspect to become healthy...');

  for (int i = 0; i < retries; i++) {
    await Future.delayed(interval);
    final health = await _getContainerHealth(containerNameToInspect);
    final status = health['Status'];
    print(
        'Attempt ${i + 1}/${retries}: Health status for $containerNameToInspect is "$status".');

    if (status == 'healthy') {
      print('$containerNameToInspect is healthy.');
      return true;
    }
    // Optional: Treat 'healthy_but_no_check' as success if applicable
    // if (status == 'healthy_but_no_check') {
    //   print('$containerNameToInspect is running (no Docker health check, considered healthy).');
    //   return true;
    // }
  }

  print(
      '$containerNameToInspect did not become healthy after ${retries * interval.inSeconds} seconds.');
  final logsResult = await Process.run(
      'docker', ['logs', '--tail', '50', containerNameToInspect]);
  if (logsResult.exitCode == 0) {
    print(
        'Last 50 log lines for $containerNameToInspect:\\n${logsResult.stdout}\\n${logsResult.stderr}');
  } else {
    print('Could not retrieve logs for $containerNameToInspect.');
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

Future<String> _getContainerLogs(String? containerName,
    {int lines = 50}) async {
  if (containerName == null) {
    print('Error: Attempted to get logs for a null container name.');
    return Future.value('Error: Container name was null.');
  }
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
  final composeFilesToUp = [
    'config/docker/docker-compose.yml',
    'config/docker/docker-compose.monitoring.yml',
  ];

  // Map compose files to their key services and any specific project name
  final Map<String, ({List<String> services, String? projectName})>
      orderedServices = {
    'config/docker/docker-compose.yml': (
      services: ['webapp', 'cloudtolocalllm-fusionauth-app'],
      projectName: mainProjectName
    ),
    // 'config/docker/docker-compose.monitoring.yml': (
    //   services: ['cloudtolocalllm_monitor'],
    //   projectName: null
    // ),
  };

  final unhealthy = <String, dynamic>{};
  final failedComposeFiles =
      <String, String>{}; // To store stderr of failed compose up

  // 1. Remove any unhealthy or exited containers from previous runs.
  print(
      'Attempting to remove any unhealthy or exited containers from previous runs...');
  await _removeUnhealthyOrExitedContainers();
  print('Finished removing unhealthy/exited containers.');

  // Attempt to free up port 80 by stopping containers using it
  print('Attempting to free port 80...');
  try {
    final pidsResult = await Process.run(
      'docker',
      ['ps', '-q', '--filter', 'publish=80'],
      workingDirectory: projectRoot,
      runInShell: true,
    );
    if (pidsResult.exitCode == 0 &&
        pidsResult.stdout.toString().trim().isNotEmpty) {
      final containerIds = pidsResult.stdout.toString().trim().split('\n');
      for (final id in containerIds) {
        if (id.isEmpty) continue;
        print('Stopping container $id using port 80...');
        await Process.run('docker', ['stop', id],
            workingDirectory: projectRoot, runInShell: true);
        print('Removing container $id using port 80...');
        await Process.run('docker', ['rm', id],
            workingDirectory: projectRoot, runInShell: true);
      }
      print('Finished attempting to free port 80.');
    } else {
      print(
          'No containers found publishing port 80, or an error occurred listing them.');
    }
  } catch (e) {
    print('Error trying to free port 80: $e');
  }

  // 2. Start and check each service group by compose file
  for (final file in orderedServices.keys) {
    final serviceGroup = orderedServices[file]!;
    final currentProjectName = serviceGroup.projectName;

    if (file == 'config/docker/docker-compose.yml') {
      print(
          'Attempting to remove existing ${mainProjectName}-webapp image to ensure fresh build...');
      final rmiResult = await Process.run(
          'docker', ['rmi', '-f', '${mainProjectName}-webapp'],
          workingDirectory: projectRoot, runInShell: true);
      if (rmiResult.exitCode == 0) {
        print(
            'Successfully removed ${mainProjectName}-webapp image (or it did not exist).');
      } else {
        print(
            'Warning: Failed to remove ${mainProjectName}-webapp image. Stderr: ${rmiResult.stderr}');
      }
    }

    final composeUpResult =
        await _composeUp(file, projectName: currentProjectName);
    if (composeUpResult.exitCode != 0) {
      print(
          'ERROR: docker compose up for $file failed with exit code ${composeUpResult.exitCode}');
      failedComposeFiles[file] = composeUpResult.stderr.toString();
      // If compose up fails, we should probably stop deploying further
      results['failed_compose_files'] = failedComposeFiles;
      results['unhealthy_services'] =
          unhealthy; // Include any already found unhealthy services
      return Response.internalServerError(
        body: jsonEncode({
          'status':
              'A critical docker compose up command failed. Halting deployment.',
          'failed_compose_file': file,
          'results': results,
        }),
        headers: {'Content-Type': 'application/json'},
      );
    }

    // Check health for services in this group
    for (final name in serviceGroup.services) {
      if (unhealthy.containsKey(name))
        continue; // Already marked by a previous group (should not happen with this loop structure)

      String effectiveProjectName;
      if (currentProjectName != null && currentProjectName.isNotEmpty) {
        effectiveProjectName = currentProjectName;
      } else {
        // Default project name for compose files in config/docker/ when not specified
        effectiveProjectName = "docker";
      }
      final healthy =
          await _waitForHealthy(name, file, effectiveProjectName, {});
      if (!healthy) {
        final logs = await _getContainerLogs(name, lines: 20);
        unhealthy[name] = {
          'status': 'unhealthy_or_not_found',
          'logs': logs,
          'checked_after_compose_file': file
        };
        // If a key service in this group is unhealthy, stop and report.
        results['failed_compose_files'] = failedComposeFiles;
        results['unhealthy_services'] = unhealthy;
        return Response.internalServerError(
          body: jsonEncode({
            'status':
                'A key service from $file did not become healthy. Halting deployment.',
            'unhealthy_service': name,
            'results': results,
          }),
          headers: {'Content-Type': 'application/json'},
        );
      }
    }
    // Optional: Small delay between service groups if needed
    // await Future.delayed(Duration(seconds: 5));
  }

  // No need for the old serviceNames list or the loop that iterated through it
  // final serviceNames = [ ... ];
  // for (final name in serviceNames) { ... }

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
