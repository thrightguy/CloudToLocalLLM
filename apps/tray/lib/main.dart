import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import 'package:tray_manager/tray_manager.dart';

import 'services/tray_service.dart';
import 'services/ipc_server.dart';
import 'services/config_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize window manager for desktop
  await windowManager.ensureInitialized();

  // Configure window - hidden by default for tray service
  WindowOptions windowOptions = const WindowOptions(
    size: Size(400, 300),
    minimumSize: Size(300, 200),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: true, // Hide from taskbar
    titleBarStyle: TitleBarStyle.hidden,
    title: 'CloudToLocalLLM Tray Service',
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    // Start hidden - this is a background service
    await windowManager.hide();
  });

  runApp(const CloudToLocalLLMTrayApp());
}

class CloudToLocalLLMTrayApp extends StatelessWidget {
  const CloudToLocalLLMTrayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ConfigService()),
        ChangeNotifierProvider(create: (_) => TrayService()),
        ChangeNotifierProvider(create: (_) => IPCServer()),
      ],
      child: MaterialApp(
        title: 'CloudToLocalLLM Tray Service',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          brightness: Brightness.dark,
        ),
        home: const TrayServiceHome(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

class TrayServiceHome extends StatefulWidget {
  const TrayServiceHome({super.key});

  @override
  State<TrayServiceHome> createState() => _TrayServiceHomeState();
}

class _TrayServiceHomeState extends State<TrayServiceHome>
    with TrayListener, WindowListener {
  @override
  void initState() {
    super.initState();
    trayManager.addListener(this);
    windowManager.addListener(this);
    _initializeServices();
  }

  @override
  void dispose() {
    trayManager.removeListener(this);
    windowManager.removeListener(this);
    super.dispose();
  }

  Future<void> _initializeServices() async {
    try {
      final configService = Provider.of<ConfigService>(context, listen: false);
      final trayService = Provider.of<TrayService>(context, listen: false);
      final ipcServer = Provider.of<IPCServer>(context, listen: false);

      // Initialize configuration
      await configService.initialize();

      // Initialize IPC server
      await ipcServer.start();

      // Initialize tray service
      await trayService.initialize(
        onShowWindow: _handleShowWindow,
        onHideWindow: _handleHideWindow,
        onSettings: _handleSettings,
        onQuit: _handleQuit,
      );

      debugPrint('Tray service initialized successfully');
    } catch (e) {
      debugPrint('Failed to initialize tray service: $e');
      // Show error dialog if needed
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Initialization Error'),
            content: Text('Failed to initialize tray service:\n$e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  void _handleShowWindow() {
    debugPrint('Tray requested: Show main window');
    final ipcServer = Provider.of<IPCServer>(context, listen: false);
    ipcServer.sendCommand({'command': 'SHOW'});
  }

  void _handleHideWindow() {
    debugPrint('Tray requested: Hide main window');
    final ipcServer = Provider.of<IPCServer>(context, listen: false);
    ipcServer.sendCommand({'command': 'HIDE'});
  }

  void _handleSettings() {
    debugPrint('Tray requested: Open settings');
    final ipcServer = Provider.of<IPCServer>(context, listen: false);
    ipcServer.sendCommand({'command': 'SETTINGS'});
  }

  void _handleQuit() {
    debugPrint('Tray requested: Quit application');
    final ipcServer = Provider.of<IPCServer>(context, listen: false);
    ipcServer.sendCommand({'command': 'QUIT'});

    // Give time for command to be sent, then exit
    Timer(const Duration(milliseconds: 500), () {
      exit(0);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      body: Consumer3<ConfigService, TrayService, IPCServer>(
        builder: (context, config, tray, ipc, child) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.settings_system_daydream,
                  size: 64,
                  color: Colors.blue[300],
                ),
                const SizedBox(height: 16),
                Text(
                  'CloudToLocalLLM Tray Service',
                  style: Theme.of(
                    context,
                  ).textTheme.headlineSmall?.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 8),
                Text(
                  'Running in background',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.grey[400]),
                ),
                const SizedBox(height: 24),
                _buildStatusCard('Tray Status', tray.status),
                const SizedBox(height: 8),
                _buildStatusCard('IPC Server', ipc.status),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => windowManager.hide(),
                  child: const Text('Hide to Tray'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusCard(String title, String status) {
    Color statusColor = Colors.grey;
    if (status.contains('Running') || status.contains('Connected')) {
      statusColor = Colors.green;
    } else if (status.contains('Error') || status.contains('Failed')) {
      statusColor = Colors.red;
    } else if (status.contains('Starting') || status.contains('Connecting')) {
      statusColor = Colors.orange;
    }

    return Card(
      color: Colors.grey[800],
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: statusColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text('$title: $status', style: TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
  }

  @override
  void onTrayIconMouseDown() {
    // Show context menu on left click
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayIconRightMouseDown() {
    // Show context menu on right click
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    final trayService = Provider.of<TrayService>(context, listen: false);
    trayService.handleMenuClick(menuItem.key ?? '');
  }

  @override
  void onWindowClose() async {
    // Hide to tray instead of closing
    await windowManager.hide();
  }
}
