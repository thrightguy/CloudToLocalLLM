import 'package:flutter/foundation.dart';

/// A centralized logging utility for the app
class AppLogger {
  static bool _initialized = false;
  static LogLevel _logLevel = LogLevel.info;

  /// The tag for this logger instance
  final String _tag;

  /// Create a new logger with the given tag
  AppLogger(this._tag);

  /// Initialize the logger
  static void init({LogLevel logLevel = LogLevel.info}) {
    _logLevel = logLevel;
    _initialized = true;
  }

  /// Log a debug message
  void debug(String message) {
    _log(LogLevel.debug, message);
  }

  /// Log an info message
  void info(String message) {
    _log(LogLevel.info, message);
  }

  /// Log a warning message
  void warning(String message) {
    _log(LogLevel.warning, message);
  }

  /// Log an error message
  void error(String message, [Object? error, StackTrace? stackTrace]) {
    final errorMsg = error != null ? '$message: $error' : message;
    _log(LogLevel.error, errorMsg);
    if (stackTrace != null) {
      _log(LogLevel.error, 'Stack trace: $stackTrace');
    }
  }

  /// Internal log method
  void _log(LogLevel level, String message) {
    if (!_shouldLog(level)) return;

    final timestamp = DateTime.now().toString();
    final levelString = level.toString().split('.').last.toUpperCase();
    debugPrint('$timestamp [$levelString] [$_tag] $message');
  }

  /// Check if we should log at the given level
  bool _shouldLog(LogLevel level) {
    return level.index >= _logLevel.index;
  }
}

/// Log levels
enum LogLevel {
  debug,
  info,
  warning,
  error,
}
