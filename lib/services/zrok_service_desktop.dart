import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'zrok_service.dart';
import 'auth_service.dart';
import '../config/app_config.dart';

/// Desktop zrok service implementation
/// Provides full zrok functionality on Windows, Linux, and macOS
class ZrokServiceDesktop extends ZrokService {
  ZrokConfig _config = ZrokConfig.defaultConfig();
  ZrokTunnel? _activeTunnel;
  bool _isRunning = false;
  bool _isStarting = false;
  String? _lastError;
  Process? _zrokProcess;
  Timer? _startupTimer;
  final AuthService? _authService;

  // HTTP client for API communication
  late http.Client _httpClient;

  // Tunnel registration and health monitoring
  Timer? _registrationHeartbeat;
  Timer? _healthMonitor;
  String? _registeredTunnelId;

  // Startup timeout for zrok initialization
  static const Duration _startupTimeout = Duration(seconds: 30);

  ZrokServiceDesktop({AuthService? authService}) : _authService = authService {
    debugPrint(
      '🌐 [ZrokService] Desktop service initialized with Auth0 integration',
    );
  }

  @override
  ZrokConfig get config => _config;

  @override
  ZrokTunnel? get activeTunnel => _activeTunnel;

  @override
  bool get isRunning => _isRunning;

  @override
  bool get isStarting => _isStarting;

  @override
  String? get lastError => _lastError;

  @override
  bool get isSupported => true; // Full support on desktop

  @override
  Future<void> initialize() async {
    debugPrint('🌐 [ZrokService] Initializing desktop zrok service...');

    // Initialize HTTP client
    _httpClient = http.Client();

    try {
      // Check if zrok is installed
      final isInstalled = await isZrokInstalled();
      if (!isInstalled) {
        _lastError = 'Zrok is not installed or not found in PATH';
        debugPrint('🌐 [ZrokService] $_lastError');
        return;
      }

      // Get version information
      final version = await getZrokVersion();
      debugPrint('🌐 [ZrokService] Found zrok version: $version');

      // Check if environment is enabled
      final isEnvEnabled = await isEnvironmentEnabled();
      if (!isEnvEnabled) {
        debugPrint(
          '🌐 [ZrokService] Zrok environment not enabled - will need account token',
        );
      }

      // Start health monitoring
      _startHealthMonitoring();

      debugPrint('🌐 [ZrokService] Desktop service initialized successfully');
    } catch (e) {
      _lastError = 'Failed to initialize zrok service: $e';
      debugPrint('🌐 [ZrokService] Initialization error: $_lastError');
    }
  }

  @override
  Future<ZrokTunnel?> startTunnel(ZrokConfig config) async {
    if (_isRunning || _isStarting) {
      debugPrint('🌐 [ZrokService] Tunnel already running or starting');
      return _activeTunnel;
    }

    if (!config.enabled) {
      debugPrint('🌐 [ZrokService] Zrok is disabled in configuration');
      return null;
    }

    _isStarting = true;
    _lastError = null;
    _config = config;
    notifyListeners();

    try {
      debugPrint('🌐 [ZrokService] Starting zrok tunnel...');
      debugPrint('🌐 [ZrokService] Config: $config');

      // Check if zrok is installed
      if (!await isZrokInstalled()) {
        throw Exception('Zrok is not installed or not found in PATH');
      }

      // Stop any existing tunnel
      await stopTunnel();

      // Check if environment is enabled
      if (!await isEnvironmentEnabled()) {
        if (config.accountToken != null) {
          debugPrint('🌐 [ZrokService] Enabling zrok environment...');
          final enabled = await enableEnvironment(config.accountToken!);
          if (!enabled) {
            throw Exception('Failed to enable zrok environment');
          }
        } else {
          throw Exception(
            'Zrok environment not enabled and no account token provided',
          );
        }
      }

      // Build zrok command
      final command = _buildZrokCommand(config);
      debugPrint('🌐 [ZrokService] Executing: ${command.join(' ')}');

      // Start zrok process
      _zrokProcess = await Process.start(
        command.first,
        command.skip(1).toList(),
        mode: ProcessStartMode.normal,
      );

      // Set up process monitoring
      _setupProcessMonitoring();

      // Wait for zrok to start and get tunnel info
      _startupTimer = Timer(_startupTimeout, () {
        if (_isStarting) {
          _handleStartupTimeout();
        }
      });

      // Poll for tunnel information
      await _waitForTunnelReady();

      // Register tunnel with API backend
      if (_activeTunnel != null) {
        await _registerTunnelWithBackend(_activeTunnel!);
        _startRegistrationHeartbeat();
      }

      return _activeTunnel;
    } catch (e) {
      _lastError = 'Failed to start zrok tunnel: $e';
      debugPrint('🌐 [ZrokService] Start tunnel error: $_lastError');
      await _cleanup();
      rethrow;
    } finally {
      _isStarting = false;
      notifyListeners();
    }
  }

  @override
  Future<void> stopTunnel() async {
    debugPrint('🌐 [ZrokService] Stopping zrok tunnel...');

    // Unregister tunnel from backend
    if (_registeredTunnelId != null) {
      await _unregisterTunnelFromBackend(_registeredTunnelId!);
      _registeredTunnelId = null;
    }

    // Stop heartbeat and health monitoring
    _stopRegistrationHeartbeat();

    await _cleanup();

    _isRunning = false;
    _activeTunnel = null;
    _lastError = null;

    debugPrint('🌐 [ZrokService] Zrok tunnel stopped');
    notifyListeners();
  }

  @override
  Future<bool> isZrokInstalled() async {
    try {
      final result = await Process.run('zrok', ['version']);
      return result.exitCode == 0;
    } catch (e) {
      debugPrint('🌐 [ZrokService] Zrok not found in PATH: $e');
      return false;
    }
  }

  @override
  Future<String?> getZrokVersion() async {
    try {
      final result = await Process.run('zrok', ['version']);
      if (result.exitCode == 0) {
        final output = result.stdout.toString().trim();
        // Extract version from output (format may vary)
        final versionMatch = RegExp(r'v?(\d+\.\d+\.\d+)').firstMatch(output);
        return versionMatch?.group(1) ?? output;
      }
    } catch (e) {
      debugPrint('🌐 [ZrokService] Failed to get zrok version: $e');
    }
    return null;
  }

  @override
  Future<void> updateConfiguration(ZrokConfig newConfig) async {
    final wasRunning = _isRunning;
    final oldConfig = _config;

    _config = newConfig;

    // If configuration changed and tunnel was running, restart it
    if (wasRunning && _configurationChanged(oldConfig, newConfig)) {
      debugPrint(
        '🖥️ [ZrokService] Configuration changed, restarting tunnel...',
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

    return status;
  }

  @override
  Future<bool> enableEnvironment(String accountToken) async {
    try {
      debugPrint('🌐 [ZrokService] Enabling zrok environment...');

      final result = await Process.run('zrok', ['enable', accountToken]);

      if (result.exitCode == 0) {
        debugPrint('🌐 [ZrokService] Environment enabled successfully');
        return true;
      } else {
        _lastError = 'Failed to enable environment: ${result.stderr}';
        debugPrint('🌐 [ZrokService] $_lastError');
        return false;
      }
    } catch (e) {
      _lastError = 'Error enabling environment: $e';
      debugPrint('🌐 [ZrokService] $_lastError');
      return false;
    }
  }

  @override
  Future<bool> isEnvironmentEnabled() async {
    try {
      final result = await Process.run('zrok', ['status']);
      return result.exitCode == 0 &&
          result.stdout.toString().contains('environment');
    } catch (e) {
      debugPrint('🌐 [ZrokService] Error checking environment status: $e');
      return false;
    }
  }

  @override
  Future<String?> createReservedShare(ZrokConfig config) async {
    try {
      debugPrint('🌐 [ZrokService] Creating reserved share...');

      final result = await Process.run('zrok', [
        'reserve',
        'public',
        '--backend-mode',
        config.backendMode,
      ]);

      if (result.exitCode == 0) {
        final output = result.stdout.toString();
        // Extract share token from output
        final tokenMatch = RegExp(r'share token: (\S+)').firstMatch(output);
        final shareToken = tokenMatch?.group(1);

        if (shareToken != null) {
          debugPrint('🌐 [ZrokService] Reserved share created: $shareToken');
          return shareToken;
        }
      }

      _lastError = 'Failed to create reserved share: ${result.stderr}';
      debugPrint('🌐 [ZrokService] $_lastError');
    } catch (e) {
      _lastError = 'Error creating reserved share: $e';
      debugPrint('🌐 [ZrokService] $_lastError');
    }
    return null;
  }

  @override
  Future<void> releaseReservedShare(String shareToken) async {
    try {
      debugPrint('🌐 [ZrokService] Releasing reserved share: $shareToken');

      final result = await Process.run('zrok', ['release', shareToken]);

      if (result.exitCode == 0) {
        debugPrint('🌐 [ZrokService] Reserved share released successfully');
      } else {
        _lastError = 'Failed to release reserved share: ${result.stderr}';
        debugPrint('🌐 [ZrokService] $_lastError');
      }
    } catch (e) {
      _lastError = 'Error releasing reserved share: $e';
      debugPrint('🌐 [ZrokService] $_lastError');
    }
  }

  @override
  void dispose() {
    _cleanup();
    super.dispose();
  }

  // Helper methods

  List<String> _buildZrokCommand(ZrokConfig config) {
    final command = <String>['zrok', 'share'];

    if (config.useReservedShare && config.reservedShareToken != null) {
      command.addAll(['reserved', config.reservedShareToken!]);
    } else {
      command.add('public');
    }

    command.addAll([
      '--backend-mode',
      config.backendMode,
      '${config.localHost}:${config.localPort}',
    ]);

    return command;
  }

  void _setupProcessMonitoring() {
    if (_zrokProcess == null) return;

    // Monitor stdout for tunnel information
    _zrokProcess!.stdout.transform(utf8.decoder).listen((data) {
      debugPrint('🌐 [ZrokService] stdout: $data');
      _parseZrokOutput(data);
    });

    // Monitor stderr for errors
    _zrokProcess!.stderr.transform(utf8.decoder).listen((data) {
      debugPrint('🌐 [ZrokService] stderr: $data');
      if (data.toLowerCase().contains('error')) {
        _lastError = data.trim();
        notifyListeners();
      }
    });

    // Monitor process exit
    _zrokProcess!.exitCode.then((exitCode) {
      debugPrint('🌐 [ZrokService] Process exited with code: $exitCode');
      if (exitCode != 0 && _isRunning) {
        _lastError = 'Zrok process exited unexpectedly (code: $exitCode)';
        _isRunning = false;
        _activeTunnel = null;
        notifyListeners();
      }
    });
  }

  void _parseZrokOutput(String output) {
    // Parse zrok output to extract tunnel information
    // Example output: "https://abc123.share.zrok.io"
    final urlMatch = RegExp(
      r'https?://[^\s]+\.share\.zrok\.io[^\s]*',
    ).firstMatch(output);

    if (urlMatch != null && _activeTunnel == null) {
      final publicUrl = urlMatch.group(0)!;
      final localAddress = '${_config.localHost}:${_config.localPort}';

      _activeTunnel = ZrokTunnel(
        publicUrl: publicUrl,
        localUrl: localAddress,
        protocol: _config.protocol,
        shareToken: _extractShareToken(output) ?? 'unknown',
        createdAt: DateTime.now(),
        isActive: true,
        isReserved: _config.useReservedShare,
      );

      _isRunning = true;
      _startupTimer?.cancel();

      debugPrint('🌐 [ZrokService] Tunnel established: $publicUrl');
      notifyListeners();
    }
  }

  String? _extractShareToken(String output) {
    // Try to extract share token from output
    final tokenMatch = RegExp(r'share token: (\S+)').firstMatch(output);
    return tokenMatch?.group(1);
  }

  Future<void> _waitForTunnelReady() async {
    // Wait for tunnel to be established (up to startup timeout)
    final completer = Completer<void>();

    Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (_activeTunnel != null || !_isStarting) {
        timer.cancel();
        completer.complete();
      }
    });

    return completer.future;
  }

  void _handleStartupTimeout() {
    if (_isStarting) {
      _lastError = 'Zrok tunnel startup timeout';
      debugPrint('🌐 [ZrokService] $_lastError');
      _cleanup();
      notifyListeners();
    }
  }

  Future<void> _cleanup() async {
    _startupTimer?.cancel();
    _startupTimer = null;

    // Stop registration heartbeat and health monitoring
    _stopRegistrationHeartbeat();
    _healthMonitor?.cancel();
    _healthMonitor = null;

    if (_zrokProcess != null) {
      try {
        _zrokProcess!.kill();
        await _zrokProcess!.exitCode.timeout(const Duration(seconds: 5));
      } catch (e) {
        debugPrint('🌐 [ZrokService] Error killing process: $e');
      }
      _zrokProcess = null;
    }
  }

  bool _configurationChanged(ZrokConfig oldConfig, ZrokConfig newConfig) {
    return oldConfig.enabled != newConfig.enabled ||
        oldConfig.protocol != newConfig.protocol ||
        oldConfig.localPort != newConfig.localPort ||
        oldConfig.localHost != newConfig.localHost ||
        oldConfig.backendMode != newConfig.backendMode ||
        oldConfig.useReservedShare != newConfig.useReservedShare ||
        oldConfig.reservedShareToken != newConfig.reservedShareToken;
  }

  @override
  Future<bool> validateTunnelAccess() async {
    // Validate Auth0 authentication if available
    if (_authService != null) {
      final isAuthenticated = _authService.isAuthenticated.value;
      if (!isAuthenticated) {
        debugPrint(
          '🌐 [ZrokService] Tunnel access denied - user not authenticated',
        );
        return false;
      }

      // Additional validation can be added here
      debugPrint(
        '🌐 [ZrokService] Tunnel access validated for authenticated user',
      );
      return true;
    }

    // If no auth service, allow access (for development/testing)
    return true;
  }

  /// Register tunnel with API backend
  Future<void> _registerTunnelWithBackend(ZrokTunnel tunnel) async {
    if (_authService == null || !_authService.isAuthenticated.value) {
      debugPrint('🌐 [ZrokService] Cannot register tunnel - not authenticated');
      return;
    }

    try {
      final accessToken = _authService.getAccessToken();
      final response = await _httpClient.post(
        Uri.parse('${AppConfig.apiBaseUrl}/api/zrok/register'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: json.encode({
          'tunnelInfo': {
            'publicUrl': tunnel.publicUrl,
            'localUrl': tunnel.localUrl,
            'shareToken': tunnel.shareToken,
            'protocol': tunnel.protocol,
            'userAgent': 'CloudToLocalLLM-Desktop',
            'version': '1.0.0',
            'platform': Platform.operatingSystem,
          },
        }),
      );

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        _registeredTunnelId = data['data']['tunnelId'];
        debugPrint(
          '🌐 [ZrokService] Tunnel registered successfully: $_registeredTunnelId',
        );
      } else {
        debugPrint(
          '🌐 [ZrokService] Failed to register tunnel: ${response.statusCode}',
        );
      }
    } catch (e) {
      debugPrint('🌐 [ZrokService] Error registering tunnel: $e');
    }
  }

  /// Unregister tunnel from API backend
  Future<void> _unregisterTunnelFromBackend(String tunnelId) async {
    if (_authService == null || !_authService.isAuthenticated.value) {
      return;
    }

    try {
      final accessToken = _authService.getAccessToken();
      final response = await _httpClient.delete(
        Uri.parse('${AppConfig.apiBaseUrl}/api/zrok/unregister'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: json.encode({'tunnelId': tunnelId}),
      );

      if (response.statusCode == 200) {
        debugPrint(
          '🌐 [ZrokService] Tunnel unregistered successfully: $tunnelId',
        );
      } else {
        debugPrint(
          '🌐 [ZrokService] Failed to unregister tunnel: ${response.statusCode}',
        );
      }
    } catch (e) {
      debugPrint('🌐 [ZrokService] Error unregistering tunnel: $e');
    }
  }

  /// Start registration heartbeat
  void _startRegistrationHeartbeat() {
    _stopRegistrationHeartbeat();

    _registrationHeartbeat = Timer.periodic(const Duration(seconds: 30), (
      _,
    ) async {
      if (_registeredTunnelId != null) {
        await _updateTunnelHeartbeat(_registeredTunnelId!);
      }
    });

    debugPrint('🌐 [ZrokService] Registration heartbeat started');
  }

  /// Stop registration heartbeat
  void _stopRegistrationHeartbeat() {
    _registrationHeartbeat?.cancel();
    _registrationHeartbeat = null;
  }

  /// Update tunnel heartbeat
  Future<void> _updateTunnelHeartbeat(String tunnelId) async {
    if (_authService == null || !_authService.isAuthenticated.value) {
      return;
    }

    try {
      final accessToken = _authService.getAccessToken();
      final response = await _httpClient.post(
        Uri.parse('${AppConfig.apiBaseUrl}/api/zrok/heartbeat'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: json.encode({'tunnelId': tunnelId}),
      );

      if (response.statusCode != 200) {
        debugPrint('🌐 [ZrokService] Heartbeat failed: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('🌐 [ZrokService] Error updating heartbeat: $e');
    }
  }

  /// Start health monitoring
  void _startHealthMonitoring() {
    _healthMonitor?.cancel();

    _healthMonitor = Timer.periodic(const Duration(minutes: 1), (_) async {
      if (_activeTunnel != null && !await _verifyTunnelHealth()) {
        debugPrint(
          '🌐 [ZrokService] Tunnel health check failed, attempting recovery',
        );
        await _attemptTunnelRecovery();
      }
    });

    debugPrint('🌐 [ZrokService] Health monitoring started');
  }

  /// Verify tunnel health
  Future<bool> _verifyTunnelHealth() async {
    if (_activeTunnel == null) return false;

    try {
      final response = await _httpClient
          .head(Uri.parse(_activeTunnel!.publicUrl))
          .timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('🌐 [ZrokService] Health check failed: $e');
      return false;
    }
  }

  /// Attempt tunnel recovery
  Future<void> _attemptTunnelRecovery() async {
    try {
      debugPrint('🌐 [ZrokService] Attempting tunnel recovery...');

      // Stop current tunnel
      await stopTunnel();

      // Restart with same configuration
      await startTunnel(_config);

      debugPrint('🌐 [ZrokService] Tunnel recovery successful');
    } catch (e) {
      debugPrint('🌐 [ZrokService] Tunnel recovery failed: $e');
      _lastError = 'Tunnel recovery failed: $e';
      notifyListeners();
    }
  }
}
