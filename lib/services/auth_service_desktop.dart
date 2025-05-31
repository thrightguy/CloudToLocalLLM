import 'package:flutter/foundation.dart';
import 'package:openid_client/openid_client_io.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/app_config.dart';
import '../models/user_model.dart';

/// Desktop-specific authentication service using OpenID Connect
class AuthServiceDesktop extends ChangeNotifier {
  // OpenID Connect client and credentials
  Client? _client;
  Credential? _credential;
  Issuer? _issuer;

  final ValueNotifier<bool> _isAuthenticated = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _isLoading = ValueNotifier<bool>(false);
  UserModel? _currentUser;

  // Getters
  ValueNotifier<bool> get isAuthenticated => _isAuthenticated;
  ValueNotifier<bool> get isLoading => _isLoading;
  UserModel? get currentUser => _currentUser;
  Credential? get credential => _credential;

  AuthServiceDesktop() {
    _initialize();
  }

  /// Initialize OpenID Connect client with Auth0
  Future<void> _initialize() async {
    try {
      _isLoading.value = true;
      notifyListeners();

      // Discover Auth0 issuer
      _issuer = await Issuer.discover(Uri.parse(AppConfig.auth0Issuer));

      // Create client
      _client = Client(_issuer!, AppConfig.auth0ClientId);

      // Check for existing authentication
      await _checkAuthenticationStatus();
    } catch (e) {
      debugPrint('Error initializing Auth0: $e');
    } finally {
      _isLoading.value = false;
      notifyListeners();
    }
  }

  /// Check current authentication status
  Future<void> _checkAuthenticationStatus() async {
    try {
      // For now, we'll implement a simple check
      // In a production app, you'd check for stored tokens
      _isAuthenticated.value = false;
    } catch (e) {
      debugPrint('Error checking authentication status: $e');
      _isAuthenticated.value = false;
    }
  }

  /// Login using Authorization Code Flow with PKCE
  Future<void> login() async {
    if (_client == null) {
      throw Exception('Auth client not initialized');
    }

    try {
      _isLoading.value = true;
      notifyListeners();

      final authenticator = Authenticator(
        _client!,
        scopes: AppConfig.auth0Scopes,
        port: 3025,
        urlLancher: (url) async {
          debugPrint('Launching auth URL: $url');
          if (await canLaunchUrl(Uri.parse(url))) {
            await launchUrl(
              Uri.parse(url),
              mode: LaunchMode.externalApplication,
            );
          } else {
            throw 'Could not launch $url';
          }
        },
      );

      _credential = await authenticator.authorize();

      if (_credential != null) {
        await _loadUserProfile();
        _isAuthenticated.value = true;
      }
    } catch (e) {
      debugPrint('Login error: $e');
      _isAuthenticated.value = false;
      rethrow;
    } finally {
      _isLoading.value = false;
      notifyListeners();
    }
  }

  /// Logout
  Future<void> logout() async {
    try {
      _isLoading.value = true;
      notifyListeners();

      // Clear local state
      _credential = null;
      _currentUser = null;
      _isAuthenticated.value = false;
    } catch (e) {
      debugPrint('Logout error: $e');
      rethrow;
    } finally {
      _isLoading.value = false;
      notifyListeners();
    }
  }

  /// Load user profile from OpenID Connect token
  Future<void> _loadUserProfile() async {
    try {
      if (_credential?.idToken != null) {
        final idToken = _credential!.idToken;
        final claims = idToken.claims;

        // Create user model from token claims
        _currentUser = UserModel(
          id: claims['sub'] as String? ?? '',
          email: claims['email'] as String? ?? '',
          name: claims['name'] as String? ?? '',
          picture: claims['picture'] as String?,
          nickname: claims['nickname'] as String?,
          emailVerified: (claims['email_verified'] as bool? ?? false)
              ? DateTime.now()
              : null,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
      }
    } catch (e) {
      debugPrint('Error loading user profile: $e');
    }
  }

  /// Handle Auth0 callback
  Future<bool> handleCallback() async {
    try {
      // Desktop apps redirect to web callback, then close browser
      // and return to the application with authentication state
      debugPrint('Desktop callback handling - checking authentication state');

      // Give some time for the authentication flow to complete
      await Future.delayed(const Duration(seconds: 2));

      // Check if we have valid credentials
      if (_credential != null) {
        await _loadUserProfile();
        _isAuthenticated.value = true;
        notifyListeners();
        return true;
      }

      return _isAuthenticated.value;
    } catch (e) {
      debugPrint('Callback handling error: $e');
      return false;
    }
  }

  @override
  void dispose() {
    _isAuthenticated.dispose();
    _isLoading.dispose();
    super.dispose();
  }
}
