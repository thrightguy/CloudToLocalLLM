import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage_x/flutter_secure_storage_x.dart';
import 'auth_service.dart';
import 'desktop_client_detection_service.dart';

/// Service to manage setup wizard state and first-time user detection
///
/// This service tracks:
/// - Whether the user has completed the setup wizard
/// - Whether the user is logging in for the first time
/// - When to show the setup wizard based on connection state
class SetupWizardService extends ChangeNotifier {
  static const String _setupCompletedKey = 'cloudtolocalllm_setup_completed';
  static const String _userSeenWizardKey = 'cloudtolocalllm_user_seen_wizard';

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final AuthService _authService;
  final DesktopClientDetectionService? _clientDetectionService;

  // State
  bool _isSetupCompleted = false;
  bool _hasUserSeenWizard = false;
  bool _shouldShowWizard = false;
  bool _isFirstTimeUser = false;
  bool _isInitialized = false;

  SetupWizardService({
    required AuthService authService,
    DesktopClientDetectionService? clientDetectionService,
  }) : _authService = authService,
       _clientDetectionService = clientDetectionService {
    _initialize();
  }

  // Getters
  bool get isSetupCompleted => _isSetupCompleted;
  bool get hasUserSeenWizard => _hasUserSeenWizard;
  bool get shouldShowWizard => _shouldShowWizard;
  bool get isFirstTimeUser => _isFirstTimeUser;
  bool get isInitialized => _isInitialized;

  /// Initialize the service and check setup state
  Future<void> _initialize() async {
    if (!kIsWeb) {
      _isInitialized = true;
      return;
    }

    debugPrint('🧙 [SetupWizard] Initializing setup wizard service...');

    try {
      // Load stored setup state
      await _loadSetupState();

      // Listen to authentication changes
      _authService.addListener(_onAuthStateChanged);

      // Listen to client detection changes if available
      _clientDetectionService?.addListener(_onClientDetectionChanged);

      // Check initial state
      await _checkShouldShowWizard();

      _isInitialized = true;
      debugPrint('🧙 [SetupWizard] Setup wizard service initialized');
      notifyListeners();
    } catch (e) {
      debugPrint(
        '🧙 [SetupWizard] Error initializing setup wizard service: $e',
      );
      _isInitialized = true;
      notifyListeners();
    }
  }

  /// Load setup state from secure storage
  Future<void> _loadSetupState() async {
    try {
      final setupCompleted = await _secureStorage.read(key: _setupCompletedKey);
      final userSeenWizard = await _secureStorage.read(key: _userSeenWizardKey);

      _isSetupCompleted = setupCompleted == 'true';
      _hasUserSeenWizard = userSeenWizard == 'true';

      debugPrint(
        '🧙 [SetupWizard] Loaded setup state: completed=$_isSetupCompleted, seen=$_hasUserSeenWizard',
      );
    } catch (e) {
      debugPrint('🧙 [SetupWizard] Error loading setup state: $e');
      _isSetupCompleted = false;
      _hasUserSeenWizard = false;
    }
  }

  /// Save setup state to secure storage
  Future<void> _saveSetupState() async {
    try {
      await _secureStorage.write(
        key: _setupCompletedKey,
        value: _isSetupCompleted.toString(),
      );
      await _secureStorage.write(
        key: _userSeenWizardKey,
        value: _hasUserSeenWizard.toString(),
      );
      debugPrint(
        '🧙 [SetupWizard] Saved setup state: completed=$_isSetupCompleted, seen=$_hasUserSeenWizard',
      );
    } catch (e) {
      debugPrint('🧙 [SetupWizard] Error saving setup state: $e');
    }
  }

  /// Handle authentication state changes
  void _onAuthStateChanged() {
    debugPrint(
      '🧙 [SetupWizard] Auth state changed: ${_authService.isAuthenticated.value}',
    );

    if (_authService.isAuthenticated.value) {
      // User just logged in, check if they're a first-time user
      _checkIfFirstTimeUser();
      _checkShouldShowWizard();
    } else {
      // User logged out, reset wizard state
      _shouldShowWizard = false;
      _isFirstTimeUser = false;
      notifyListeners();
    }
  }

  /// Handle client detection changes
  void _onClientDetectionChanged() {
    debugPrint(
      '🧙 [SetupWizard] Client detection changed: ${_clientDetectionService?.hasConnectedClients}',
    );
    _checkShouldShowWizard();
  }

  /// Check if the user is logging in for the first time
  void _checkIfFirstTimeUser() {
    // For now, we'll consider a user first-time if they haven't seen the wizard
    // In a real implementation, you might check Auth0 metadata or user creation date
    _isFirstTimeUser = !_hasUserSeenWizard;

    // Additional check: if user is authenticated and we haven't loaded their state yet
    if (_authService.isAuthenticated.value && !_hasUserSeenWizard) {
      // This could be enhanced to check Auth0 user metadata for actual first login
      // For example: user.metadata?.firstLogin or user.createdAt comparison
      _isFirstTimeUser = true;
    }

    debugPrint(
      '🧙 [SetupWizard] First time user: $_isFirstTimeUser (hasSeenWizard: $_hasUserSeenWizard)',
    );
  }

  /// Check if the setup wizard should be shown
  Future<void> _checkShouldShowWizard() async {
    if (!kIsWeb || !_authService.isAuthenticated.value) {
      _shouldShowWizard = false;
      notifyListeners();
      return;
    }

    final hasConnectedClients =
        _clientDetectionService?.hasConnectedClients ?? false;

    // Show wizard only if:
    // 1. User is first-time AND hasn't seen the wizard yet
    // Don't show wizard just because no clients are connected - that's handled by DesktopClientPrompt
    final shouldShow = _isFirstTimeUser && !_hasUserSeenWizard;

    if (_shouldShowWizard != shouldShow) {
      _shouldShowWizard = shouldShow;
      debugPrint(
        '🧙 [SetupWizard] Should show wizard: $_shouldShowWizard (firstTime: $_isFirstTimeUser, hasSeenWizard: $_hasUserSeenWizard, hasClients: $hasConnectedClients, completed: $_isSetupCompleted)',
      );
      notifyListeners();
    }
  }

  /// Mark the wizard as seen by the user
  Future<void> markWizardSeen() async {
    if (!_hasUserSeenWizard) {
      _hasUserSeenWizard = true;
      await _saveSetupState();
      debugPrint('🧙 [SetupWizard] Marked wizard as seen');
      notifyListeners();
    }
  }

  /// Mark the setup as completed
  Future<void> markSetupCompleted() async {
    _isSetupCompleted = true;
    _hasUserSeenWizard = true;
    _shouldShowWizard = false;
    await _saveSetupState();
    debugPrint('🧙 [SetupWizard] Marked setup as completed');
    notifyListeners();
  }

  /// Reset the setup state (for testing or re-onboarding)
  Future<void> resetSetupState() async {
    _isSetupCompleted = false;
    _hasUserSeenWizard = false;
    _shouldShowWizard = false;
    _isFirstTimeUser = false;
    await _saveSetupState();
    debugPrint('🧙 [SetupWizard] Reset setup state');
    notifyListeners();
  }

  /// Force show the wizard (for manual access from settings)
  void showWizard() {
    _shouldShowWizard = true;
    debugPrint('🧙 [SetupWizard] Manually showing wizard');
    notifyListeners();
  }

  /// Hide the wizard
  void hideWizard() {
    _shouldShowWizard = false;
    debugPrint('🧙 [SetupWizard] Hiding wizard');
    notifyListeners();
  }

  /// Check if the wizard should be accessible from settings
  bool get canAccessFromSettings {
    return kIsWeb && _authService.isAuthenticated.value;
  }

  /// Show the wizard from settings (always show, regardless of completion status)
  void showWizardFromSettings() {
    _shouldShowWizard = true;
    debugPrint('🧙 [SetupWizard] Showing wizard from settings');
    notifyListeners();
  }

  /// Get setup progress information
  Map<String, dynamic> getSetupProgress() {
    final hasConnectedClients =
        _clientDetectionService?.hasConnectedClients ?? false;

    return {
      'isSetupCompleted': _isSetupCompleted,
      'hasUserSeenWizard': _hasUserSeenWizard,
      'shouldShowWizard': _shouldShowWizard,
      'isFirstTimeUser': _isFirstTimeUser,
      'hasConnectedClients': hasConnectedClients,
      'isAuthenticated': _authService.isAuthenticated.value,
      'connectedClientCount':
          _clientDetectionService?.connectedClientCount ?? 0,
    };
  }

  @override
  void dispose() {
    _authService.removeListener(_onAuthStateChanged);
    _clientDetectionService?.removeListener(_onClientDetectionChanged);
    super.dispose();
  }
}
