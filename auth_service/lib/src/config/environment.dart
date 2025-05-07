import 'package:dotenv/dotenv.dart';

/// Environment configuration for the auth service
class Environment {
  static final DotEnv _env = DotEnv(includePlatformEnvironment: true)..load();

  /// Database connection string
  static String get dbConnString =>
      _env['DB_CONN_STRING'] ??
      'postgres://postgres:postgres@localhost:5432/auth_db';

  /// JWT secret key
  static String get jwtSecret =>
      _env['JWT_SECRET'] ??
      'change_this_in_production_this_is_not_safe_for_production';

  /// Server port
  static int get port => int.parse(_env['PORT'] ?? '8000');

  /// Server host
  static String get host => _env['HOST'] ?? '0.0.0.0';

  /// CORS allowed origins
  static List<String> get corsAllowedOrigins =>
      (_env['CORS_ALLOWED_ORIGINS'] ?? '*')
          .split(',')
          .map((e) => e.trim())
          .toList();

  /// Is development mode
  static bool get isDevelopment =>
      (_env['ENV'] ?? 'development') == 'development';

  /// Log level
  static String get logLevel => _env['LOG_LEVEL'] ?? 'INFO';
}
