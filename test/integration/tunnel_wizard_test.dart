import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:cloudtolocalllm/main.dart' as app;
import 'package:cloudtolocalllm/services/auth_service.dart';
import 'package:cloudtolocalllm/services/tunnel_manager_service.dart';
import 'package:cloudtolocalllm/components/tunnel_connection_wizard.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Tunnel Connection Wizard Integration Tests', () {
    testWidgets('Complete tunnel wizard workflow', (WidgetTester tester) async {
      // Start the app
      app.main();
      await tester.pumpAndSettle();

      // Navigate to settings
      await tester.tap(find.byIcon(Icons.settings));
      await tester.pumpAndSettle();

      // Navigate to tunnel connection settings
      await tester.tap(find.text('Tunnel Connection'));
      await tester.pumpAndSettle();

      // Find and tap the tunnel wizard button
      await tester.tap(find.text('Launch Tunnel Wizard'));
      await tester.pumpAndSettle();

      // Verify wizard dialog is shown
      expect(find.text('Tunnel Connection Setup'), findsOneWidget);
      expect(find.text('Authentication'), findsOneWidget);

      // Test authentication step
      expect(find.text('Authentication Required'), findsOneWidget);
      expect(find.text('Login'), findsOneWidget);

      // Note: We can't actually test the full authentication flow in integration tests
      // without real credentials, but we can verify the UI components are present

      // Test server selection step navigation
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      // Should still be on authentication step since not authenticated
      expect(find.text('Authentication'), findsOneWidget);

      // Test cancel functionality
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      // Verify wizard is closed
      expect(find.text('Tunnel Connection Setup'), findsNothing);
    });

    testWidgets('Tunnel wizard UI components validation', (WidgetTester tester) async {
      // Create a test widget with the wizard
      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider<AuthService>(
                create: (_) => AuthService(),
              ),
              ChangeNotifierProvider<TunnelManagerService>(
                create: (_) => TunnelManagerService(),
              ),
            ],
            child: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => const TunnelConnectionWizard(),
                    );
                  },
                  child: const Text('Show Wizard'),
                ),
              ),
            ),
          ),
        ),
      );

      // Open the wizard
      await tester.tap(find.text('Show Wizard'));
      await tester.pumpAndSettle();

      // Verify wizard components
      expect(find.text('Tunnel Connection Setup'), findsOneWidget);
      expect(find.text('Configure your CloudToLocalLLM tunnel connection'), findsOneWidget);

      // Verify step indicators
      expect(find.text('Authentication'), findsOneWidget);
      expect(find.text('Server Selection'), findsOneWidget);
      expect(find.text('Connection Testing'), findsOneWidget);
      expect(find.text('Configuration Save'), findsOneWidget);

      // Verify step icons
      expect(find.byIcon(Icons.login), findsOneWidget);
      expect(find.byIcon(Icons.dns), findsOneWidget);
      expect(find.byIcon(Icons.network_check), findsOneWidget);
      expect(find.byIcon(Icons.save), findsOneWidget);

      // Verify navigation buttons
      expect(find.text('Next'), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);

      // Verify authentication step content
      expect(find.text('Authentication Required'), findsOneWidget);
      expect(find.text('Please authenticate with your CloudToLocalLLM account to continue.'), findsOneWidget);
      expect(find.text('Login'), findsOneWidget);
    });

    testWidgets('Enhanced authentication service validation', (WidgetTester tester) async {
      // Create a test widget with auth service
      late AuthService authService;
      
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<AuthService>(
            create: (_) {
              authService = AuthService();
              return authService;
            },
            child: Consumer<AuthService>(
              builder: (context, auth, child) {
                return Scaffold(
                  body: Column(
                    children: [
                      Text('Authenticated: ${auth.isAuthenticated.value}'),
                      Text('Loading: ${auth.isLoading.value}'),
                      Text('Validating: ${auth.isValidatingToken}'),
                      ElevatedButton(
                        onPressed: () async {
                          await auth.validateAuthentication();
                        },
                        child: const Text('Validate Auth'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify initial state
      expect(find.text('Authenticated: false'), findsOneWidget);
      expect(find.text('Loading: false'), findsOneWidget);
      expect(find.text('Validating: false'), findsOneWidget);

      // Test validation method exists and can be called
      await tester.tap(find.text('Validate Auth'));
      await tester.pump(); // Don't wait for settle as this might be async

      // Verify the enhanced methods are available
      expect(authService.isValidatingToken, isA<bool>());
      expect(authService.lastTokenValidation, isA<DateTime?>());
    });

    testWidgets('Tunnel manager wizard integration validation', (WidgetTester tester) async {
      // Create a test widget with tunnel manager
      late TunnelManagerService tunnelManager;
      
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<TunnelManagerService>(
            create: (_) {
              tunnelManager = TunnelManagerService();
              return tunnelManager;
            },
            child: Consumer<TunnelManagerService>(
              builder: (context, tunnel, child) {
                return Scaffold(
                  body: Column(
                    children: [
                      Text('Connected: ${tunnel.isConnected}'),
                      Text('Connecting: ${tunnel.isConnecting}'),
                      ElevatedButton(
                        onPressed: () async {
                          tunnel.enableWizardMode();
                        },
                        child: const Text('Enable Wizard Mode'),
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          final diagnostics = tunnel.getConnectionDiagnostics();
                          print('Diagnostics: $diagnostics');
                        },
                        child: const Text('Get Diagnostics'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Test wizard mode functionality
      await tester.tap(find.text('Enable Wizard Mode'));
      await tester.pumpAndSettle();

      // Test diagnostics functionality
      await tester.tap(find.text('Get Diagnostics'));
      await tester.pumpAndSettle();

      // Verify enhanced methods are available
      final wizardStatus = tunnelManager.getWizardStatus();
      expect(wizardStatus, isA<Map<String, dynamic>>());
      expect(wizardStatus['isWizardMode'], isA<bool>());

      final diagnostics = tunnelManager.getConnectionDiagnostics();
      expect(diagnostics, isA<Map<String, dynamic>>());
      expect(diagnostics['platform'], isA<String>());
      expect(diagnostics['config'], isA<Map<String, dynamic>>());
    });
  });
}
