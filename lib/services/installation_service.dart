import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:process_run/process_run.dart';
import '../config/app_config.dart';

/// Service for installing and configuring LLM providers (Ollama and LM Studio)
class InstallationService {
  /// Check if Ollama is installed
  Future<bool> isOllamaInstalled() async {
    try {
      // Check if Ollama executable exists in common locations
      final result = await Process.run('where', ['ollama.exe']);
      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }

  /// Check if LM Studio is installed
  Future<bool> isLmStudioInstalled() async {
    try {
      // Check common installation paths for LM Studio
      final programFiles = Platform.environment['ProgramFiles'] ?? 'C:\\Program Files';
      final programFilesX86 = Platform.environment['ProgramFiles(x86)'] ?? 'C:\\Program Files (x86)';
      
      final paths = [
        path.join(programFiles, 'LM Studio', 'LM Studio.exe'),
        path.join(programFilesX86, 'LM Studio', 'LM Studio.exe'),
      ];
      
      for (final p in paths) {
        if (await File(p).exists()) {
          return true;
        }
      }
      
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Install Ollama
  Future<bool> installOllama({Function(double)? onProgress, Function(String)? onStatus}) async {
    try {
      onStatus?.call('Downloading Ollama installer...');
      
      // Download Ollama installer
      final tempDir = await getTemporaryDirectory();
      final installerPath = path.join(tempDir.path, 'ollama-installer.exe');
      
      final response = await http.get(
        Uri.parse('https://ollama.ai/download/ollama-windows-amd64.exe'),
        headers: {'User-Agent': 'CloudToLocalLLM-App'},
      );
      
      if (response.statusCode != 200) {
        throw Exception('Failed to download Ollama installer: ${response.statusCode}');
      }
      
      // Save installer to temp directory
      await File(installerPath).writeAsBytes(response.bodyBytes);
      onProgress?.call(0.3);
      
      // Run installer
      onStatus?.call('Installing Ollama...');
      final installResult = await Process.run(
        installerPath,
        ['/S'], // Silent install
        runInShell: true,
      );
      
      if (installResult.exitCode != 0) {
        throw Exception('Failed to install Ollama: ${installResult.stderr}');
      }
      
      onProgress?.call(0.7);
      
      // Start Ollama service
      onStatus?.call('Starting Ollama service...');
      await Process.run('ollama', ['serve'], runInShell: true);
      
      // Wait for Ollama to start
      bool ollamaRunning = false;
      for (int i = 0; i < 30; i++) {
        try {
          final response = await http.get(Uri.parse('${AppConfig.ollamaBaseUrl}/api/tags'));
          if (response.statusCode == 200) {
            ollamaRunning = true;
            break;
          }
        } catch (e) {
          // Ignore errors while waiting for Ollama to start
        }
        
        await Future.delayed(const Duration(seconds: 1));
      }
      
      if (!ollamaRunning) {
        throw Exception('Ollama service failed to start');
      }
      
      // Pull default model
      onStatus?.call('Downloading default model (tinyllama)...');
      final pullResult = await Process.run('ollama', ['pull', 'tinyllama'], runInShell: true);
      
      if (pullResult.exitCode != 0) {
        throw Exception('Failed to pull default model: ${pullResult.stderr}');
      }
      
      onProgress?.call(1.0);
      onStatus?.call('Ollama installation complete');
      
      return true;
    } catch (e) {
      onStatus?.call('Error installing Ollama: $e');
      return false;
    }
  }

  /// Install LM Studio
  Future<bool> installLmStudio({Function(double)? onProgress, Function(String)? onStatus}) async {
    try {
      onStatus?.call('Downloading LM Studio installer...');
      
      // Download LM Studio installer
      final tempDir = await getTemporaryDirectory();
      final installerPath = path.join(tempDir.path, 'lmstudio-installer.exe');
      
      final response = await http.get(
        Uri.parse('https://lmstudio.ai/download/windows'),
        headers: {'User-Agent': 'CloudToLocalLLM-App'},
      );
      
      if (response.statusCode != 200) {
        throw Exception('Failed to download LM Studio installer: ${response.statusCode}');
      }
      
      // Save installer to temp directory
      await File(installerPath).writeAsBytes(response.bodyBytes);
      onProgress?.call(0.3);
      
      // Run installer
      onStatus?.call('Installing LM Studio...');
      final installResult = await Process.run(
        installerPath,
        ['/S'], // Silent install
        runInShell: true,
      );
      
      if (installResult.exitCode != 0) {
        throw Exception('Failed to install LM Studio: ${installResult.stderr}');
      }
      
      onProgress?.call(0.7);
      
      // LM Studio doesn't have a CLI to start it or download models automatically
      // We'll need to instruct the user to start it manually and configure it
      
      onProgress?.call(1.0);
      onStatus?.call('LM Studio installation complete. Please start LM Studio manually to complete setup.');
      
      return true;
    } catch (e) {
      onStatus?.call('Error installing LM Studio: $e');
      return false;
    }
  }

  /// Check if Ollama is running
  Future<bool> isOllamaRunning() async {
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.ollamaBaseUrl}/api/tags'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 5));
      
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Check if LM Studio is running
  Future<bool> isLmStudioRunning() async {
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.lmStudioBaseUrl}/v1/models'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 5));
      
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Start Ollama if it's installed but not running
  Future<bool> startOllama() async {
    try {
      if (await isOllamaRunning()) {
        return true;
      }
      
      if (!await isOllamaInstalled()) {
        return false;
      }
      
      // Start Ollama service
      await Process.run('ollama', ['serve'], runInShell: true);
      
      // Wait for Ollama to start
      for (int i = 0; i < 30; i++) {
        if (await isOllamaRunning()) {
          return true;
        }
        await Future.delayed(const Duration(seconds: 1));
      }
      
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Start LM Studio if it's installed but not running
  Future<bool> startLmStudio() async {
    try {
      if (await isLmStudioRunning()) {
        return true;
      }
      
      if (!await isLmStudioInstalled()) {
        return false;
      }
      
      // Try to find LM Studio executable
      final programFiles = Platform.environment['ProgramFiles'] ?? 'C:\\Program Files';
      final programFilesX86 = Platform.environment['ProgramFiles(x86)'] ?? 'C:\\Program Files (x86)';
      
      final paths = [
        path.join(programFiles, 'LM Studio', 'LM Studio.exe'),
        path.join(programFilesX86, 'LM Studio', 'LM Studio.exe'),
      ];
      
      String? lmStudioPath;
      for (final p in paths) {
        if (await File(p).exists()) {
          lmStudioPath = p;
          break;
        }
      }
      
      if (lmStudioPath == null) {
        return false;
      }
      
      // Start LM Studio
      await Process.run(lmStudioPath, [], runInShell: true);
      
      // Wait for LM Studio to start
      for (int i = 0; i < 30; i++) {
        if (await isLmStudioRunning()) {
          return true;
        }
        await Future.delayed(const Duration(seconds: 1));
      }
      
      return false;
    } catch (e) {
      return false;
    }
  }
}