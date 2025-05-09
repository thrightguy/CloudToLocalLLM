import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import '../services/local_auth_service.dart';
import 'windows_service.dart';

class TunnelService {
  final LocalAuthService authService;
  final WindowsService? windowsService;

  Process? _ngrokProcess;
  bool _isRunning = false;
  final ValueNotifier<bool> isConnected = ValueNotifier<bool>(false);
  final ValueNotifier<String> tunnelUrl = ValueNotifier<String>('');
  Timer? _healthCheckTimer;
  Timer? _setupRetryTimer;
  int _setupAttempts = 0;
  final int _maxSetupAttempts = 3;

  TunnelService({
    required this.authService,
    this.windowsService,
  }) {
    // Listen to value changes to update system tray
    isConnected.addListener(_onTunnelStatusChanged);
    tunnelUrl.addListener(_onTunnelStatusChanged);

    // Listen to auth changes
    authService.isAuthenticated.addListener(_onAuthStatusChanged);
  }

  // Handle authentication status changes
  void _onAuthStatusChanged() {
    if (authService.isAuthenticated.value) {
      // User is authenticated, check if we should start tunnel
      if (_setupRetryTimer == null && !_isRunning) {
        debugPrint("User authenticated, auto-starting tunnel...");
        startTunnel();
      }
    } else {
      // User logged out, stop tunnel
      if (_isRunning) {
        debugPrint("User logged out, stopping tunnel...");
        stopTunnel();
      }
    }
  }

  // Handle tunnel status changes
  void _onTunnelStatusChanged() {
    // Update Windows service if available
    if (Platform.isWindows && windowsService != null) {
      windowsService!
          .updateNativeTunnelStatus(isConnected.value, tunnelUrl.value);

      // Update Windows service internal state
      windowsService!.isTunnelConnected.value = isConnected.value;
      windowsService!.tunnelUrl.value = tunnelUrl.value;
    }
  }

  // Check if the tunnel is running
  bool get isRunning => _isRunning;

  // Start the tunnel
  Future<bool> startTunnel() async {
    if (_isRunning) return true;

    // Reset setup attempts
    _setupAttempts = 0;
    return _startTunnelWithRetry();
  }

  // Start tunnel with retry logic
  Future<bool> _startTunnelWithRetry() async {
    if (_isRunning) return true;

    // Check setup attempts
    if (_setupAttempts >= _maxSetupAttempts) {
      debugPrint('Max setup attempts reached, giving up');
      return false;
    }

    _setupAttempts++;
    debugPrint('Tunnel setup attempt $_setupAttempts of $_maxSetupAttempts');

    try {
      // First make sure we're authenticated
      if (!authService.isAuthenticated.value) {
        debugPrint('Not authenticated, cannot start tunnel');
        return false;
      }

      // Get config paths from the application config
      final configFile = File(
          path.join(Directory.current.path, 'tools', 'ngrok', 'ngrok.yml'));
      if (!await configFile.exists()) {
        debugPrint('Config file not found at ${configFile.path}');

        // Try to create the config directory and file
        try {
          await configFile.parent.create(recursive: true);

          // Create a basic config
          final config = '''
version: 2
authtoken: ${await _getNgrokAuthToken()}
tunnels:
  ollama:
    proto: http
    addr: 11434
    bind_tls: true
''';
          await configFile.writeAsString(config);
          debugPrint('Created ngrok config file');
        } catch (e) {
          debugPrint('Error creating config file: $e');
          return false;
        }
      }

      // Get ngrok path
      final ngrokPath = await _getNgrokPath();
      if (ngrokPath == null) {
        debugPrint('Ngrok executable not found');
        return false;
      }

      // Start ngrok
      _ngrokProcess = await Process.start(
        ngrokPath,
        ['start', '--config', configFile.path, 'ollama'],
        runInShell: true,
      );

      // Listen to process output
      _ngrokProcess!.stdout.transform(utf8.decoder).listen((data) {
        debugPrint('ngrok stdout: $data');
        // Extract tunnel URL from output
        if (data.contains('https://')) {
          final url = RegExp(r'https://[^\s]+').firstMatch(data)?.group(0);
          if (url != null) {
            tunnelUrl.value = url;
            isConnected.value = true;
            _isRunning = true;

            // Register tunnel URL with cloud service
            _registerTunnelUrl(url);
          }
        }
      });

      _ngrokProcess!.stderr.transform(utf8.decoder).listen((data) {
        debugPrint('ngrok stderr: $data');

        // Check for common errors
        if (data.contains('authtoken') || data.contains('unauthorized')) {
          debugPrint('Ngrok auth token issue, attempting to refresh');
          _refreshNgrokAuth();
        }
      });

      // Start health check timer
      _healthCheckTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
        checkTunnelStatus();
      });

      // Wait for tunnel to start
      int attempts = 0;
      while (!isConnected.value && attempts < 30) {
        await Future.delayed(const Duration(seconds: 1));
        attempts++;
      }

      return isConnected.value;
    } catch (e) {
      debugPrint('Error starting tunnel: $e');

      // Schedule retry
      _scheduleRetry();
      return false;
    }
  }

  // Schedule retry for tunnel setup
  void _scheduleRetry() {
    _setupRetryTimer?.cancel();
    _setupRetryTimer = Timer(const Duration(seconds: 30), () {
      if (!_isRunning && _setupAttempts < _maxSetupAttempts) {
        debugPrint('Retrying tunnel setup...');
        _startTunnelWithRetry();
      }
    });
  }

  // Get ngrok auth token from cloud service
  Future<String> _getNgrokAuthToken() async {
    try {
      if (!authService.isAuthenticated.value) {
        throw Exception('Not authenticated');
      }

      final response = await http.get(
        Uri.parse('${authService.baseUrl}/api/tunnel/token'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${authService.getToken()}',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['auth_token'] ?? '';
      }

      throw Exception('Failed to get ngrok auth token: ${response.statusCode}');
    } catch (e) {
      debugPrint('Error getting ngrok auth token: $e');
      return '';
    }
  }

  // Refresh ngrok auth
  Future<void> _refreshNgrokAuth() async {
    await stopTunnel();

    // Wait a bit before trying again
    await Future.delayed(const Duration(seconds: 5));

    // Try to start again
    _startTunnelWithRetry();
  }

  // Get the path to the ngrok executable
  Future<String?> _getNgrokPath() async {
    if (Platform.isWindows) {
      final ngrokPath =
          path.join(Directory.current.path, 'tools', 'ngrok', 'ngrok.exe');
      if (await File(ngrokPath).exists()) {
        return ngrokPath;
      }
    } else if (Platform.isMacOS || Platform.isLinux) {
      final ngrokPath =
          path.join(Directory.current.path, 'tools', 'ngrok', 'ngrok');
      if (await File(ngrokPath).exists()) {
        return ngrokPath;
      }
    }

    // If not found in expected location, try to find in PATH
    try {
      if (Platform.isWindows) {
        final result = await Process.run('where', ['ngrok']);
        if (result.exitCode == 0 &&
            result.stdout.toString().trim().isNotEmpty) {
          return result.stdout.toString().trim().split('\n').first;
        }
      } else {
        final result = await Process.run('which', ['ngrok']);
        if (result.exitCode == 0 &&
            result.stdout.toString().trim().isNotEmpty) {
          return result.stdout.toString().trim();
        }
      }
    } catch (e) {
      debugPrint('Error finding ngrok in PATH: $e');
    }

    return null;
  }

  // Register tunnel URL with cloud service
  Future<void> _registerTunnelUrl(String url) async {
    try {
      if (!authService.isAuthenticated.value) {
        throw Exception('Not authenticated');
      }

      final response = await http.post(
        Uri.parse('${authService.baseUrl}/api/tunnel/register'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${authService.getToken()}',
        },
        body: jsonEncode({
          'url': url,
        }),
      );

      if (response.statusCode == 200) {
        debugPrint('Tunnel URL registered with cloud service');
      } else {
        debugPrint('Failed to register tunnel URL: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error registering tunnel URL: $e');
    }
  }

  // Stop the tunnel
  Future<void> stopTunnel() async {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = null;

    _setupRetryTimer?.cancel();
    _setupRetryTimer = null;

    if (_ngrokProcess != null) {
      _ngrokProcess!.kill();
      _ngrokProcess = null;
    }

    _isRunning = false;
    isConnected.value = false;
    tunnelUrl.value = '';
  }

  // Check tunnel status
  Future<bool> checkTunnelStatus() async {
    if (!_isRunning || _ngrokProcess == null) {
      isConnected.value = false;
      return false;
    }

    try {
      // Check if process is still running
      final result = await _ngrokProcess!.exitCode.timeout(
        const Duration(milliseconds: 100),
        onTimeout: () => -1, // Still running
      );

      if (result != -1) {
        // Process has exited
        await stopTunnel();
        return false;
      }

      // Check if we can reach Ollama through the tunnel
      if (tunnelUrl.value.isNotEmpty) {
        final response = await http
            .get(Uri.parse('${tunnelUrl.value}/api/tags'))
            .timeout(const Duration(seconds: 5));

        final isConnectedNow = response.statusCode == 200;
        if (isConnected.value != isConnectedNow) {
          isConnected.value = isConnectedNow;
        }
        return isConnectedNow;
      }

      return false;
    } catch (e) {
      debugPrint('Error checking tunnel status: $e');
      if (isConnected.value) {
        isConnected.value = false;
      }
      return false;
    }
  }

  // Clean up resources
  void dispose() {
    isConnected.removeListener(_onTunnelStatusChanged);
    tunnelUrl.removeListener(_onTunnelStatusChanged);
    authService.isAuthenticated.removeListener(_onAuthStatusChanged);
    stopTunnel();
  }
}
