import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import 'package:cloudtolocalllm_shared/version.dart';

import 'services/tunnel_service.dart';
import 'services/api_server_service.dart';
import 'services/health_monitor_service.dart';
import 'services/config_service.dart';
import 'ui/tunnel_dashboard.dart';
import 'ui/tunnel_settings.dart';

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
    title: 'CloudToLocalLLM Tunnel Manager',
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  // Check version compatibility
  final compatibilityReport =
      await VersionCompatibility.getCompatibilityReport();
  if (!compatibilityReport['shared_library_compatible']) {
    debugPrint('WARNING: Shared library version incompatible');
  }

  runApp(const TunnelManagerApp());
}

class TunnelManagerApp extends StatelessWidget {
  const TunnelManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ConfigService()),
        ChangeNotifierProvider(create: (_) => TunnelService()),
        ChangeNotifierProvider(create: (_) => ApiServerService()),
        ChangeNotifierProvider(create: (_) => HealthMonitorService()),
      ],
      child: MaterialApp(
        title: 'CloudToLocalLLM Tunnel Manager',
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF6366F1),
            brightness: Brightness.dark,
          ),
          scaffoldBackgroundColor: const Color(0xFF0F172A),
          cardTheme: const CardThemeData(
            color: Color(0xFF1E293B),
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
          ),
        ),
        home: const TunnelManagerHome(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

class TunnelManagerHome extends StatefulWidget {
  const TunnelManagerHome({super.key});

  @override
  State<TunnelManagerHome> createState() => _TunnelManagerHomeState();
}

class _TunnelManagerHomeState extends State<TunnelManagerHome>
    with WindowListener {
  int _selectedIndex = 0;

  final List<Widget> _pages = [TunnelDashboard(), TunnelSettings()];

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
    final configService = Provider.of<ConfigService>(context, listen: false);
    final tunnelService = Provider.of<TunnelService>(context, listen: false);
    final apiServerService = Provider.of<ApiServerService>(
      context,
      listen: false,
    );
    final healthMonitorService = Provider.of<HealthMonitorService>(
      context,
      listen: false,
    );

    try {
      // Initialize configuration
      await configService.initialize();

      // Initialize tunnel service
      await tunnelService.initialize(configService.config);

      // Start API server
      await apiServerService.start(configService.config.apiServerPort);

      // Start health monitoring
      await healthMonitorService.start(tunnelService);

      debugPrint('Tunnel Manager services initialized successfully');
    } catch (e) {
      debugPrint('Failed to initialize services: $e');
      // Show error dialog
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Initialization Error'),
            content: Text('Failed to initialize tunnel manager services:\n$e'),
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
  void onWindowMinimize() {
    // Hide to system tray if configured
    final configService = Provider.of<ConfigService>(context, listen: false);
    if (configService.config.minimizeToTray) {
      windowManager.hide();
    }
  }

  @override
  void onWindowRestore() {
    // Window restored from minimized state
  }

  @override
  void onWindowClose() async {
    // Graceful shutdown
    final tunnelService = Provider.of<TunnelService>(context, listen: false);
    final apiServerService = Provider.of<ApiServerService>(
      context,
      listen: false,
    );
    final healthMonitorService = Provider.of<HealthMonitorService>(
      context,
      listen: false,
    );

    await healthMonitorService.stop();
    await apiServerService.stop();
    await tunnelService.shutdown();

    await windowManager.destroy();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.vpn_lock, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            const Text('Tunnel Manager'),
            const Spacer(),
            Consumer<TunnelService>(
              builder: (context, tunnelService, child) {
                return Row(
                  children: [
                    Icon(
                      tunnelService.isConnected
                          ? Icons.check_circle
                          : Icons.error,
                      color: tunnelService.isConnected
                          ? Colors.green
                          : Colors.red,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      tunnelService.isConnected ? 'Connected' : 'Disconnected',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                );
              },
            ),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            labelType: NavigationRailLabelType.all,
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.dashboard),
                label: Text('Dashboard'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.settings),
                label: Text('Settings'),
              ),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(child: _pages[_selectedIndex]),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'v${CloudToLocalLLMVersions.tunnelManagerVersion}+${CloudToLocalLLMVersions.tunnelManagerBuildNumber}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            Consumer<ApiServerService>(
              builder: (context, apiService, child) {
                return Text(
                  'API: ${apiService.isRunning ? "localhost:${apiService.port}" : "Stopped"}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: apiService.isRunning ? Colors.green : Colors.red,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
