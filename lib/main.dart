import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'config/app_config.dart';
import 'config/theme.dart';
import 'providers/auth_provider.dart';
import 'providers/llm_provider.dart';
import 'providers/settings_provider.dart';
import 'services/auth_service.dart';
import 'services/cloud_service.dart';
import 'services/installation_service.dart';
import 'services/ollama_service.dart';
import 'services/storage_service.dart';
import 'services/tunnel_service.dart';
import 'screens/home_screen.dart';

void main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize services
  final storageService = StorageService();
  await storageService.initialize();

  final ollamaService = OllamaService();
  final authService = AuthService();
  final tunnelService = TunnelService(authService: authService);
  final cloudService = CloudService(authService: authService);
  final installationService = InstallationService();

  // Run the app
  runApp(
    MultiProvider(
      providers: [
        // Services
        Provider<StorageService>.value(value: storageService),
        Provider<OllamaService>.value(value: ollamaService),
        Provider<AuthService>.value(value: authService),
        Provider<TunnelService>.value(value: tunnelService),
        Provider<CloudService>.value(value: cloudService),
        Provider<InstallationService>.value(value: installationService),

        // Providers
        ChangeNotifierProvider(
          create: (context) => AuthProvider(
            authService: authService,
            cloudService: cloudService,
            storageService: storageService,
          ),
        ),
        ChangeNotifierProvider(
          create: (context) => SettingsProvider(
            storageService: storageService,
            tunnelService: tunnelService,
          ),
        ),
        ChangeNotifierProvider(
          create: (context) => LlmProvider(
            ollamaService: ollamaService,
            storageService: storageService,
            installationService: installationService,
          ),
        ),
      ],
      child: const CloudToLocalLlmApp(),
    ),
  );
}

class CloudToLocalLlmApp extends StatefulWidget {
  const CloudToLocalLlmApp({Key? key}) : super(key: key);

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
    // Initialize auth provider
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.initialize();

    // Initialize settings provider
    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
    await settingsProvider.initialize();

    // Initialize LLM provider
    final llmProvider = Provider.of<LlmProvider>(context, listen: false);
    await llmProvider.initialize();
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);

    return MaterialApp(
      title: 'CloudToLocalLLM',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: settingsProvider.themeMode,
      home: const HomeScreen(),
    );
  }
}
