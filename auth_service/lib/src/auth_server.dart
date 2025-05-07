import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:logging/logging.dart';
import 'package:shelf_cors_headers/shelf_cors_headers.dart';
import 'config/environment.dart';
import 'services/jwt_service.dart';
import 'services/user_service.dart';
import 'routes/auth_routes.dart';
import 'routes/user_routes.dart';
import 'package:postgres/postgres.dart';

/// Main authentication server class
class AuthServer {
  final Logger _logger = Logger('AuthServer');
  late final UserService _userService;
  final JwtService _jwtService = JwtService();
  late Router _router;
  HttpServer? _server;

  AuthServer() {
    _setupLogging();
    _setupRouter();
  }

  /// Initialize the server
  Future<void> init() async {
    // Initialize database connection
    final uri = Uri.parse(Environment.dbConnString);
    final db = await Connection.open(
      Endpoint(
        host: uri.host,
        database: uri.pathSegments.last,
        username: uri.userInfo.split(':')[0],
        password: uri.userInfo.split(':')[1],
        port: uri.port,
      ),
      settings: ConnectionSettings(sslMode: SslMode.disable),
    );

    _userService = UserService(db);
    await _userService.initialize();
    _logger.info('Auth server initialized');
  }

  /// Start the server
  Future<void> start() async {
    final ip = Environment.host;
    final port = Environment.port;

    // Create the server
    final handler = Pipeline()
        .addMiddleware(logRequests())
        .addMiddleware(corsHeaders(headers: {
          'Access-Control-Allow-Origin':
              Environment.corsAllowedOrigins.join(','),
          'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
          'Access-Control-Allow-Headers':
              'Origin, Content-Type, Accept, Authorization',
        }))
        .addHandler(_router.call);

    _server = await serve(handler, ip, port);
    _logger.info('Auth server started on http://$ip:$port');
  }

  /// Stop the server
  Future<void> stop() async {
    await _server?.close();
    await _userService.dispose();
    _logger.info('Auth server stopped');
  }

  /// Setup logging
  void _setupLogging() {
    hierarchicalLoggingEnabled = true;
    Logger.root.level = Level.INFO;

    Logger.root.onRecord.listen((record) {
      stderr.writeln('${record.time}: ${record.level.name}: ${record.message}');
      if (record.error != null) {
        stderr.writeln('Error: ${record.error}');
      }
      if (record.stackTrace != null) {
        stderr.writeln('Stack trace: ${record.stackTrace}');
      }
    });

    // Set log level based on environment
    switch (Environment.logLevel.toUpperCase()) {
      case 'FINE':
        Logger.root.level = Level.FINE;
        break;
      case 'INFO':
        Logger.root.level = Level.INFO;
        break;
      case 'WARNING':
        Logger.root.level = Level.WARNING;
        break;
      case 'SEVERE':
        Logger.root.level = Level.SEVERE;
        break;
      default:
        Logger.root.level = Level.INFO;
    }
  }

  /// Setup routing
  void _setupRouter() {
    _router = Router();

    // Add health check endpoint
    _router.get(
        '/health',
        (Request request) {
          return Response.ok('OK');
        }.call);

    // Add version endpoint
    _router.get(
        '/version',
        (Request request) {
          return Response.ok('{"version": "1.0.0"}',
              headers: {'content-type': 'application/json'});
        }.call);

    // Add auth routes
    _router.mount('/auth', createAuthRoutes(_userService, _jwtService).call);

    // Add user management routes
    _router.mount('/users', createUserRoutes(_userService, _jwtService).call);

    // Handle 404
    _router.all(
        '/<ignored|.*>',
        (Request request) {
          return Response.notFound('Not found');
        }.call);
  }
}
