import 'package:flutter/foundation.dart';
import 'dart:convert';

// Conditional import for web package - only import on web platform
import 'package:web/web.dart' as web if (dart.library.io) 'dart:io';

/// Persistent authentication logger for debugging
/// Stores logs in browser localStorage and provides download functionality
class AuthLogger {
  static const String _storageKey = 'cloudtolocalllm_auth_logs';
  static const int _maxLogEntries = 1000;

  static final AuthLogger _instance = AuthLogger._internal();
  factory AuthLogger() => _instance;
  AuthLogger._internal();

  /// Log an authentication event with timestamp
  static void log(String message,
      {String level = 'INFO', Map<String, dynamic>? data}) {
    if (!kIsWeb) return; // Only works on web

    try {
      final timestamp = DateTime.now().toIso8601String();
      final logEntry = {
        'timestamp': timestamp,
        'level': level,
        'message': message,
        'data': data,
      };

      // Get existing logs
      final existingLogs = _getStoredLogs();
      existingLogs.add(logEntry);

      // Keep only the last N entries to prevent storage overflow
      if (existingLogs.length > _maxLogEntries) {
        existingLogs.removeRange(0, existingLogs.length - _maxLogEntries);
      }

      // Store back to localStorage
      _storeLogs(existingLogs);

      // Also log to console for immediate viewing
      debugPrint(
          '[$level] $timestamp: $message${data != null ? ' | Data: $data' : ''}');
    } catch (e) {
      debugPrint('AuthLogger error: $e');
    }
  }

  /// Log info message
  static void info(String message, [Map<String, dynamic>? data]) {
    log(message, level: 'INFO', data: data);
  }

  /// Log warning message
  static void warning(String message, [Map<String, dynamic>? data]) {
    log(message, level: 'WARN', data: data);
  }

  /// Log error message
  static void error(String message, [Map<String, dynamic>? data]) {
    log(message, level: 'ERROR', data: data);
  }

  /// Log debug message
  static void debug(String message, [Map<String, dynamic>? data]) {
    log(message, level: 'DEBUG', data: data);
  }

  /// Get all stored logs
  static List<Map<String, dynamic>> getLogs() {
    if (!kIsWeb) return [];
    return _getStoredLogs();
  }

  /// Get logs as formatted string
  static String getLogsAsString() {
    final logs = getLogs();
    final buffer = StringBuffer();

    buffer.writeln('CloudToLocalLLM Authentication Debug Log');
    buffer.writeln('Generated: ${DateTime.now().toIso8601String()}');
    buffer.writeln('Total Entries: ${logs.length}');
    buffer.writeln('=' * 60);
    buffer.writeln();

    for (final log in logs) {
      buffer.writeln('[${log['level']}] ${log['timestamp']}');
      buffer.writeln('Message: ${log['message']}');
      if (log['data'] != null) {
        buffer.writeln('Data: ${log['data']}');
      }
      buffer.writeln('-' * 40);
    }

    return buffer.toString();
  }

  /// Download logs as a text file
  static void downloadLogs() {
    if (!kIsWeb) return;

    try {
      final logContent = getLogsAsString();
      // Print to console for now (download feature disabled due to web API complexity)
      debugPrint('=== AUTH DEBUG LOG ===');
      debugPrint(logContent);
      debugPrint('=== END AUTH DEBUG LOG ===');

      info('Debug log printed to console');
    } catch (e) {
      error('Failed to print logs', {'error': e.toString()});
    }
  }

  /// Clear all stored logs
  static void clearLogs() {
    if (!kIsWeb) return;

    try {
      if (kIsWeb) {
        web.window.localStorage.removeItem(_storageKey);
      }
      info('Authentication logs cleared');
    } catch (e) {
      error('Failed to clear logs', {'error': e.toString()});
    }
  }

  /// Get logs from localStorage
  static List<Map<String, dynamic>> _getStoredLogs() {
    try {
      if (!kIsWeb) return [];

      final stored = web.window.localStorage.getItem(_storageKey);
      if (stored == null) return [];

      // Parse JSON array using dart:convert
      final List<dynamic> parsed = jsonDecode(stored) as List<dynamic>;
      return parsed.cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('Error reading stored logs: $e');
      return [];
    }
  }

  /// Store logs to localStorage
  static void _storeLogs(List<Map<String, dynamic>> logs) {
    try {
      if (!kIsWeb) return;

      final jsonString = jsonEncode(logs);
      web.window.localStorage.setItem(_storageKey, jsonString);
    } catch (e) {
      debugPrint('Error storing logs: $e');
    }
  }

  /// Get summary of recent authentication attempts
  static Map<String, dynamic> getAuthSummary() {
    final logs = getLogs();
    final authLogs = logs
        .where((log) =>
            log['message'].toString().contains('login') ||
            log['message'].toString().contains('auth') ||
            log['message'].toString().contains('redirect'))
        .toList();

    return {
      'totalLogs': logs.length,
      'authRelatedLogs': authLogs.length,
      'lastAuthAttempt':
          authLogs.isNotEmpty ? authLogs.last['timestamp'] : null,
      'errorCount': logs.where((log) => log['level'] == 'ERROR').length,
      'warningCount': logs.where((log) => log['level'] == 'WARN').length,
    };
  }

  /// Initialize logger and log startup
  static void initialize() {
    info('AuthLogger initialized', {
      'platform': kIsWeb ? 'web' : 'desktop',
      'userAgent': kIsWeb ? web.window.navigator.userAgent : 'desktop-app',
      'url': kIsWeb ? web.window.location.href : 'desktop-app',
    });
  }

  /// Log page navigation
  static void logNavigation(String from, String to) {
    info('Navigation', {
      'from': from,
      'to': to,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Log authentication state change
  static void logAuthStateChange(bool isAuthenticated, String reason) {
    info('Authentication state changed', {
      'isAuthenticated': isAuthenticated,
      'reason': reason,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }
}
