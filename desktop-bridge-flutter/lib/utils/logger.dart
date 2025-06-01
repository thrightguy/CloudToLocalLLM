import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

import '../config/app_config.dart';

class AppLogger {
  static Logger? _logger;
  static File? _logFile;

  static Logger get instance {
    _logger ??= _createLogger();
    return _logger!;
  }

  static Future<void> init() async {
    if (AppConfig.enableVerboseLogging) {
      await _initLogFile();
    }
    _logger = _createLogger();
    info('Logger initialized');
  }

  static Logger _createLogger() {
    return Logger(
      filter: _LogFilter(),
      printer: _LogPrinter(),
      output: _LogOutput(),
      level: AppConfig.enableDebugMode ? Level.debug : Level.info,
    );
  }

  static Future<void> _initLogFile() async {
    try {
      final appDir = await getApplicationSupportDirectory();
      final logDir = Directory(path.join(appDir.path, 'logs'));
      
      if (!await logDir.exists()) {
        await logDir.create(recursive: true);
      }
      
      _logFile = File(path.join(logDir.path, AppConfig.logFileName));
      
      // Rotate log file if it's too large
      if (await _logFile!.exists()) {
        final stat = await _logFile!.stat();
        if (stat.size > AppConfig.maxLogFileSize) {
          await _rotateLogFile();
        }
      }
    } catch (e) {
      debugPrint('Failed to initialize log file: $e');
    }
  }

  static Future<void> _rotateLogFile() async {
    if (_logFile == null) return;

    try {
      final logDir = _logFile!.parent;
      final baseName = path.basenameWithoutExtension(_logFile!.path);
      final extension = path.extension(_logFile!.path);

      // Rotate existing log files
      for (int i = AppConfig.maxLogFiles - 1; i > 0; i--) {
        final oldFile = File(path.join(logDir.path, '$baseName.$i$extension'));
        final newFile = File(path.join(logDir.path, '$baseName.${i + 1}$extension'));
        
        if (await oldFile.exists()) {
          if (i == AppConfig.maxLogFiles - 1) {
            await oldFile.delete();
          } else {
            await oldFile.rename(newFile.path);
          }
        }
      }

      // Move current log to .1
      final backupFile = File(path.join(logDir.path, '$baseName.1$extension'));
      await _logFile!.rename(backupFile.path);
      
      // Create new log file
      _logFile = File(path.join(logDir.path, AppConfig.logFileName));
    } catch (e) {
      debugPrint('Failed to rotate log file: $e');
    }
  }

  // Convenience methods
  static void debug(String message, [Object? error, StackTrace? stackTrace]) {
    instance.d(message, error: error, stackTrace: stackTrace);
  }

  static void info(String message, [Object? error, StackTrace? stackTrace]) {
    instance.i(message, error: error, stackTrace: stackTrace);
  }

  static void warning(String message, [Object? error, StackTrace? stackTrace]) {
    instance.w(message, error: error, stackTrace: stackTrace);
  }

  static void error(String message, [Object? error, StackTrace? stackTrace]) {
    instance.e(message, error: error, stackTrace: stackTrace);
  }

  static void fatal(String message, [Object? error, StackTrace? stackTrace]) {
    instance.f(message, error: error, stackTrace: stackTrace);
  }
}

class _LogFilter extends LogFilter {
  @override
  bool shouldLog(LogEvent event) {
    if (kDebugMode) return true;
    return event.level.index >= Level.info.index;
  }
}

class _LogPrinter extends LogPrinter {
  static final _levelEmojis = {
    Level.trace: '🔍',
    Level.debug: '🐛',
    Level.info: 'ℹ️',
    Level.warning: '⚠️',
    Level.error: '❌',
    Level.fatal: '💀',
  };

  @override
  List<String> log(LogEvent event) {
    final emoji = _levelEmojis[event.level] ?? '';
    final timestamp = DateTime.now().toIso8601String();
    final level = event.level.name.toUpperCase().padRight(7);
    
    final lines = <String>[];
    
    // Main message
    lines.add('$timestamp [$level] $emoji ${event.message}');
    
    // Error details
    if (event.error != null) {
      lines.add('Error: ${event.error}');
    }
    
    // Stack trace
    if (event.stackTrace != null) {
      lines.addAll(event.stackTrace.toString().split('\n'));
    }
    
    return lines;
  }
}

class _LogOutput extends LogOutput {
  @override
  void output(OutputEvent event) {
    // Always output to console in debug mode
    if (kDebugMode) {
      for (final line in event.lines) {
        debugPrint(line);
      }
    }
    
    // Write to file if available
    if (AppLogger._logFile != null) {
      _writeToFile(event.lines);
    }
  }

  void _writeToFile(List<String> lines) {
    try {
      final content = lines.join('\n') + '\n';
      AppLogger._logFile!.writeAsStringSync(
        content,
        mode: FileMode.append,
        flush: true,
      );
    } catch (e) {
      debugPrint('Failed to write to log file: $e');
    }
  }
}
