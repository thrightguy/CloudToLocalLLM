import 'dart:io';
import 'package:flutter/foundation.dart';

/// Centralized logging utility for CloudToLocalLLM applications
class AppLogger {
  static const String _logDir = '/tmp';
  static const String _logFilePrefix = 'cloudtolocalllm';
  
  final String _appName;
  late final String _logFilePath;
  
  AppLogger(this._appName) {
    _logFilePath = '$_logDir/${_logFilePrefix}_$_appName.log';
  }

  /// Log an info message
  void info(String message) {
    _log('INFO', message);
  }

  /// Log a warning message
  void warning(String message) {
    _log('WARN', message);
  }

  /// Log an error message
  void error(String message, [Object? error, StackTrace? stackTrace]) {
    _log('ERROR', message);
    if (error != null) {
      _log('ERROR', 'Exception: $error');
    }
    if (stackTrace != null) {
      _log('ERROR', 'Stack trace: $stackTrace');
    }
  }

  /// Log a debug message (only in debug mode)
  void debug(String message) {
    if (kDebugMode) {
      _log('DEBUG', message);
    }
  }

  /// Internal logging method
  void _log(String level, String message) {
    final timestamp = DateTime.now().toIso8601String();
    final logEntry = '[$timestamp] [$level] [$_appName] $message';
    
    // Print to console
    debugPrint(logEntry);
    
    // Write to file (non-web platforms only)
    if (!kIsWeb) {
      try {
        final file = File(_logFilePath);
        file.writeAsStringSync('$logEntry\n', mode: FileMode.append);
      } catch (e) {
        debugPrint('Failed to write to log file: $e');
      }
    }
  }

  /// Clear the log file
  void clearLog() {
    if (!kIsWeb) {
      try {
        final file = File(_logFilePath);
        if (file.existsSync()) {
          file.deleteSync();
        }
      } catch (e) {
        debugPrint('Failed to clear log file: $e');
      }
    }
  }

  /// Get the log file path
  String get logFilePath => _logFilePath;
}
