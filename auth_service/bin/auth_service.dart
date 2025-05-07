import 'dart:io';
import 'package:args/args.dart';
import 'package:auth_service/auth_service.dart';

/// Command-line application to run the authentication service
Future<void> main(List<String> args) async {
  // Parse command-line arguments
  final parser = ArgParser()
    ..addFlag('help',
        abbr: 'h', negatable: false, help: 'Show usage information')
    ..addOption('port',
        abbr: 'p', help: 'Port to listen on', defaultsTo: '8000')
    ..addOption('host', help: 'Host to listen on', defaultsTo: '0.0.0.0')
    ..addOption('env',
        abbr: 'e', help: 'Environment (dev, prod)', defaultsTo: 'dev')
    ..addOption('log-level',
        help: 'Log level (info, warning, severe)', defaultsTo: 'info');

  // Parse arguments or show usage on error
  late final ArgResults argResults;
  try {
    argResults = parser.parse(args);
  } catch (e) {
    print('Error: $e\n');
    _printUsage(parser);
    exit(1);
  }

  // Show help
  if (argResults['help'] as bool) {
    _printUsage(parser);
    exit(0);
  }

  // Set environment variables
  final port = int.parse(argResults['port'] as String);
  final host = argResults['host'] as String;
  final env = argResults['env'] as String;
  final logLevel = argResults['log-level'] as String;

  Platform.environment['PORT'] = port.toString();
  Platform.environment['HOST'] = host;
  Platform.environment['ENV'] = env;
  Platform.environment['LOG_LEVEL'] = logLevel.toUpperCase();

  // Create and start the auth server
  final server = AuthServer();

  // Handle termination signals
  ProcessSignal.sigint.watch().listen((_) async {
    print('Received SIGINT, shutting down...');
    await server.stop();
    exit(0);
  });

  ProcessSignal.sigterm.watch().listen((_) async {
    print('Received SIGTERM, shutting down...');
    await server.stop();
    exit(0);
  });

  try {
    // Initialize and start the server
    await server.init();
    await server.start();

    print('Auth Service is running at http://$host:$port');
    print('Press Ctrl+C to stop');
  } catch (e, stackTrace) {
    stderr.writeln('Error starting server: $e');
    stderr.writeln(stackTrace);
    exit(1);
  }
}

/// Print usage information
void _printUsage(ArgParser parser) {
  print('Authentication Service for CloudToLocalLLM');
  print('');
  print('Usage: dart bin/auth_service.dart [options]');
  print('');
  print('Options:');
  print(parser.usage);
}
