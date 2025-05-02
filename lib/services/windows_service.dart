import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:process_run/process_run.dart';
import '../config/app_config.dart';
import 'tunnel_service.dart';

/// Service to handle Windows-specific operations and LLM management
class WindowsService {
  static const platform = MethodChannel('com.cloudtolocalllm/windows');
  
  // Value notifiers for service status
  final ValueNotifier<bool> isOllamaRunning = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isLmStudioRunning = ValueNotifier<bool>(false);
  final ValueNotifier<String> ollamaVersion = ValueNotifier<String>('');
  final ValueNotifier<bool> isTunnelConnected = ValueNotifier<bool>(false);
  final ValueNotifier<String> tunnelUrl = ValueNotifier<String>('');
  
  // Timer for status checks
  Timer? _statusCheckTimer;
  
  // Reference to the tunnel service (will be set later)
  TunnelService? _tunnelService;
  
  // Singleton pattern
  static final WindowsService _instance = WindowsService._internal();
  factory WindowsService() => _instance;
  WindowsService._internal();
  
  // Set the tunnel service reference
  void setTunnelService(TunnelService tunnelService) {
    _tunnelService = tunnelService;
    
    // Sync initial values
    isTunnelConnected.value = tunnelService.isConnected.value;
    tunnelUrl.value = tunnelService.tunnelUrl.value;
  }
  
  /// Initialize the Windows service
  Future<void> initialize() async {
    // Set up method channel handler
    _setupMethodChannel();
    
    // Start status check timer
    _statusCheckTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      checkOllamaStatus();
      checkLmStudioStatus();
    });
    
    // Initial check
    await checkOllamaStatus();
    await checkLmStudioStatus();
  }
  
  /// Set up the method channel handler
  void _setupMethodChannel() {
    platform.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'startLlm':
          return await startOllama();
        case 'checkLlmStatus':
          return await checkOllamaStatus();
        case 'connectTunnel':
          return await connectTunnel();
        case 'disconnectTunnel':
          return await disconnectTunnel();
        case 'checkTunnelStatus':
          return await checkTunnelStatus();
        default:
          throw PlatformException(
            code: 'Unimplemented',
            details: 'Method ${call.method} not implemented',
          );
      }
    });
  }
  
  /// Update native code about LLM status
  Future<void> updateNativeLlmStatus() async {
    try {
      await platform.invokeMethod('updateLlmStatus', {
        'isRunning': isOllamaRunning.value,
      });
    } on PlatformException catch (e) {
      print('Error updating native LLM status: $e');
    }
  }
  
  /// Update native code about tunnel status
  Future<void> updateNativeTunnelStatus(bool isConnected, String url) async {
    try {
      await platform.invokeMethod('updateTunnelStatus', {
        'isConnected': isConnected,
        'url': url,
      });
    } on PlatformException catch (e) {
      print('Error updating native tunnel status: $e');
    }
  }
  
  /// Dispose the service
  void dispose() {
    _statusCheckTimer?.cancel();
  }
  
  /// Check if Ollama is running
  Future<bool> checkOllamaStatus() async {
    try {
      // Check if Ollama port is accessible
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 2);
      
      final request = await client.getUrl(Uri.parse('${AppConfig.ollamaBaseUrl}/api/tags'));
      final response = await request.close();
      client.close();
      
      final isRunning = response.statusCode == 200;
      isOllamaRunning.value = isRunning;
      
      if (isRunning) {
        await _getOllamaVersion();
      }
      
      // Update native code
      await updateNativeLlmStatus();
      
      return isRunning;
    } catch (e) {
      isOllamaRunning.value = false;
      
      // Update native code
      await updateNativeLlmStatus();
      
      return false;
    }
  }
  
  /// Check if LM Studio is running
  Future<bool> checkLmStudioStatus() async {
    try {
      // Check if LM Studio port is accessible
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 2);
      
      final request = await client.getUrl(Uri.parse('${AppConfig.lmStudioBaseUrl}/models'));
      final response = await request.close();
      client.close();
      
      final isRunning = response.statusCode == 200;
      isLmStudioRunning.value = isRunning;
      return isRunning;
    } catch (e) {
      isLmStudioRunning.value = false;
      return false;
    }
  }
  
  /// Start Ollama service
  Future<bool> startOllama() async {
    try {
      if (await checkOllamaStatus()) {
        // Already running
        return true;
      }
      
      // Try to start Ollama as a Windows service first
      final result = await _runPowerShellCommand(
        'Start-Service -Name "Ollama" -ErrorAction SilentlyContinue'
      );
      
      if (result.exitCode == 0) {
        // Give it a moment to start
        await Future.delayed(const Duration(seconds: 2));
        return await checkOllamaStatus();
      }
      
      // If service start failed, try to run Ollama executable
      final ollamaExePath = await _findOllamaExecutable();
      if (ollamaExePath == null) {
        return false;
      }
      
      // Start Ollama process
      await Process.start(
        ollamaExePath, 
        ['serve'],
        mode: ProcessStartMode.detached,
      );
      
      // Give it a moment to start
      await Future.delayed(const Duration(seconds: 2));
      return await checkOllamaStatus();
    } catch (e) {
      print('Error starting Ollama: $e');
      return false;
    }
  }
  
  /// Stop Ollama service
  Future<bool> stopOllama() async {
    try {
      if (!await checkOllamaStatus()) {
        // Already stopped
        return true;
      }
      
      // Try to stop Ollama as a Windows service first
      final result = await _runPowerShellCommand(
        'Stop-Service -Name "Ollama" -ErrorAction SilentlyContinue'
      );
      
      if (result.exitCode == 0) {
        // Give it a moment to stop
        await Future.delayed(const Duration(seconds: 2));
        return !await checkOllamaStatus();
      }
      
      // If service stop failed, try to kill Ollama process
      await _runPowerShellCommand(
        'Get-Process -Name "ollama" -ErrorAction SilentlyContinue | Stop-Process -Force'
      );
      
      // Give it a moment to stop
      await Future.delayed(const Duration(seconds: 2));
      return !await checkOllamaStatus();
    } catch (e) {
      print('Error stopping Ollama: $e');
      return false;
    }
  }
  
  /// Install Ollama as a Windows service
  Future<bool> installOllamaAsService() async {
    try {
      // Stop any running Ollama process
      await stopOllama();
      
      // Try to find Ollama executable
      final ollamaExePath = await _findOllamaExecutable();
      if (ollamaExePath == null) {
        return false;
      }
      
      // Create Windows service using PowerShell
      final result = await _runPowerShellCommand('''
        \$exists = Get-Service -Name "Ollama" -ErrorAction SilentlyContinue
        if (\$exists) {
          # Remove existing service
          sc.exe delete Ollama
        }
        
        # Create new service
        sc.exe create Ollama binPath= "$ollamaExePath serve" start= auto DisplayName= "Ollama LLM Server"
        sc.exe description Ollama "Ollama API server for large language models"
        sc.exe start Ollama
      ''');
      
      if (result.exitCode == 0) {
        // Give it a moment to start
        await Future.delayed(const Duration(seconds: 2));
        return await checkOllamaStatus();
      }
      
      return false;
    } catch (e) {
      print('Error installing Ollama as service: $e');
      return false;
    }
  }
  
  /// Check if Ollama is installed
  Future<bool> isOllamaInstalled() async {
    try {
      final ollamaExePath = await _findOllamaExecutable();
      return ollamaExePath != null;
    } catch (e) {
      return false;
    }
  }
  
  /// Connect to tunnel
  Future<bool> connectTunnel() async {
    if (_tunnelService == null) {
      print('Tunnel service not set');
      return false;
    }
    
    try {
      // Use the actual tunnel service to connect
      final result = await _tunnelService!.startTunnel();
      
      // The status will be updated through the listeners in TunnelService
      return result;
    } catch (e) {
      print('Error connecting to tunnel: $e');
      return false;
    }
  }
  
  /// Disconnect from tunnel
  Future<bool> disconnectTunnel() async {
    if (_tunnelService == null) {
      print('Tunnel service not set');
      return false;
    }
    
    try {
      // Use the actual tunnel service to disconnect
      await _tunnelService!.stopTunnel();
      
      // The status will be updated through the listeners in TunnelService
      return true;
    } catch (e) {
      print('Error disconnecting from tunnel: $e');
      return false;
    }
  }
  
  /// Check tunnel status
  Future<bool> checkTunnelStatus() async {
    if (_tunnelService == null) {
      print('Tunnel service not set');
      return false;
    }
    
    try {
      // Use the actual tunnel service to check status
      return await _tunnelService!.checkTunnelStatus();
    } catch (e) {
      print('Error checking tunnel status: $e');
      return false;
    }
  }
  
  /// Find Ollama executable path
  Future<String?> _findOllamaExecutable() async {
    try {
      // Common installation locations
      final possiblePaths = [
        'C:\\Program Files\\Ollama\\ollama.exe',
        'C:\\Ollama\\ollama.exe',
        path.join(Platform.environment['LOCALAPPDATA'] ?? '', 'Ollama\\ollama.exe'),
      ];
      
      // Check if any of the paths exist
      for (final p in possiblePaths) {
        if (await File(p).exists()) {
          return p;
        }
      }
      
      // Try to find using where command
      final result = await _runPowerShellCommand('where.exe ollama');
      if (result.exitCode == 0 && result.stdout.toString().trim().isNotEmpty) {
        final wherePath = result.stdout.toString().trim().split('\n').first;
        if (await File(wherePath).exists()) {
          return wherePath;
        }
      }
      
      return null;
    } catch (e) {
      print('Error finding Ollama executable: $e');
      return null;
    }
  }
  
  /// Get Ollama version
  Future<void> _getOllamaVersion() async {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 2);
      
      final request = await client.getUrl(Uri.parse('${AppConfig.ollamaBaseUrl}/api/version'));
      final response = await request.close();
      
      if (response.statusCode == 200) {
        final versionStr = await response.transform(utf8.decoder).join();
        ollamaVersion.value = versionStr.trim();
      } else {
        ollamaVersion.value = '';
      }
      
      client.close();
    } catch (e) {
      ollamaVersion.value = '';
    }
  }
  
  /// Run a PowerShell command
  Future<ProcessResult> _runPowerShellCommand(String command) async {
    final shell = Shell();
    return await shell.run('powershell.exe -Command "$command"');
  }
  
  /// Call a native method through the method channel
  Future<dynamic> _callNativeMethod(String method, [dynamic arguments]) async {
    try {
      return await platform.invokeMethod(method, arguments);
    } on PlatformException catch (e) {
      print('Error calling native method: $e');
      return null;
    }
  }
} 