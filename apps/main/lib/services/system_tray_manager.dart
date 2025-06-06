import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;

/// Cross-platform system tray manager using Python daemon
///
/// This replaces the problematic system_tray package with a reliable
/// Python-based separate process architecture that provides:
/// - Crash isolation from the main Flutter app
/// - Cross-platform compatibility (Linux, Windows, macOS)
/// - TCP socket IPC with JSON protocol
/// - Automatic daemon lifecycle management
/// - Health monitoring and restart capabilities
class SystemTrayManager {
  static final SystemTrayManager _instance = SystemTrayManager._internal();
  factory SystemTrayManager() => _instance;
  SystemTrayManager._internal();

  // State management
  bool _isInitialized = false;
  bool _isDaemonRunning = false;
  Process? _daemonProcess;
  Socket? _socket;
  int? _daemonPort;
  Timer? _healthCheckTimer;
  int _restartAttempts = 0;
  static const int _maxRestartAttempts = 3;

  // Callbacks
  Function()? _onShowWindow;
  Function()? _onHideWindow;
  Function()? _onQuit;
  Function()? _onSettings;
  Function()? _onOllamaTest;

  // Configuration
  static const Duration _healthCheckInterval = Duration(seconds: 30);
  static const Duration _connectionTimeout = Duration(seconds: 5);
  static const Duration _restartDelay = Duration(seconds: 2);

  /// Check if system tray is supported on this platform
  bool get isSupported => !kIsWeb && _isDesktopPlatform();

  /// Check if system tray is initialized and running
  bool get isInitialized => _isInitialized && _isDaemonRunning;

  /// Get current daemon status for UI display
  String get status {
    if (!isSupported) return "Not Supported";
    if (!_isInitialized) return "Not Initialized";
    if (!_isDaemonRunning) return "Daemon Stopped";
    if (_socket == null) return "Connecting";
    return "Running";
  }

  /// Connect to an existing tray daemon (new architecture)
  Future<bool> connectToExistingDaemon({
    Function()? onShowWindow,
    Function()? onHideWindow,
    Function()? onQuit,
    Function()? onSettings,
    Function()? onOllamaTest,
  }) async {
    if (_isInitialized) return true;

    try {
      debugPrint("Connecting to existing tray daemon...");

      _onShowWindow = onShowWindow;
      _onHideWindow = onHideWindow;
      _onQuit = onQuit;
      _onSettings = onSettings;
      _onOllamaTest = onOllamaTest;

      // Check if platform is supported
      if (!isSupported) {
        debugPrint("System tray not supported on this platform");
        return false;
      }

      // Try to read existing daemon port
      _daemonPort = await _readDaemonPort();
      if (_daemonPort == null) {
        debugPrint("No existing tray daemon found");
        return false;
      }

      // Connect to the existing daemon
      if (!await _connectToDaemon()) {
        debugPrint("Failed to connect to existing tray daemon");
        return false;
      }

      // Start health monitoring
      _startHealthMonitoring();

      _isInitialized = true;
      _isDaemonRunning = true; // We connected to existing daemon
      debugPrint("Connected to existing tray daemon successfully");
      return true;
    } catch (e) {
      debugPrint("Failed to connect to existing tray daemon: $e");
      return false;
    }
  }

  /// Initialize the system tray manager (legacy method - starts own daemon)
  Future<bool> initialize({
    Function()? onShowWindow,
    Function()? onHideWindow,
    Function()? onQuit,
    Function()? onSettings,
    Function()? onOllamaTest,
  }) async {
    if (_isInitialized) return true;

    try {
      debugPrint("Initializing SystemTrayManager...");

      _onShowWindow = onShowWindow;
      _onHideWindow = onHideWindow;
      _onQuit = onQuit;
      _onSettings = onSettings;
      _onOllamaTest = onOllamaTest;

      // Check if platform is supported
      if (!isSupported) {
        debugPrint("System tray not supported on this platform");
        return false;
      }

      // Start the Python daemon
      if (!await _startDaemon()) {
        debugPrint("Failed to start tray daemon");
        return false;
      }

      // Connect to the daemon
      if (!await _connectToDaemon()) {
        debugPrint("Failed to connect to tray daemon");
        await _stopDaemon();
        return false;
      }

      // Start health monitoring
      _startHealthMonitoring();

      _isInitialized = true;
      debugPrint("SystemTrayManager initialized successfully");
      return true;
    } catch (e) {
      debugPrint("Failed to initialize SystemTrayManager: $e");
      return false;
    }
  }

  /// Start the Python tray daemon process
  Future<bool> _startDaemon() async {
    try {
      final daemonPath = _getDaemonExecutablePath();
      if (daemonPath == null) {
        debugPrint("Tray daemon executable not found");
        return false;
      }

      debugPrint("Starting tray daemon: $daemonPath");

      // Start the daemon process
      _daemonProcess = await Process.start(
        daemonPath,
        ['--port', '0'], // Auto-assign port
        mode: ProcessStartMode.detached,
      );

      // Give the daemon time to start and write the port file
      await Future.delayed(const Duration(milliseconds: 1500));

      // Read the port from the port file
      _daemonPort = await _readDaemonPort();
      if (_daemonPort == null) {
        debugPrint("Failed to read daemon port");
        await _stopDaemon();
        return false;
      }

      _isDaemonRunning = true;
      debugPrint("Tray daemon started on port $_daemonPort");
      return true;
    } catch (e) {
      debugPrint("Failed to start tray daemon: $e");
      return false;
    }
  }

  /// Get the path to the tray daemon executable
  String? _getDaemonExecutablePath() {
    final platform = Platform.operatingSystem;
    final executableName = platform == 'windows'
        ? 'cloudtolocalllm-tray.exe'
        : 'cloudtolocalllm-tray';

    // Try different possible locations
    final possiblePaths = <String>[];

    if (platform == 'linux') {
      // For Linux packages
      possiblePaths.addAll([
        '/usr/bin/$executableName',
        '/usr/local/bin/$executableName',
        './bin/$executableName', // AppImage
        path.join(Directory.current.path, 'dist', 'tray_daemon', 'linux-x64',
            executableName),
      ]);
    } else if (platform == 'windows') {
      // For Windows
      possiblePaths.addAll([
        path.join(Platform.environment['PROGRAMFILES'] ?? '', 'CloudToLocalLLM',
            'bin', executableName),
        path.join('.', 'bin', executableName),
        path.join(Directory.current.path, 'dist', 'tray_daemon', 'windows-x64',
            executableName),
      ]);
    } else if (platform == 'macos') {
      // For macOS
      possiblePaths.addAll([
        '/Applications/CloudToLocalLLM.app/Contents/MacOS/$executableName',
        path.join('.', 'bin', executableName),
        path.join(Directory.current.path, 'dist', 'tray_daemon', 'macos-x64',
            executableName),
      ]);
    }

    // Find the first existing executable
    for (final execPath in possiblePaths) {
      final file = File(execPath);
      if (file.existsSync()) {
        debugPrint("Found tray daemon at: $execPath");
        return execPath;
      }
    }

    debugPrint("Tray daemon executable not found. Searched paths:");
    for (final execPath in possiblePaths) {
      debugPrint("  - $execPath");
    }
    return null;
  }

  /// Read the daemon port from the port file
  Future<int?> _readDaemonPort() async {
    try {
      final portFile = File(_getPortFilePath());

      // Wait for port file to be created (up to 5 seconds)
      for (int i = 0; i < 50; i++) {
        if (portFile.existsSync()) {
          final portStr = await portFile.readAsString();
          final port = int.tryParse(portStr.trim());
          if (port != null && port > 0) {
            return port;
          }
        }
        await Future.delayed(const Duration(milliseconds: 100));
      }

      debugPrint("Port file not found or invalid after waiting");
      return null;
    } catch (e) {
      debugPrint("Failed to read daemon port: $e");
      return null;
    }
  }

  /// Get the path to the port file
  String _getPortFilePath() {
    final home = Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '';
    final platform = Platform.operatingSystem;

    String configDir;
    if (platform == 'windows') {
      configDir = path.join(
          Platform.environment['LOCALAPPDATA'] ?? home, 'CloudToLocalLLM');
    } else if (platform == 'macos') {
      configDir =
          path.join(home, 'Library', 'Application Support', 'CloudToLocalLLM');
    } else {
      configDir = path.join(home, '.cloudtolocalllm');
    }

    return path.join(configDir, 'tray_port');
  }

  /// Connect to the tray daemon via TCP socket
  Future<bool> _connectToDaemon() async {
    if (_daemonPort == null) return false;

    try {
      debugPrint("Connecting to daemon on port $_daemonPort");

      _socket = await Socket.connect('127.0.0.1', _daemonPort!)
          .timeout(_connectionTimeout);

      // Listen for messages from daemon
      _socket!.listen(
        _handleDaemonMessage,
        onError: (error) {
          debugPrint("Socket error: $error");
          _handleConnectionLost();
        },
        onDone: () {
          debugPrint("Socket connection closed");
          _handleConnectionLost();
        },
      );

      debugPrint("Connected to tray daemon");
      return true;
    } catch (e) {
      debugPrint("Failed to connect to daemon: $e");
      return false;
    }
  }

  /// Handle messages received from the daemon
  void _handleDaemonMessage(List<int> data) {
    try {
      final message = utf8.decode(data).trim();
      if (message.isEmpty) return;

      final json = jsonDecode(message);
      final command = json['command'] as String?;

      debugPrint("Received from daemon: $command");

      switch (command) {
        case 'SHOW':
          debugPrint("Tray daemon requested: Show window");
          _onShowWindow?.call();
          break;
        case 'HIDE':
          debugPrint("Tray daemon requested: Hide window");
          _onHideWindow?.call();
          break;
        case 'SETTINGS':
          debugPrint("Tray daemon requested: Open settings");
          _onSettings?.call();
          break;
        case 'OLLAMA_TEST':
          debugPrint("Tray daemon requested: Open Ollama test");
          _onOllamaTest?.call();
          break;
        case 'QUIT':
          debugPrint("Tray daemon requested: Quit application");
          _onQuit?.call();
          break;
        default:
          debugPrint("Unknown command from daemon: $command");
      }
    } catch (e) {
      debugPrint("Failed to handle daemon message: $e");
    }
  }

  /// Send a command to the daemon
  Future<bool> _sendCommand(Map<String, dynamic> command) async {
    if (_socket == null) return false;

    try {
      final message = '${jsonEncode(command)}\n';
      _socket!.add(utf8.encode(message));
      return true;
    } catch (e) {
      debugPrint("Failed to send command to daemon: $e");
      return false;
    }
  }

  /// Update the tray tooltip
  Future<void> setTooltip(String tooltip) async {
    await _sendCommand({
      'command': 'UPDATE_TOOLTIP',
      'text': tooltip,
    });
  }

  /// Update the tray icon state
  Future<void> updateIconState(String state) async {
    await _sendCommand({
      'command': 'UPDATE_ICON',
      'state': state, // idle, connected, error
    });
  }

  /// Update the authentication status
  Future<void> updateAuthenticationStatus(bool isAuthenticated) async {
    debugPrint("Sending auth status to tray daemon: $isAuthenticated");
    await _sendCommand({
      'command': 'UPDATE_AUTH_STATUS',
      'authenticated': isAuthenticated,
    });
  }

  /// Start health monitoring of the daemon
  void _startHealthMonitoring() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = Timer.periodic(_healthCheckInterval, (_) {
      _performHealthCheck();
    });
  }

  /// Perform a health check on the daemon
  Future<void> _performHealthCheck() async {
    if (!_isDaemonRunning || _socket == null) {
      _handleConnectionLost();
      return;
    }

    try {
      // Send ping command
      final success = await _sendCommand({'command': 'PING'});
      if (!success) {
        debugPrint("Health check failed: unable to send ping");
        _handleConnectionLost();
      }
      // Note: We don't wait for PONG response in this simple implementation
      // The socket error handler will catch connection issues
    } catch (e) {
      debugPrint("Health check error: $e");
      _handleConnectionLost();
    }
  }

  /// Handle connection lost to daemon
  void _handleConnectionLost() {
    debugPrint("Connection to tray daemon lost");
    _socket?.close();
    _socket = null;
    _isDaemonRunning = false;

    // Attempt restart if we haven't exceeded max attempts
    if (_restartAttempts < _maxRestartAttempts) {
      _restartAttempts++;
      debugPrint(
          "Attempting to restart daemon (attempt $_restartAttempts/$_maxRestartAttempts)");

      Timer(_restartDelay, () async {
        if (await _restartDaemon()) {
          _restartAttempts = 0; // Reset on successful restart
        }
      });
    } else {
      debugPrint("Max restart attempts reached, giving up on tray daemon");
    }
  }

  /// Restart the daemon
  Future<bool> _restartDaemon() async {
    debugPrint("Restarting tray daemon...");

    // Stop current daemon
    await _stopDaemon();

    // Wait a bit before restarting
    await Future.delayed(const Duration(milliseconds: 500));

    // Start new daemon
    if (await _startDaemon()) {
      return await _connectToDaemon();
    }

    return false;
  }

  /// Stop the tray daemon
  Future<void> _stopDaemon() async {
    try {
      // Send quit command if connected
      if (_socket != null) {
        await _sendCommand({'command': 'QUIT'});
        await Future.delayed(const Duration(milliseconds: 500));
      }

      // Close socket
      _socket?.close();
      _socket = null;

      // Kill process if still running
      if (_daemonProcess != null) {
        _daemonProcess!.kill();
        _daemonProcess = null;
      }

      _isDaemonRunning = false;
      _daemonPort = null;

      debugPrint("Tray daemon stopped");
    } catch (e) {
      debugPrint("Error stopping daemon: $e");
    }
  }

  /// Shutdown the system tray manager
  Future<void> shutdown() async {
    debugPrint("Shutting down SystemTrayManager...");

    _healthCheckTimer?.cancel();
    _healthCheckTimer = null;

    await _stopDaemon();

    _isInitialized = false;
    _restartAttempts = 0;

    debugPrint("SystemTrayManager shutdown complete");
  }

  /// Check if running on desktop platform
  bool _isDesktopPlatform() {
    try {
      return Platform.isWindows || Platform.isMacOS || Platform.isLinux;
    } catch (e) {
      return false;
    }
  }

  /// Show a notification (if supported by daemon)
  Future<void> showNotification({
    required String title,
    required String message,
  }) async {
    await _sendCommand({
      'command': 'NOTIFICATION',
      'title': title,
      'message': message,
    });
  }

  /// Get daemon log path for debugging
  String getDaemonLogPath() {
    final home = Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '';
    final platform = Platform.operatingSystem;

    String configDir;
    if (platform == 'windows') {
      configDir = path.join(
          Platform.environment['LOCALAPPDATA'] ?? home, 'CloudToLocalLLM');
    } else if (platform == 'macos') {
      configDir =
          path.join(home, 'Library', 'Application Support', 'CloudToLocalLLM');
    } else {
      configDir = path.join(home, '.cloudtolocalllm');
    }

    return path.join(configDir, 'tray.log');
  }
}
