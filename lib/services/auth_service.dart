import 'package:flutter/foundation.dart'; // Required for kIsWeb
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:openid_client/openid_client.dart'; // Generic OpenID Client
import 'package:openid_client_io/openid_client_io.dart'; // IO-specific for Token Storage
import 'package:url_launcher/url_launcher.dart';
// import 'package:uuid/uuid.dart'; // Uuid is not used directly anymore with PKCE verifier

class AuthService {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  // final _uuid = const Uuid(); // Not strictly needed if openid_client generates state/nonce

  // Configuration
  static const String _issuerUrl = 'https://auth.cloudtolocalllm.online';
  static const String _clientId = '31ab784f-f74d-4764-abe1-29060075e5c3';
  static const String _clientSecret = '6DP4-nMxwPccJg-knfqXYRzlHL3hdeLifVvrIoKPMvw';
  static const String _redirectUriString = 'https://cloudtolocalllm.online/oauthredirect';
  static final Uri _redirectUri = Uri.parse(_redirectUriString);
  static const List<String> _scopes = ['openid', 'email', 'profile', 'offline_access'];

  // Secure Storage Keys
  static const String _idTokenKey = 'id_token';
  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _userInfoKey = 'user_info';
  static const String _codeVerifierKey = 'code_verifier'; // For PKCE

  Future<Issuer> _getIssuer() async {
    return await Issuer.discover(Uri.parse(_issuerUrl));
  }

  Future<Client> _getClient(Issuer issuer) async {
    // For web, clientSecret should not be used directly in the frontend.
    // However, openid_client requires it for token endpoint authentication if the client isn't public.
    // FusionAuth apps are typically 'confidential' by default.
    // If your FusionAuth app is 'public', you can omit clientSecret.
    // For PKCE, the client secret is still used at the token endpoint.
    return Client(issuer, _clientId, clientSecret: _clientSecret);
  }

  Future<bool> isLoggedIn() async {
    final accessToken = await _secureStorage.read(key: _accessTokenKey);
    // TODO: Add robust token expiration check and refresh logic.
    return accessToken != null;
  }

  // Initiates the login process by redirecting the user to the FusionAuth login page.
  Future<void> login() async {
    final issuer = await _getIssuer();
    final client = await _getClient(issuer);

    // Create a Credential instance for the authorization flow.
    // This setup is for initiating the flow.
    final authenticator = Authenticator.pkce(
      client,
      scopes: _scopes,
      redirectUri: _redirectUri,
      // urlLancher is not used directly here for web, browser handles redirect.
    );

    // Store the code verifier, it will be needed to exchange the authorization code.
    await _secureStorage.write(key: _codeVerifierKey, value: authenticator.codeVerifier);
    
    // Get the authorization URL
    final authUrl = await authenticator.authorize();

    // Redirect the browser to the authorization URL
    if (await canLaunchUrl(authUrl)) {
      // For web, `launchUrl` with `webOnlyWindowName: '_self'` will navigate in the current tab.
      await launchUrl(authUrl, webOnlyWindowName: '_self');
    } else {
      throw Exception('Could not launch \\'$authUrl\\'');
    }
  }

  // Handles the redirect from FusionAuth, exchanges the code for tokens, and stores them.
  Future<User?> handleRedirectAndLogin(Uri responseUri) async {
    final codeVerifier = await _secureStorage.read(key: _codeVerifierKey);
    if (codeVerifier == null) {
      print('Error: Code verifier not found. Login flow may be broken.');
      return null;
    }

    final issuer = await _getIssuer();
    final client = await _getClient(issuer);
    
    try {
      // Process the authentication response using the full response URI
      final credential = await client.processAuthenticationResponse(
        responseUri,
        codeVerifier,
      );

      // Clear the code verifier as it's a one-time use
      await _secureStorage.delete(key: _codeVerifierKey);

      if (credential.idToken != null) {
        await _secureStorage.write(key: _idTokenKey, value: credential.idToken.toString());
      }
      if (credential.accessToken != null) {
        await _secureStorage.write(key: _accessTokenKey, value: credential.accessToken);
      }
      if (credential.refreshToken != null) {
        await _secureStorage.write(key: _refreshTokenKey, value: credential.refreshToken);
      }
      
      final userInfo = await credential.getUserInfo();
      if (userInfo != null) {
        // Storing UserInfo as a JSON string for simplicity
        // You might want a more structured approach (e.g., dedicated class, proper JSON parsing)
        await _secureStorage.write(key: _userInfoKey, value: userInfo.toJson().toString()); 
        print('Logged in user: ${userInfo.name}');
        return userInfo;
      }
      return null; // Should ideally return the user object or similar
    } catch (e, s) {
      print('Error processing authentication response: $e');
      print('Stack trace: $s');
      // Clear the code verifier in case of error to prevent reuse issues
      await _secureStorage.delete(key: _codeVerifierKey);
      return null;
    }
  }

  Future<void> logout() async {
    final idTokenHint = await _secureStorage.read(key: _idTokenKey);
    
    await _secureStorage.delete(key: _idTokenKey);
    await _secureStorage.delete(key: _accessTokenKey);
    await _secureStorage.delete(key: _refreshTokenKey);
    await _secureStorage.delete(key: _userInfoKey);
    await _secureStorage.delete(key: _codeVerifierKey); // Also clear verifier on logout

    final issuer = await _getIssuer();
    final endSessionUri = issuer.endSessionEndpoint;

    if (endSessionUri != null) {
      final logoutUrl = endSessionUri.replace(queryParameters: {
        'id_token_hint': idTokenHint,
        'post_logout_redirect_uri': _redirectUriString, // Redirect back to app after logout
        'client_id': _clientId, // Required by some OIDC providers for logout
      });

      if (await canLaunchUrl(logoutUrl)) {
        await launchUrl(logoutUrl, webOnlyWindowName: '_self'); // Navigate in current tab for web
      } else {
        print('Could not launch logout URL: $logoutUrl');
      }
    }
    print('User logged out.');
  }

  Future<String?> getAccessToken() async {
    // TODO: Implement token refresh logic using refresh token if access token is expired.
    // This would involve checking expiry, then calling client.createCredential(refreshToken: storedRefreshToken).getTokenResponse()
    return await _secureStorage.read(key: _accessTokenKey);
  }

  Future<User?> getUserInfo() async {
    final accessToken = await getAccessToken();
    if (accessToken == null) return null;

    // Check if we have stored user info
    var userInfoString = await _secureStorage.read(key: _userInfoKey);
    if (userInfoString != null) {
      try {
        // Attempt to parse and return stored User object
        // Note: openid_client's User.fromJson might not be public or suitable for direct use.
        // You might need to manually reconstruct or use a simplified Map.
        // For now, this is a placeholder. A proper implementation would deserialize.
        print('Returning stored UserInfo: $userInfoString');
        // return User.fromJson(json.decode(userInfoString)); // This is conceptual
        // Since User.fromJson isn't directly available/easy, fetch if expired or for critical ops
      } catch (e) {
        print('Error parsing stored user info: $e. Fetching fresh.');
      }
    }
    
    // If not stored, or if you want to ensure it's fresh:
    try {
      final issuer = await _getIssuer();
      final client = await _getClient(issuer);
      final credential = client.createCredential(accessToken: accessToken);
      final user = await credential.getUserInfo();
      if (user != null) {
        await _secureStorage.write(key: _userInfoKey, value: user.toJson().toString());
      }
      return user;
    } catch (e) {
      print('Error fetching user info: $e');
      // Could be an expired token, needs refresh logic
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