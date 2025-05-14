import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';
import 'config/app_config.dart';
import 'config/theme.dart';
import 'providers/auth_provider.dart';
import 'providers/llm_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/onboarding_provider.dart';
import 'services/local_auth_service.dart';
import 'services/cloud_service.dart';
import 'services/ollama_service.dart';
import 'services/storage_service.dart';
import 'services/tunnel_service.dart';
import 'services/windows_service.dart';
import 'services/api_service.dart';
import 'services/backend_service.dart';
import 'services/license_service.dart';
import 'screens/home_screen.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

void main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize window manager
  if (Platform.isWindows || Platform.isLinux) {
    await windowManager.ensureInitialized();
    WindowOptions windowOptions = const WindowOptions(
      size: Size(1280, 720),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.normal,
    );
    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  // Initialize storage service
  final storageService = StorageService();
  await storageService.initialize();

  // Initialize Windows service if on Windows
  final windowsService = Platform.isWindows ? WindowsService() : null;
  if (windowsService != null) {
    await windowsService.initialize();
  }

  // Initialize other services
  final authService = LocalAuthService();
  final tunnelService = TunnelService(
    authService: authService,
    windowsService: windowsService,
  );

  // Set up bidirectional connection between WindowsService and TunnelService
  if (windowsService != null) {
    windowsService.setTunnelService(tunnelService);
  }

  final cloudService = CloudService(authService: authService);

  // Get the saved settings to determine the LLM provider
  final prefs = await SharedPreferences.getInstance();
  final settingsJson = prefs.getString(AppConfig.settingsStorageKey);
  final settings = settingsJson != null
      ? Map<String, dynamic>.from(jsonDecode(settingsJson))
      : <String, dynamic>{};
  final llmProvider =
      settings['llmProvider'] as String? ?? AppConfig.defaultLlmProvider;

  // Initialize OllamaService with the appropriate base URL based on the provider
  final ollamaService = OllamaService(
      baseUrl: llmProvider == 'lmstudio'
          ? AppConfig.lmStudioBaseUrl
          : AppConfig.ollamaBaseUrl);

  // Start Ollama if it's not running and we're on Windows
  if (Platform.isWindows && windowsService != null) {
    if (!windowsService.isOllamaRunning.value) {
      // Try to start Ollama
      windowsService.startOllama();
    }
  }

  // Set up provider dependencies
  final settingsProvider = SettingsProvider(
    storageService: storageService,
    tunnelService: tunnelService,
    ollamaService: ollamaService,
    windowsService: windowsService,
  );
  await settingsProvider.initialize();

  final authProvider = AuthProvider(
    authService: authService,
    cloudService: CloudService(authService: authService),
    storageService: StorageService(),
  );
  await authProvider.initialize();

  final licenseService = LicenseService(
    secureStorage: const FlutterSecureStorage(),
    httpClient: http.Client(),
  );

  // Run the app
  runApp(
    MultiProvider(
      providers: [
        // Services
        Provider<StorageService>.value(value: storageService),
        Provider<OllamaService>.value(value: ollamaService),
        Provider<LocalAuthService>.value(value: authService),
        Provider<TunnelService>.value(value: tunnelService),
        Provider<CloudService>.value(value: cloudService),
        Provider<BackendService>(
          create: (context) => BackendService(authService: authService),
        ),
        Provider<ApiService>(
          create: (context) => ApiService(
            backendService: Provider.of<BackendService>(context, listen: false),
          ),
        ),
        if (windowsService != null)
          Provider<WindowsService>.value(value: windowsService),

        // Providers
        ChangeNotifierProvider(create: (_) => settingsProvider),
        ChangeNotifierProvider(create: (_) => authProvider),
        ChangeNotifierProvider(
          create: (_) => LlmProvider(
            ollamaService: ollamaService,
            storageService: storageService,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => OnboardingProvider(
            apiService: ApiService(
              backendService: BackendService(authService: authService),
            ),
            authProvider: authProvider,
          ),
        ),
        Provider(create: (_) => licenseService),
      ],
      child: const CloudToLocalLlmApp(),
    ),
  );
}

class CloudToLocalLlmApp extends StatefulWidget {
  const CloudToLocalLlmApp({super.key});

  @override
  State<CloudToLocalLlmApp> createState() => _CloudToLocalLlmAppState();
}

class _CloudToLocalLlmAppState extends State<CloudToLocalLlmApp> {
  @override
  void initState() {
    super.initState();

    // Initialize providers
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeProviders();
    });
  }

  Future<void> _initializeProviders() async {
    if (!mounted) return;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final settingsProvider =
        Provider.of<SettingsProvider>(context, listen: false);

    await authProvider.initialize();
    if (!mounted) return;

    await settingsProvider.initialize();
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);

    return MaterialApp(
      title: 'CloudToLocalLLM Portal',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: settingsProvider.themeMode,
      home: const HomeScreen(),
    );
  }
}
