import 'package:logging/logging.dart';

/// A centralized logging utility for the app
class AppLogger {
  static final Logger _logger = Logger('CloudToLocalLLM');
  static bool _initialized = false;

  /// Initialize the logger
  static void init() {
    if (_initialized) return;

    Logger.root.level = Level.ALL;
    Logger.root.onRecord.listen((record) {
      // In development: print to console
      // In production: could send to a monitoring service
      final message = '${record.level.name}: ${record.time}: ${record.message}';

      if (record.level >= Level.SEVERE) {
        // Error and critical logs
        print('\x1B[31m$message\x1B[0m'); // Red text
      } else if (record.level >= Level.WARNING) {
        // Warning logs
        print('\x1B[33m$message\x1B[0m'); // Yellow text
      } else if (record.level >= Level.INFO) {
        // Info logs
        print('\x1B[36m$message\x1B[0m'); // Cyan text
      } else {
        // Debug and trace logs
        print(message);
      }
    });

    _initialized = true;
  }

  /// Log a debug message
  static void debug(String message) {
    if (!_initialized) init();
    _logger.fine(message);
  }

  /// Log an info message
  static void info(String message) {
    if (!_initialized) init();
    _logger.info(message);
  }

  /// Log a warning message
  static void warning(String message) {
    if (!_initialized) init();
    _logger.warning(message);
  }

  /// Log an error message
  static void error(String message, [Object? error, StackTrace? stackTrace]) {
    if (!_initialized) init();
    _logger.severe(message, error, stackTrace);
  }
}
