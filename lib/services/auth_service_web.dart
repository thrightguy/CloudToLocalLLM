import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/user_model.dart';
import 'auth_logger.dart';

// Modern web imports using package:web
import 'package:web/web.dart' as web;

/// Web-specific authentication service using direct Auth0 redirect with JWT tokens
class AuthServiceWeb extends ChangeNotifier {
  final ValueNotifier<bool> _isAuthenticated = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _isLoading = ValueNotifier<bool>(false);
  UserModel? _currentUser;
  String? _accessToken;
  String? _idToken;
  DateTime? _tokenExpiry;

  // Login state tracking to prevent multiple simultaneous attempts
  bool _isLoginInProgress = false;
  DateTime? _lastLoginAttempt;

  // Getters
  ValueNotifier<bool> get isAuthenticated => _isAuthenticated;
  ValueNotifier<bool> get isLoading => _isLoading;
  UserModel? get currentUser => _currentUser;
  String? get accessToken => _accessToken;
  String? get idToken => _idToken;

  AuthServiceWeb() {
    AuthLogger.initialize();
    AuthLogger.info('AuthServiceWeb constructor called');
    _initialize();
  }

  /// Initialize authentication service
  Future<void> _initialize() async {
    AuthLogger.info('Web authentication service initializing');
    try {
      _isLoading.value = true;
      notifyListeners();
      AuthLogger.debug('Loading state set to true during initialization');

      // Check for existing authentication
      await _checkAuthenticationStatus();
      AuthLogger.info('Authentication service initialized successfully');
    } catch (e) {
      AuthLogger.error('Error initializing Auth0', {'error': e.toString()});
    } finally {
      _isLoading.value = false;
      notifyListeners();
      AuthLogger.debug('Loading state set to false after initialization');
    }
  }

  /// Check current authentication status and validate stored tokens
  Future<void> _checkAuthenticationStatus() async {
    try {
      AuthLogger.info('🔐 Checking authentication status');

      // Check if we're on the callback URL (web only)
      if (kIsWeb) {
        final currentUrl = web.window.location.href;
        if (currentUrl.contains('/callback')) {
          AuthLogger.info('🔐 Detected callback URL during initialization');
          await handleCallback();
          return;
        }
      }

      // Check for stored tokens
      await _loadStoredTokens();

      if (_accessToken != null) {
        // Validate token expiry
        if (_tokenExpiry != null && DateTime.now().isBefore(_tokenExpiry!)) {
          // Token is valid, load user profile
          await _loadUserProfile();
          _isAuthenticated.value = true;
          AuthLogger.info('🔐 Valid stored tokens found');
          notifyListeners();
          return;
        } else {
          // Token expired, clear stored data
          AuthLogger.info('🔐 Stored tokens expired, clearing');
          await _clearStoredTokens();
        }
      }

      // No valid authentication found
      _isAuthenticated.value = false;
      AuthLogger.info('🔐 No valid authentication found');
    } catch (e) {
      AuthLogger.error('🔐 Error checking authentication status', {
        'error': e.toString(),
      });
      _isAuthenticated.value = false;
      await _clearStoredTokens();
    }
  }

  /// Login using Auth0 redirect flow with enhanced protection against loops
  Future<void> login() async {
    // Add stack trace to identify what's calling login repeatedly
    final stackTrace = StackTrace.current;
    AuthLogger.info('🔐 Web login method called', {
      'stackTrace': stackTrace.toString().split('\n').take(5).join('\n'),
    });
    AuthLogger.logAuthStateChange(false, 'Login attempt started');

    // Prevent multiple simultaneous login attempts
    if (_isLoginInProgress) {
      AuthLogger.warning(
        '🔐 Login already in progress, ignoring duplicate call',
      );
      return;
    }

    // Prevent rapid successive login attempts (within 3 seconds)
    if (_lastLoginAttempt != null &&
        DateTime.now().difference(_lastLoginAttempt!).inSeconds < 3) {
      AuthLogger.warning(
        '🔐 Login attempted too soon after previous attempt, ignoring',
      );
      return;
    }

    // Check if already loading to prevent race conditions
    if (_isLoading.value) {
      AuthLogger.warning(
        '🔐 Authentication already in loading state, ignoring login call',
      );
      return;
    }

    try {
      _isLoginInProgress = true;
      _lastLoginAttempt = DateTime.now();
      _isLoading.value = true;
      notifyListeners();
      AuthLogger.debug(
        '🔐 Loading state set to true, login protection enabled',
      );

      // For web, redirect directly to Auth0 login page
      final redirectUri = AppConfig.auth0WebRedirectUri;
      final state = DateTime.now().millisecondsSinceEpoch.toString();

      AuthLogger.info('🔐 Building Auth0 URL', {
        'redirectUri': redirectUri,
        'state': state,
        'domain': AppConfig.auth0Domain,
        'clientId': AppConfig.auth0ClientId,
        'scopes': AppConfig.auth0Scopes,
      });

      final authUrl = Uri.https(AppConfig.auth0Domain, '/authorize', {
        'client_id': AppConfig.auth0ClientId,
        'redirect_uri': redirectUri,
        'response_type': 'code',
        'scope': AppConfig.auth0Scopes.join(' '),
        'state': state,
      });

      AuthLogger.info('🔐 Auth0 URL constructed', {
        'url': authUrl.toString(),
        'length': authUrl.toString().length,
      });

      // For web, redirect the current window to Auth0
      if (kIsWeb) {
        await _performRedirectToAuth0(authUrl.toString());
      } else {
        // For non-web platforms, this service shouldn't be used
        throw UnsupportedError(
          'Web authentication service is only supported on web platform',
        );
      }
    } catch (e) {
      AuthLogger.error('🔐 Login error', {
        'error': e.toString(),
        'errorType': e.runtimeType.toString(),
        'stackTrace': StackTrace.current.toString(),
      });
      _isAuthenticated.value = false;
      AuthLogger.logAuthStateChange(false, 'Login failed with error');
      rethrow;
    } finally {
      _isLoading.value = false;
      _isLoginInProgress = false;
      notifyListeners();
      AuthLogger.debug('🔐 Login method finally block executed');
    }
  }

  /// Perform redirect to Auth0 with multiple fallback methods
  Future<void> _performRedirectToAuth0(String authUrl) async {
    try {
      AuthLogger.info('🔐 Attempting window.location.href redirect');

      // Method 1: Use window.location.href (primary method)
      web.window.location.href = authUrl;
      AuthLogger.info('🔐 Redirect initiated with window.location.href');

      // Wait to check if redirect actually happened
      await Future.delayed(const Duration(milliseconds: 1000));

      // If we're still here after 1 second, the redirect might have failed
      AuthLogger.warning(
        '🔐 Still executing after redirect - checking if navigation occurred',
      );

      // Check if we're still on the same page
      final currentUrl = web.window.location.href;
      if (!currentUrl.contains('auth0.com')) {
        AuthLogger.error('🔐 Redirect failed - still on original page', {
          'currentUrl': currentUrl,
          'expectedDomain': 'auth0.com',
        });

        // Try alternative redirect methods
        await _attemptAlternativeRedirect(authUrl);
      } else {
        AuthLogger.info('🔐 Redirect successful - now on Auth0 domain');
      }
    } catch (redirectError) {
      AuthLogger.error('🔐 Primary redirect failed', {
        'error': redirectError.toString(),
        'errorType': redirectError.runtimeType.toString(),
      });

      // Try alternative redirect methods
      await _attemptAlternativeRedirect(authUrl);
    }
  }

  /// Attempt alternative redirect methods if primary method fails
  Future<void> _attemptAlternativeRedirect(String authUrl) async {
    AuthLogger.info('🔐 Attempting alternative redirect methods');

    try {
      // Method 1: window.open with _self
      AuthLogger.info('🔐 Trying window.open with _self');
      web.window.open(authUrl, '_self');

      // Wait to see if this worked
      await Future.delayed(const Duration(milliseconds: 500));

      // Check if redirect happened
      final currentUrl = web.window.location.href;
      if (!currentUrl.contains('auth0.com')) {
        // Method 2: Try multiple href assignments
        AuthLogger.info('🔐 Trying multiple location.href assignments');

        for (int i = 0; i < 3; i++) {
          web.window.location.href = authUrl;
          await Future.delayed(const Duration(milliseconds: 200));

          final checkUrl = web.window.location.href;
          if (checkUrl.contains('auth0.com')) {
            AuthLogger.info(
              '🔐 Multiple href assignment succeeded on attempt ${i + 1}',
            );
            return;
          }
        }

        // Final check - if we still haven't redirected, throw an error
        final finalUrl = web.window.location.href;
        if (!finalUrl.contains('auth0.com')) {
          AuthLogger.error('🔐 All redirect methods failed', {
            'finalUrl': finalUrl,
            'targetUrl': authUrl,
          });
          throw Exception(
            'Unable to redirect to Auth0 - all methods failed. This may be due to browser security restrictions, popup blockers, or CORS policies.',
          );
        }
      }

      AuthLogger.info('🔐 Alternative redirect method succeeded');
    } catch (fallbackError) {
      AuthLogger.error('🔐 All redirect methods failed', {
        'error': fallbackError.toString(),
        'errorType': fallbackError.runtimeType.toString(),
      });
      throw Exception(
        'All redirect methods failed: ${fallbackError.toString()}. Please check browser settings and disable popup blockers.',
      );
    }
  }

  /// Logout and clear all stored tokens
  Future<void> logout() async {
    try {
      _isLoading.value = true;
      notifyListeners();

      // Clear local state
      _currentUser = null;
      _accessToken = null;
      _idToken = null;
      _tokenExpiry = null;
      _isAuthenticated.value = false;

      // Clear stored tokens
      await _clearStoredTokens();

      AuthLogger.logAuthStateChange(false, 'User logged out');
    } catch (e) {
      AuthLogger.error('🔐 Logout error', {'error': e.toString()});
      rethrow;
    } finally {
      _isLoading.value = false;
      notifyListeners();
    }
  }

  /// Handle Auth0 callback
  Future<bool> handleCallback() async {
    try {
      AuthLogger.info('🔐 Web callback handling started');

      if (!kIsWeb) {
        AuthLogger.error(
          '🔐 Callback handling is only supported on web platform',
        );
        return false;
      }

      // Get current URL parameters
      final uri = Uri.parse(web.window.location.href);
      AuthLogger.info('🔐 Current URL', {
        'url': uri.toString(),
        'path': uri.path,
        'query': uri.query,
        'fragment': uri.fragment,
      });

      // Check for error parameters
      if (uri.queryParameters.containsKey('error')) {
        final error = uri.queryParameters['error'];
        final errorDescription = uri.queryParameters['error_description'];
        AuthLogger.error('🔐 Auth0 callback error', {
          'error': error,
          'error_description': errorDescription,
        });
        return false;
      }

      // Check for authorization code
      if (uri.queryParameters.containsKey('code')) {
        final code = uri.queryParameters['code'];
        final state = uri.queryParameters['state'];

        AuthLogger.info('🔐 Authorization code received', {
          'code': code != null ? '${code.substring(0, 10)}...' : 'null',
          'state': state,
        });

        if (code != null) {
          // Exchange authorization code for tokens
          final success = await _exchangeCodeForTokens(code);

          if (success) {
            try {
              // Load user profile with the new access token
              await _loadUserProfile();

              // Set authentication state and notify listeners
              _isAuthenticated.value = true;
              notifyListeners();
              AuthLogger.logAuthStateChange(
                true,
                'Token exchange and profile loading successful',
              );

              // Ensure state change has time to propagate through widget tree
              // This is critical to prevent race conditions with router redirect logic
              await Future.delayed(const Duration(milliseconds: 100));

              // Clear the URL parameters (web only) after state is set
              if (kIsWeb) {
                web.window.history.replaceState(null, '', '/');
              }

              // Additional delay to ensure all state updates are complete
              await Future.delayed(const Duration(milliseconds: 100));

              AuthLogger.info('🔐 Authentication completed successfully');
              return true;
            } catch (profileError) {
              AuthLogger.error(
                '🔐 Profile loading failed after successful token exchange',
                {'error': profileError.toString()},
              );

              // Clear tokens since profile loading failed
              await _clearStoredTokens();
              _isAuthenticated.value = false;
              notifyListeners();

              return false;
            }
          } else {
            AuthLogger.error('🔐 Token exchange failed');
            return false;
          }
        }
      }

      AuthLogger.warning('🔐 No authorization code or error in callback');
      return false;
    } catch (e) {
      AuthLogger.error('🔐 Callback handling error', {
        'error': e.toString(),
        'stackTrace': StackTrace.current.toString(),
      });
      return false;
    }
  }

  /// Exchange authorization code for access and ID tokens
  Future<bool> _exchangeCodeForTokens(String code) async {
    try {
      AuthLogger.info('🔐 Exchanging authorization code for tokens', {
        'codeLength': code.length,
        'redirectUri': AppConfig.auth0WebRedirectUri,
      });

      final response = await http.post(
        Uri.https(AppConfig.auth0Domain, '/oauth/token'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'grant_type': 'authorization_code',
          'client_id': AppConfig.auth0ClientId,
          'code': code,
          'redirect_uri': AppConfig.auth0WebRedirectUri,
        }),
      );

      AuthLogger.debug('🔐 Token exchange response received', {
        'statusCode': response.statusCode,
        'hasBody': response.body.isNotEmpty,
      });

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        _accessToken = data['access_token'] as String?;
        _idToken = data['id_token'] as String?;

        if (_accessToken == null) {
          AuthLogger.error('🔐 No access token in response', {
            'response': data,
          });
          return false;
        }

        // Calculate token expiry
        final expiresIn = data['expires_in'] as int? ?? 3600;
        _tokenExpiry = DateTime.now().add(Duration(seconds: expiresIn));

        // Store tokens securely
        await _storeTokens();

        AuthLogger.info('🔐 Tokens received and stored successfully', {
          'hasAccessToken': _accessToken != null,
          'hasIdToken': _idToken != null,
          'expiresIn': expiresIn,
        });
        return true;
      } else {
        AuthLogger.error('🔐 Token exchange failed', {
          'statusCode': response.statusCode,
          'body': response.body,
          'headers': response.headers,
        });
        return false;
      }
    } catch (e) {
      AuthLogger.error('🔐 Token exchange error', {
        'error': e.toString(),
        'errorType': e.runtimeType.toString(),
      });
      return false;
    }
  }

  /// Load user profile from Auth0 Management API
  Future<void> _loadUserProfile() async {
    try {
      if (_accessToken == null) {
        AuthLogger.warning('🔐 No access token available for profile loading');
        throw Exception('No access token available for profile loading');
      }

      AuthLogger.info('🔐 Loading user profile');

      final response = await http.get(
        Uri.https(AppConfig.auth0Domain, '/userinfo'),
        headers: {
          'Authorization': 'Bearer $_accessToken',
          'Content-Type': 'application/json',
        },
      );

      AuthLogger.debug('🔐 User profile response received', {
        'statusCode': response.statusCode,
        'hasBody': response.body.isNotEmpty,
      });

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Validate required fields
        final userId = data['sub'] as String?;
        if (userId == null || userId.isEmpty) {
          AuthLogger.error('🔐 Invalid user profile: missing user ID', {
            'response': data,
          });
          throw Exception('Invalid user profile: missing user ID');
        }

        _currentUser = UserModel(
          id: userId,
          email: data['email'] as String? ?? '',
          name: data['name'] as String? ?? '',
          picture: data['picture'] as String?,
          nickname: data['nickname'] as String?,
          emailVerified: data['email_verified'] == true ? DateTime.now() : null,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        AuthLogger.info('🔐 User profile loaded successfully', {
          'userId': _currentUser!.id,
          'email': _currentUser!.email,
          'name': _currentUser!.name,
        });
      } else {
        AuthLogger.error('🔐 Failed to load user profile', {
          'statusCode': response.statusCode,
          'body': response.body,
          'headers': response.headers,
        });
        throw Exception('Failed to load user profile: ${response.statusCode}');
      }
    } catch (e) {
      AuthLogger.error('🔐 User profile loading error', {
        'error': e.toString(),
        'errorType': e.runtimeType.toString(),
      });
      // Re-throw to ensure calling code knows profile loading failed
      rethrow;
    }
  }

  /// Store tokens in localStorage
  Future<void> _storeTokens() async {
    try {
      if (!kIsWeb) return;

      if (_accessToken != null) {
        web.window.localStorage.setItem(
          'cloudtolocalllm_access_token',
          _accessToken!,
        );
      }
      if (_idToken != null) {
        web.window.localStorage.setItem('cloudtolocalllm_id_token', _idToken!);
      }
      if (_tokenExpiry != null) {
        web.window.localStorage.setItem(
          'cloudtolocalllm_token_expiry',
          _tokenExpiry!.toIso8601String(),
        );
      }

      AuthLogger.info('🔐 Tokens stored in localStorage');
    } catch (e) {
      AuthLogger.error('🔐 Error storing tokens', {'error': e.toString()});
    }
  }

  /// Load tokens from localStorage
  Future<void> _loadStoredTokens() async {
    try {
      if (!kIsWeb) return;

      _accessToken = web.window.localStorage.getItem(
        'cloudtolocalllm_access_token',
      );
      _idToken = web.window.localStorage.getItem('cloudtolocalllm_id_token');

      final expiryString = web.window.localStorage.getItem(
        'cloudtolocalllm_token_expiry',
      );
      if (expiryString != null) {
        _tokenExpiry = DateTime.tryParse(expiryString);
      }

      if (_accessToken != null) {
        AuthLogger.info('🔐 Tokens loaded from localStorage');
      }
    } catch (e) {
      AuthLogger.error('🔐 Error loading stored tokens', {
        'error': e.toString(),
      });
    }
  }

  /// Clear stored tokens from localStorage
  Future<void> _clearStoredTokens() async {
    try {
      if (!kIsWeb) return;

      web.window.localStorage.removeItem('cloudtolocalllm_access_token');
      web.window.localStorage.removeItem('cloudtolocalllm_id_token');
      web.window.localStorage.removeItem('cloudtolocalllm_token_expiry');
      web.window.localStorage.removeItem(
        'cloudtolocalllm_authenticated',
      ); // Legacy cleanup

      AuthLogger.info('🔐 Stored tokens cleared');
    } catch (e) {
      AuthLogger.error('🔐 Error clearing stored tokens', {
        'error': e.toString(),
      });
    }
  }

  @override
  void dispose() {
    _isAuthenticated.dispose();
    _isLoading.dispose();
    super.dispose();
  }
}
