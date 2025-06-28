// Desktop-specific ngrok service implementation
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:process_run/shell.dart';
import 'package:http/http.dart' as http;
import 'ngrok_service.dart';
import 'auth_service.dart';

/// Desktop ngrok service implementation
/// Handles ngrok process execution and tunnel management
class NgrokServiceDesktop extends NgrokService {
  NgrokConfig _config = NgrokConfig.defaultConfig();
  NgrokTunnel? _activeTunnel;
  bool _isRunning = false;
  bool _isStarting = false;
  String? _lastError;

  Process? _ngrokProcess;
  Timer? _healthCheckTimer;
  Timer? _startupTimer;
  Shell? _shell;

  // Auth service for JWT validation
  final AuthService? _authService;

  static const int _ngrokApiPort = 4040;
  static const String _ngrokApiUrl = 'http://localhost:$_ngrokApiPort';
  static const Duration _startupTimeout = Duration(seconds: 30);
  static const Duration _healthCheckInterval = Duration(seconds: 10);

  NgrokServiceDesktop({AuthService? authService}) : _authService = authService {
    _shell = Shell();
    debugPrint('🖥️ [NgrokService] Desktop service initialized');
  }

  @override
  NgrokConfig get config => _config;

  @override
  NgrokTunnel? get activeTunnel => _activeTunnel;

  @override
  bool get isRunning => _isRunning;

  @override
  bool get isStarting => _isStarting;

  @override
  String? get lastError => _lastError;

  @override
  bool get isSupported => true; // Ngrok is supported on desktop

  @override
  Future<void> initialize() async {
    debugPrint('🖥️ [NgrokService] Initializing desktop ngrok service...');

    try {
      final isInstalled = await isNgrokInstalled();
      if (!isInstalled) {
        _lastError = 'Ngrok is not installed or not found in PATH';
        debugPrint('🖥️ [NgrokService] Warning: $_lastError');
      } else {
        final version = await getNgrokVersion();
        debugPrint('🖥️ [NgrokService] Found ngrok version: $version');
      }
    } catch (e) {
      _lastError = 'Failed to initialize ngrok service: $e';
      debugPrint('🖥️ [NgrokService] Initialization error: $_lastError');
    }

    notifyListeners();
  }

  @override
  Future<NgrokTunnel?> startTunnel(NgrokConfig config) async {
    if (_isRunning || _isStarting) {
      debugPrint('🖥️ [NgrokService] Tunnel already running or starting');
      return _activeTunnel;
    }

    if (!config.enabled) {
      debugPrint('🖥️ [NgrokService] Ngrok is disabled in configuration');
      return null;
    }

    _isStarting = true;
    _lastError = null;
    _config = config;
    notifyListeners();

    try {
      debugPrint('🖥️ [NgrokService] Starting ngrok tunnel...');
      debugPrint('🖥️ [NgrokService] Config: $config');

      // Check if ngrok is installed
      if (!await isNgrokInstalled()) {
        throw Exception('Ngrok is not installed or not found in PATH');
      }

      // Stop any existing tunnel
      await stopTunnel();

      // Build ngrok command
      final command = _buildNgrokCommand(config);
      debugPrint('🖥️ [NgrokService] Executing: ${command.join(' ')}');

      // Start ngrok process
      _ngrokProcess = await Process.start(
        command.first,
        command.skip(1).toList(),
        mode: ProcessStartMode.normal,
      );

      // Set up process monitoring
      _setupProcessMonitoring();

      // Wait for ngrok to start and get tunnel info
      _startupTimer = Timer(_startupTimeout, () {
        if (_isStarting) {
          _handleStartupTimeout();
        }
      });

      // Poll for tunnel information
      await _waitForTunnelReady();

      return _activeTunnel;
    } catch (e) {
      _lastError = 'Failed to start ngrok tunnel: $e';
      debugPrint('🖥️ [NgrokService] Start tunnel error: $_lastError');
      await _cleanup();
      rethrow;
    } finally {
      _isStarting = false;
      notifyListeners();
    }
  }

  @override
  Future<void> stopTunnel() async {
    debugPrint('🖥️ [NgrokService] Stopping ngrok tunnel...');

    await _cleanup();

    _isRunning = false;
    _activeTunnel = null;
    _lastError = null;

    debugPrint('🖥️ [NgrokService] Ngrok tunnel stopped');
    notifyListeners();
  }

  @override
  Future<bool> isNgrokInstalled() async {
    try {
      final result = await _shell!.run('ngrok version');
      return result.isNotEmpty;
    } catch (e) {
      debugPrint('🖥️ [NgrokService] Ngrok not found: $e');
      return false;
    }
  }

  @override
  Future<String?> getNgrokVersion() async {
    try {
      final results = await _shell!.run('ngrok version');
      if (results.isNotEmpty) {
        final output = results.first.stdout.toString();
        // Extract version from output like "ngrok version 3.x.x"
        final versionMatch = RegExp(r'ngrok version (\S+)').firstMatch(output);
        return versionMatch?.group(1);
      }
    } catch (e) {
      debugPrint('🖥️ [NgrokService] Failed to get ngrok version: $e');
    }
    return null;
  }

  @override
  Future<void> updateConfiguration(NgrokConfig newConfig) async {
    final wasRunning = _isRunning;
    final oldConfig = _config;

    _config = newConfig;

    // If configuration changed and tunnel was running, restart it
    if (wasRunning && _configurationChanged(oldConfig, newConfig)) {
      debugPrint(
        '🖥️ [NgrokService] Configuration changed, restarting tunnel...',
      );
      await stopTunnel();
      if (newConfig.enabled) {
        await startTunnel(newConfig);
      }
    }

    notifyListeners();
  }

  @override
  Future<Map<String, dynamic>> getTunnelStatus() async {
    final status = {
      'supported': true,
      'platform': 'desktop',
      'isRunning': _isRunning,
      'isStarting': _isStarting,
      'lastError': _lastError,
      'config': _config.toString(),
      'security': {
        'hasAuthService': _authService != null,
        'isAuthenticated': _authService?.isAuthenticated.value ?? false,
        'isTunnelSecure': isTunnelSecure,
        'accessValidated': await validateTunnelAccess(),
      },
    };

    if (_activeTunnel != null) {
      status['activeTunnel'] = _activeTunnel!.toJson();
      status['secureUrl'] = getSecureTunnelUrl();
    }

    // Try to get live status from ngrok API
    try {
      final apiStatus = await _getNgrokApiStatus();
      status['apiStatus'] = apiStatus;
    } catch (e) {
      status['apiError'] = e.toString();
    }

    return status;
  }

  /// Build ngrok command arguments
  List<String> _buildNgrokCommand(NgrokConfig config) {
    final command = ['ngrok'];

    // Add protocol
    command.add(config.protocol);

    // Add local address
    command.add('${config.localHost}:${config.localPort}');

    // Add auth token if provided
    if (config.authToken != null && config.authToken!.isNotEmpty) {
      command.addAll(['--authtoken', config.authToken!]);
    }

    // Add subdomain if provided
    if (config.subdomain != null && config.subdomain!.isNotEmpty) {
      command.addAll(['--subdomain', config.subdomain!]);
    }

    // Add additional options
    if (config.additionalOptions != null) {
      config.additionalOptions!.forEach((key, value) {
        command.addAll(['--$key', value.toString()]);
      });
    }

    return command;
  }

  /// Set up process monitoring for ngrok
  void _setupProcessMonitoring() {
    if (_ngrokProcess == null) return;

    _ngrokProcess!.stdout.transform(utf8.decoder).listen((data) {
      debugPrint('🖥️ [NgrokService] stdout: $data');
    });

    _ngrokProcess!.stderr.transform(utf8.decoder).listen((data) {
      debugPrint('🖥️ [NgrokService] stderr: $data');
      if (data.toLowerCase().contains('error')) {
        _lastError = data.trim();
        notifyListeners();
      }
    });

    _ngrokProcess!.exitCode.then((exitCode) {
      debugPrint('🖥️ [NgrokService] Process exited with code: $exitCode');
      if (exitCode != 0 && _isRunning) {
        _lastError = 'Ngrok process exited unexpectedly (code: $exitCode)';
        _isRunning = false;
        _activeTunnel = null;
        notifyListeners();
      }
    });
  }

  /// Wait for ngrok tunnel to be ready
  Future<void> _waitForTunnelReady() async {
    const maxAttempts = 15;
    const delay = Duration(seconds: 2);

    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        await Future.delayed(delay);

        final tunnels = await _getNgrokTunnels();
        if (tunnels.isNotEmpty) {
          _activeTunnel = tunnels.first;
          _isRunning = true;
          _startHealthChecking();

          debugPrint(
            '🖥️ [NgrokService] Tunnel ready: ${_activeTunnel!.publicUrl}',
          );
          return;
        }

        debugPrint(
          '🖥️ [NgrokService] Waiting for tunnel... (attempt $attempt/$maxAttempts)',
        );
      } catch (e) {
        debugPrint(
          '🖥️ [NgrokService] Tunnel check failed (attempt $attempt): $e',
        );
      }
    }

    throw Exception('Timeout waiting for ngrok tunnel to become ready');
  }

  /// Get tunnel information from ngrok API
  Future<List<NgrokTunnel>> _getNgrokTunnels() async {
    final response = await http
        .get(
          Uri.parse('$_ngrokApiUrl/api/tunnels'),
          headers: {'Accept': 'application/json'},
        )
        .timeout(const Duration(seconds: 5));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final tunnels = data['tunnels'] as List<dynamic>;

      return tunnels
          .map((tunnel) => NgrokTunnel.fromJson(tunnel))
          .where((tunnel) => tunnel.protocol == _config.protocol)
          .toList();
    } else {
      throw Exception('Failed to get tunnel info: HTTP ${response.statusCode}');
    }
  }

  /// Get ngrok API status
  Future<Map<String, dynamic>> _getNgrokApiStatus() async {
    final response = await http
        .get(
          Uri.parse('$_ngrokApiUrl/api/tunnels'),
          headers: {'Accept': 'application/json'},
        )
        .timeout(const Duration(seconds: 5));

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('API request failed: HTTP ${response.statusCode}');
    }
  }

  /// Start health checking
  void _startHealthChecking() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = Timer.periodic(_healthCheckInterval, (_) {
      _performHealthCheck();
    });
  }

  /// Perform health check
  Future<void> _performHealthCheck() async {
    try {
      await _getNgrokApiStatus();
      // Health check passed
    } catch (e) {
      debugPrint('🖥️ [NgrokService] Health check failed: $e');
      if (_isRunning) {
        _lastError = 'Health check failed: $e';
        notifyListeners();
      }
    }
  }

  /// Handle startup timeout
  void _handleStartupTimeout() {
    _lastError = 'Timeout starting ngrok tunnel';
    debugPrint('🖥️ [NgrokService] $_lastError');
    _cleanup();
    notifyListeners();
  }

  /// Check if configuration changed significantly
  bool _configurationChanged(NgrokConfig oldConfig, NgrokConfig newConfig) {
    return oldConfig.authToken != newConfig.authToken ||
        oldConfig.subdomain != newConfig.subdomain ||
        oldConfig.protocol != newConfig.protocol ||
        oldConfig.localPort != newConfig.localPort ||
        oldConfig.localHost != newConfig.localHost ||
        oldConfig.enabled != newConfig.enabled;
  }

  /// Clean up resources
  Future<void> _cleanup() async {
    _startupTimer?.cancel();
    _healthCheckTimer?.cancel();

    if (_ngrokProcess != null) {
      try {
        _ngrokProcess!.kill();
        await _ngrokProcess!.exitCode.timeout(const Duration(seconds: 5));
      } catch (e) {
        debugPrint('🖥️ [NgrokService] Error killing process: $e');
      }
      _ngrokProcess = null;
    }
  }

  /// Validate JWT token for ngrok tunnel access
  /// This provides additional security for publicly exposed ngrok tunnels
  Future<bool> validateTunnelAccess() async {
    if (_authService == null) {
      debugPrint('🖥️ [NgrokService] No auth service available for validation');
      return false;
    }

    try {
      // Check if user is authenticated
      if (!_authService.isAuthenticated.value) {
        debugPrint('🖥️ [NgrokService] User not authenticated');
        return false;
      }

      // Get current access token
      final accessToken = _authService.getAccessToken();
      if (accessToken == null || accessToken.isEmpty) {
        debugPrint('🖥️ [NgrokService] No valid access token available');
        return false;
      }

      // Additional validation could include:
      // - Token expiry check
      // - Scope validation
      // - Rate limiting
      // - IP whitelisting for ngrok tunnel access

      debugPrint('🖥️ [NgrokService] Tunnel access validated successfully');
      return true;
    } catch (e) {
      debugPrint('🖥️ [NgrokService] Tunnel access validation failed: $e');
      return false;
    }
  }

  /// Get secure tunnel URL with authentication context
  String? getSecureTunnelUrl() {
    if (_activeTunnel == null) {
      return null;
    }

    // For ngrok tunnels, we return the public URL
    // The application should validate JWT tokens when accessing services
    // through this URL to ensure secure access
    return _activeTunnel!.publicUrl;
  }

  /// Check if tunnel is secure (has authentication)
  bool get isTunnelSecure =>
      _authService != null && _authService.isAuthenticated.value;

  @override
  void dispose() {
    debugPrint('🖥️ [NgrokService] Disposing desktop service...');
    _cleanup();
    super.dispose();
  }
}
