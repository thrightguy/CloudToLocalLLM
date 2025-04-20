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
import 'services/ollama_service.dart';
import 'services/storage_service.dart';
import 'services/tunnel_service.dart';
import 'screens/home_screen.dart';

void main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize storage service
  final storageService = StorageService();
  await storageService.initialize();

  // Initialize other services
  final authService = AuthService();
  final tunnelService = TunnelService(authService: authService);
  final cloudService = CloudService(authService: authService);

  // Get the saved settings to determine the LLM provider
  final prefs = await SharedPreferences.getInstance();
  final settingsJson = prefs.getString(AppConfig.settingsStorageKey);
  final settings = settingsJson != null ? Map<String, dynamic>.from(jsonDecode(settingsJson)) : <String, dynamic>{};
  final llmProvider = settings['llmProvider'] as String? ?? AppConfig.defaultLlmProvider;

  // Initialize OllamaService with the appropriate base URL based on the provider
  final ollamaService = OllamaService(
    baseUrl: llmProvider == 'lmstudio' ? AppConfig.lmStudioBaseUrl : AppConfig.ollamaBaseUrl
  );

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
            ollamaService: ollamaService,
          ),
        ),
        ChangeNotifierProxyProvider<SettingsProvider, LlmProvider>(
          create: (context) => LlmProvider(
            ollamaService: ollamaService,
            storageService: storageService,
          ),
          update: (context, settingsProvider, llmProvider) {
            if (llmProvider != null) {
              // Refresh models when the LLM provider changes
              if (settingsProvider.llmProvider != llmProvider.currentProvider) {
                // Set the current provider
                llmProvider.setCurrentProvider(settingsProvider.llmProvider);
                // Refresh models
                llmProvider.refreshModels();
              }
              return llmProvider;
            }
            return LlmProvider(
              ollamaService: ollamaService,
              storageService: storageService,
            );
          },
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
