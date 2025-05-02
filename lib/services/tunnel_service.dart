import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import '../config/app_config.dart';
import 'auth_service.dart';
import 'windows_service.dart';

class TunnelService {
  final AuthService authService;
  final WindowsService? windowsService;
  
  Process? _ngrokProcess;
  bool _isRunning = false;
  final ValueNotifier<bool> isConnected = ValueNotifier<bool>(false);
  final ValueNotifier<String> tunnelUrl = ValueNotifier<String>('');
  Timer? _healthCheckTimer;
  
  TunnelService({
    required this.authService,
    this.windowsService,
  }) {
    // Listen to value changes to update system tray
    isConnected.addListener(_onTunnelStatusChanged);
    tunnelUrl.addListener(_onTunnelStatusChanged);
  }
  
  // Handle tunnel status changes
  void _onTunnelStatusChanged() {
    // Update Windows service if available
    if (Platform.isWindows && windowsService != null) {
      windowsService!.updateNativeTunnelStatus(isConnected.value, tunnelUrl.value);
      
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
    
    try {
      // Get config paths from the application config
      final configFile = File(path.join(Directory.current.path, 'tools', 'config.json'));
      if (!await configFile.exists()) {
        print('Config file not found');
        return false;
      }
      
      final config = jsonDecode(await configFile.readAsString());
      final ngrokPath = config['ngrok_path'] as String;
      final ngrokConfig = config['ngrok_config'] as String;
      
      // Start ngrok
      _ngrokProcess = await Process.start(
        ngrokPath,
        ['start', '--config', ngrokConfig, 'ollama'],
        runInShell: true,
      );
      
      // Listen to process output
      _ngrokProcess!.stdout.transform(utf8.decoder).listen((data) {
        print('ngrok stdout: $data');
        // Extract tunnel URL from output
        if (data.contains('https://')) {
          final url = RegExp(r'https://[^\s]+').firstMatch(data)?.group(0);
          if (url != null) {
            tunnelUrl.value = url;
            isConnected.value = true;
            _isRunning = true;
          }
        }
      });
      
      _ngrokProcess!.stderr.transform(utf8.decoder).listen((data) {
        print('ngrok stderr: $data');
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
      print('Error starting tunnel: $e');
      await stopTunnel();
      return false;
    }
  }
  
  // Stop the tunnel
  Future<void> stopTunnel() async {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = null;
    
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
        final response = await http.get(Uri.parse('${tunnelUrl.value}/api/tags'))
            .timeout(const Duration(seconds: 5));
        return response.statusCode == 200;
      }
      
      return false;
    } catch (e) {
      print('Error checking tunnel status: $e');
      return false;
    }
  }
  
  // Clean up resources
  void dispose() {
    isConnected.removeListener(_onTunnelStatusChanged);
    tunnelUrl.removeListener(_onTunnelStatusChanged);
    stopTunnel();
  }
}