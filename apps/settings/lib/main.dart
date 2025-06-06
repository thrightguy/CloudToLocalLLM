import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import 'package:cloudtolocalllm_shared/version.dart';

import 'services/settings_service.dart';
import 'services/ollama_service.dart';
import 'services/ipc_client.dart';
import 'screens/settings_home.dart';
import 'config/theme.dart';
import 'config/router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize window manager for desktop
  await windowManager.ensureInitialized();

  // Configure window
  WindowOptions windowOptions = const WindowOptions(
    size: Size(800, 600),
    minimumSize: Size(600, 400),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.normal,
    title: 'CloudToLocalLLM Settings',
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(CloudToLocalLLMSettingsApp());
}

class CloudToLocalLLMSettingsApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsService()),
        ChangeNotifierProvider(create: (_) => OllamaService()),
        ChangeNotifierProvider(create: (_) => IPCClient()),
      ],
      child: MaterialApp.router(
        title: 'CloudToLocalLLM Settings',
        theme: SettingsTheme.darkTheme,
        routerConfig: SettingsRouter.router,
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

class SettingsAppInitializer extends StatefulWidget {
  final Widget child;

  const SettingsAppInitializer({Key? key, required this.child}) : super(key: key);

  @override
  _SettingsAppInitializerState createState() => _SettingsAppInitializerState();
}

class _SettingsAppInitializerState extends State<SettingsAppInitializer> 
    with WindowListener {
  
  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _initializeServices();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  Future<void> _initializeServices() async {
    try {
      final settingsService = Provider.of<SettingsService>(context, listen: false);
      final ollamaService = Provider.of<OllamaService>(context, listen: false);
      final ipcClient = Provider.of<IPCClient>(context, listen: false);

      // Initialize settings service
      await settingsService.initialize();

      // Initialize Ollama service
      await ollamaService.initialize();

      // Try to connect to tray service
      await ipcClient.connectToTray();

      debugPrint('Settings app services initialized successfully');
    } catch (e) {
      debugPrint('Failed to initialize settings services: $e');
      // Show error dialog if needed
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Initialization Error'),
            content: Text('Failed to initialize settings services:\n$e'),
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

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }

  @override
  void onWindowClose() async {
    // Graceful shutdown
    final settingsService = Provider.of<SettingsService>(context, listen: false);
    final ollamaService = Provider.of<OllamaService>(context, listen: false);
    final ipcClient = Provider.of<IPCClient>(context, listen: false);

    await ipcClient.disconnect();
    await ollamaService.dispose();
    await settingsService.dispose();

    await windowManager.destroy();
  }

  @override
  void onWindowMinimize() {
    // Hide to system tray if tray service is available
    final ipcClient = Provider.of<IPCClient>(context, listen: false);
    if (ipcClient.isConnected) {
      windowManager.hide();
    }
  }
}
