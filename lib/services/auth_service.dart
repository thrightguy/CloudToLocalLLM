import 'dart:async';
import 'package:flutter/foundation.dart'; // Required for kIsWeb
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert' as convert; // Added for JSON decoding
import 'package:firebase_auth/firebase_auth.dart';

// Import the main library with an alias for common types like Issuer, Client, Credential, UserInfo
import 'package:openid_client/openid_client.dart' as openid;

// Import platform-specific libraries for Authenticator
import 'package:openid_client/openid_client_browser.dart' as openid_browser;
// For non-web, we'll need openid_client_io.dart if direct instantiation is used.
// The openid_client package itself uses conditional exports to handle this normally.
// If we directly use openid_io.Authenticator, we need to import it.
import 'package:openid_client/openid_client_io.dart' as openid_io; 

import 'package:url_launcher/url_launcher.dart';
// import 'package:uuid/uuid.dart'; // Uuid is not used directly anymore with PKCE verifier

// import 'package:openid_client/openid_client.dart' 
//   show generateRandomCodeVerifier, calculateS256CodeChallenge, ResponseType, CodeChallengeMethod;

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  // final _uuid = const Uuid(); // Not strictly needed if openid_client generates state/nonce

  // Configuration
  static const String _issuerUrl = 'https://auth.cloudtolocalllm.online';
  static const String _clientId = '31ab784f-f74d-4764-abe1-29060075e5c3';
  static const String _clientSecret = '6DP4-nMxwPccJg-knfqXYRzlHL3hdeLifVvrIoKPMvw'; // Used for confidential client
  
  // Using the original public redirect URI
  static const String _redirectUriString = 'https://cloudtolocalllm.online/oauthredirect';
  // static final Uri _redirectUri = Uri.parse(_redirectUriString); // Authenticator takes string

  static const List<String> _scopes = ['openid', 'email', 'profile', 'offline_access'];

  // Secure Storage Keys
  static const String _idTokenKey = 'id_token';
  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _userInfoKey = 'user_info';
  // static const String _codeVerifierKey = 'pkce_code_verifier'; // For manual PKCE - REMOVED

  // Observable for authentication state
  final ValueNotifier<bool> isAuthenticated = ValueNotifier<bool>(false);
  
  AuthService() {
    // Listen to Firebase auth state changes and update isAuthenticated
    _auth.authStateChanges().listen((User? user) {
      isAuthenticated.value = user != null;
    });
  }

  // Initialize the service
  Future<void> initialize() async {
    // Check if user is already logged in
    final currentUser = _auth.currentUser;
    isAuthenticated.value = currentUser != null;
  }

  // Email/Password Sign In
  Future<UserCredential?> signInWithEmailAndPassword(String email, String password) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Store tokens if needed for API calls
      if (userCredential.user != null) {
        final idToken = await userCredential.user!.getIdToken();
        await _secureStorage.write(key: _idTokenKey, value: idToken);
        // You can also store other info if needed
      }
      
      return userCredential;
    } catch (e) {
      debugPrint('Error signing in: $e');
      return null;
    }
  }

  // Email/Password Sign Up
  Future<UserCredential?> createUserWithEmailAndPassword(String email, String password) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      if (userCredential.user != null) {
        final idToken = await userCredential.user!.getIdToken();
        await _secureStorage.write(key: _idTokenKey, value: idToken);
      }
      
      return userCredential;
    } catch (e) {
      debugPrint('Error creating user: $e');
      return null;
    }
  }

  Future<openid.Issuer> _getIssuer() async {
    return await openid.Issuer.discover(Uri.parse(_issuerUrl));
  }

  // _getClient might still be useful for operations outside of Authenticator's direct flow,
  // like token revocation or other direct client interactions if needed later.
  // For now, let's assume Authenticator handles what we need for login/token exchange.
  // Future<openid.Client> _getClient(openid.Issuer issuer) async {
  //   return openid.Client(issuer, _clientId, clientSecret: _clientSecret);
  // }

  // Use 'dynamic' for Authenticator return type initially, as the concrete type depends on platform.
  // The actual interface they implement is AuthenticatorIFace, but direct instantiation is shown in examples.
  Future<dynamic> _getAuthenticator() async {
    final issuer = await _getIssuer();
    final client = openid.Client(issuer, _clientId, clientSecret: _clientSecret);

    if (kIsWeb) {
      // For openid_client_browser.Authenticator, redirectUri and urlLancher are not typically set in constructor.
      // authorize() handles the redirect using the redirect_uri registered with the OIDC provider.
      return openid_browser.Authenticator(
        client,
        scopes: _scopes,
        // redirectUri: Uri.parse(_redirectUriString), // Removed, not a constructor param here
        // urlLancher: _launchUrl, // Removed, not a constructor param here
      );
    } else {
      // Assuming openid_io.Authenticator is the correct class for non-web
      // and its constructor accepts these parameters as per common patterns or IO needs.
      return openid_io.Authenticator(
        client,
        scopes: _scopes,
        port: 4000,
        redirectUri: Uri.parse(_redirectUriString), 
        urlLancher: _launchUrl, // Parameter name based on previous error/examples
      );
    }
  }

  Future<bool> isLoggedIn() async {
    return _auth.currentUser != null;
  }

  // URL Launcher helper
  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, webOnlyWindowName: '_self');
    } else {
      throw Exception('Could not launch $url');
    }
  }

  // Initiates the login process by redirecting to the auth server
  Future<void> login() async {
    // This would be replaced with Firebase social auth methods 
    // when you're ready to add Google/Microsoft login
    debugPrint('OIDC login not implemented yet. Use signInWithEmailAndPassword instead.');
  }

  // Handles the redirect from the auth server, exchanges code for tokens
  Future<User?> handleRedirectAndLogin(Uri responseUri) async {
    // This will be implemented when you add social logins
    // For now, just return current user to maintain backward compatibility
    return _auth.currentUser;
  }

  // Sign Out
  Future<void> logout() async {
    try {
      await _auth.signOut();
      
      // Clean up stored tokens
      await _secureStorage.delete(key: _idTokenKey);
      await _secureStorage.delete(key: _accessTokenKey);
      await _secureStorage.delete(key: _refreshTokenKey);
      await _secureStorage.delete(key: _userInfoKey);
    } catch (e) {
      debugPrint('Error signing out: $e');
    }
  }

  // Get current user
  User? get currentUser => _auth.currentUser;

  // For backward compatibility with your older code
  // Validate the current token (no need with Firebase, it handles token refresh)
  Future<bool> validateToken() async {
    return _auth.currentUser != null;
  }

  // Login with token (for backward compatibility)
  Future<void> loginWithToken(String token) async {
    // With Firebase, you'd typically use a different method
    // but we'll keep this for backward compatibility with your existing code
    await _secureStorage.write(key: _idTokenKey, value: token);
  }

  Future<String?> getAccessToken() async {
    return await _secureStorage.read(key: _accessTokenKey);
  }

  Future<openid.UserInfo?> getUserInfo() async {
    final accessToken = await getAccessToken();
    if (accessToken == null) {
      // print('No access token found, cannot get user info.');
      return null;
    }

    var userInfoString = await _secureStorage.read(key: _userInfoKey);
    if (userInfoString != null) {
      try {
        // Try to parse and return if structure is as expected
        final decoded = convert.json.decode(userInfoString); // Use convert.json.decode
        // We need to ensure the UserInfo object can make calls if it needs to lazy-load claims.
        // For now, assume fromJson is sufficient if all data is in userInfoString.
        return openid.UserInfo.fromJson(decoded);
      } catch (e) {
        // print('Error parsing stored user info: $e. Fetching fresh.');
      }
    }
    
    // print('Fetching fresh user info...');
    try {
      final issuer = await _getIssuer();
      // We need a client to get user info from an existing access token.
      final client = openid.Client(issuer, _clientId, clientSecret: _clientSecret);
      
      // Create a Credential object with the stored access token and associate the client.
      final credential = client.createCredential(accessToken: accessToken);
      // Alternatively, if fromJson is preferred and client association is manual:
      // final credential = openid.Credential.fromJson({'access_token': accessToken});
      // credential.client = client; // This was an error point before, let's rely on createCredential.
      
      final userInfo = await credential.getUserInfo(); // UserInfo from Credential
      await _secureStorage.write(key: _userInfoKey, value: userInfo.toJson().toString());
      // print('Fetched user info: ${userInfo.name}');
      return userInfo;
    } catch (e) {
      // print('Error fetching user info: $e');
      return null;
    }
  }
}

// Placeholder for deep link handling (this would be in your main app logic or a handler)
// Future<void> handleRedirect(Uri uri) async {
//   if (uri.toString().startsWith(AuthService._redirectUriString)) {
//     // Extract parameters and complete the login flow
//     // final responseParams = uri.queryParameters;
//     // This is where you would call something like:
//     // authenticator.grant.handleAuthorizationResponse(responseParams);
//     // And then exchange for tokens
//   }
// } 