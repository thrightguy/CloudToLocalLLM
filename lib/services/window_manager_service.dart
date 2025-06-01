import 'dart:io';
import 'package:flutter/foundation.dart';

/// Service for managing window state and visibility
class WindowManagerService {
  static final WindowManagerService _instance =
      WindowManagerService._internal();
  factory WindowManagerService() => _instance;
  WindowManagerService._internal();

  bool _isWindowVisible = true;
  bool _isMinimizedToTray = false;

  /// Show the application window
  Future<void> showWindow() async {
    try {
      if (Platform.isLinux) {
        // For Linux, we can use platform channels or system calls
        await _executeLinuxWindowCommand('show');
      }
      _isWindowVisible = true;
      _isMinimizedToTray = false;
      debugPrint("Window shown");
    } catch (e) {
      debugPrint("Failed to show window: $e");
    }
  }

  /// Hide the application window to system tray
  Future<void> hideToTray() async {
    try {
      if (Platform.isLinux) {
        await _executeLinuxWindowCommand('hide');
      }
      _isWindowVisible = false;
      _isMinimizedToTray = true;
      debugPrint("Window hidden to tray");
    } catch (e) {
      debugPrint("Failed to hide window: $e");
    }
  }

  /// Minimize the window (but keep it in taskbar)
  Future<void> minimizeWindow() async {
    try {
      if (Platform.isLinux) {
        await _executeLinuxWindowCommand('minimize');
      }
      _isWindowVisible = false;
      _isMinimizedToTray = false;
      debugPrint("Window minimized");
    } catch (e) {
      debugPrint("Failed to minimize window: $e");
    }
  }

  /// Maximize the window
  Future<void> maximizeWindow() async {
    try {
      if (Platform.isLinux) {
        await _executeLinuxWindowCommand('maximize');
      }
      _isWindowVisible = true;
      _isMinimizedToTray = false;
      debugPrint("Window maximized");
    } catch (e) {
      debugPrint("Failed to maximize window: $e");
    }
  }

  /// Toggle window visibility
  Future<void> toggleWindow() async {
    if (_isWindowVisible) {
      await hideToTray();
    } else {
      await showWindow();
    }
  }

  /// Execute Linux-specific window management commands
  Future<void> _executeLinuxWindowCommand(String command) async {
    try {
      // Use application name to identify our window

      switch (command) {
        case 'show':
          // Bring window to front and show it
          await Process.run('wmctrl', ['-a', 'CloudToLocalLLM']);
          break;
        case 'hide':
          // Hide the window (this is tricky in Linux, might need different approach)
          await Process.run(
              'wmctrl', ['-r', 'CloudToLocalLLM', '-b', 'add,hidden']);
          break;
        case 'minimize':
          await Process.run(
              'wmctrl', ['-r', 'CloudToLocalLLM', '-b', 'add,minimized']);
          break;
        case 'maximize':
          await Process.run('wmctrl', [
            '-r',
            'CloudToLocalLLM',
            '-b',
            'add,maximized_vert,maximized_horz'
          ]);
          break;
      }
    } catch (e) {
      debugPrint("Failed to execute window command '$command': $e");
      // Fallback: try alternative methods or ignore
    }
  }

  /// Check if window is currently visible
  bool get isWindowVisible => _isWindowVisible;

  /// Check if window is minimized to tray
  bool get isMinimizedToTray => _isMinimizedToTray;

  /// Set window visibility state (for internal tracking)
  void setWindowVisible(bool visible) {
    _isWindowVisible = visible;
    if (visible) {
      _isMinimizedToTray = false;
    }
  }

  /// Handle window close event (should minimize to tray instead of closing)
  Future<bool> handleWindowClose() async {
    await hideToTray();
    return false; // Prevent actual window close
  }
}
