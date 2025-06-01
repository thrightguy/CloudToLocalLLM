import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:system_tray/system_tray.dart';

import 'config/app_config.dart';
import 'services/auth_service.dart';
import 'services/tunnel_service.dart';
import 'services/tray_service.dart';
import 'providers/app_state_provider.dart';
import 'screens/main_screen.dart';
import 'screens/settings_screen.dart';
import 'utils/logger.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize logger
  AppLogger.init();
  AppLogger.info('Starting CloudToLocalLLM Bridge...');
  
  // Initialize window manager
  await windowManager.ensureInitialized();
  
  // Configure window
  WindowOptions windowOptions = const WindowOptions(
    size: Size(400, 300),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.normal,
    windowButtonVisibility: false,
  );
  
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
    
    // Hide window initially if system tray is available
    if (await SystemTray.initSystemTray()) {
      await windowManager.hide();
    }
  });
  
  runApp(
    ProviderScope(
      child: CloudToLocalLLMBridge(),
    ),
  );
}

class CloudToLocalLLMBridge extends ConsumerStatefulWidget {
  @override
  ConsumerState<CloudToLocalLLMBridge> createState() => _CloudToLocalLLMBridgeState();
}

class _CloudToLocalLLMBridgeState extends ConsumerState<CloudToLocalLLMBridge> 
    with WindowListener, TrayListener {
  
  late TrayService _trayService;
  
  @override
  void initState() {
    super.initState();
    _initializeServices();
  }
  
  Future<void> _initializeServices() async {
    try {
      // Initialize window listener
      windowManager.addListener(this);
      
      // Initialize tray service
      _trayService = TrayService();
      await _trayService.initialize();
      trayManager.addListener(this);
      
      // Initialize auth service
      final authService = ref.read(authServiceProvider);
      await authService.initialize();
      
      // Initialize tunnel service
      final tunnelService = ref.read(tunnelServiceProvider);
      await tunnelService.initialize();
      
      AppLogger.info('All services initialized successfully');
      
    } catch (e, stackTrace) {
      AppLogger.error('Failed to initialize services: $e', stackTrace);
    }
  }
  
  @override
  void dispose() {
    windowManager.removeListener(this);
    trayManager.removeListener(this);
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2563EB),
          brightness: Brightness.light,
        ),
        fontFamily: 'Inter',
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2563EB),
          brightness: Brightness.dark,
        ),
        fontFamily: 'Inter',
      ),
      themeMode: ThemeMode.system,
      home: const MainScreen(),
      routes: {
        '/settings': (context) => const SettingsScreen(),
      },
    );
  }
  
  // Window listener methods
  @override
  void onWindowClose() async {
    bool isPreventClose = await windowManager.isPreventClose();
    if (isPreventClose) {
      await windowManager.hide();
    }
  }
  
  @override
  void onWindowFocus() {
    // Make sure to call once.
    setState(() {});
  }
  
  @override
  void onWindowMinimize() async {
    // Hide to system tray when minimized
    await windowManager.hide();
  }
  
  // Tray listener methods
  @override
  void onTrayIconMouseDown() async {
    // Show/hide window on tray icon click
    bool isVisible = await windowManager.isVisible();
    if (isVisible) {
      await windowManager.hide();
    } else {
      await windowManager.show();
      await windowManager.focus();
    }
  }
  
  @override
  void onTrayIconRightMouseDown() {
    // Show context menu
    _trayService.showContextMenu();
  }
  
  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    _trayService.handleMenuItemClick(menuItem);
  }
}
