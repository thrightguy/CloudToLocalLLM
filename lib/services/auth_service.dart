import 'dart:async';
import 'package:flutter/foundation.dart'; // Required for kIsWeb
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert' as convert; // Added for JSON decoding

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
    final accessToken = await _secureStorage.read(key: _accessTokenKey);
    // Add robust token expiration check and refresh logic.
    return accessToken != null;
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
    final authenticator = await _getAuthenticator();
    
    // For web, authorize redirects the current window.
    // For mobile/desktop, authorize spawns a browser window and listens on a local port.
    if (kIsWeb) {
      // For web, we might use `authorize` which expects a full page redirect,
      // or `authorizeInteractive` if it's available and suitable.
      // `openid_client_browser.authenticate` or `openid_browser.Authenticator` might be more direct.
      // Let's stick to the general Authenticator and see its behavior.
      // It will call the urlLancher.
      await authenticator.authorize(); // This should use the _launchUrl we provided
    } else {
      // For non-web, authorizeInteractive usually opens a browser and listens on redirectUri's port
      // The `redirectUri` for non-web should be localhost with a port.
      // Our current _redirectUriString is a public one. This needs adjustment for non-web.
      // For simplicity, let's assume the current _redirectUriString is handled by _launchUrl opening a browser,
      // and the app will capture the redirect via deep linking.
      // This part is tricky with a single redirect URI.
      // The Authenticator's `urlLancher` param is key here.
      await authenticator.authorize(); // Should trigger _launchUrl
    }
  }

  // Handles the redirect from the auth server, exchanges code for tokens
  Future<openid.UserInfo?> handleRedirectAndLogin(Uri responseUri) async {
    // With Authenticator, the response is typically handled by its internal listener if not on web,
    // or by processing the response if on web.
    // `handleAuthorizationResponse` is the method.

    // We no longer need to read codeVerifier from storage, Authenticator manages it.
    // final codeVerifier = await _secureStorage.read(key: _codeVerifierKey);
    // if (codeVerifier == null) {
    //   // print('Error: PKCE Code verifier not found in storage.');
    //   return null;
    // }

    // The `responseUri` contains the full redirect URI with code or error.
    // The Authenticator needs the query parameters.
    final authenticator = await _getAuthenticator(); // Returns AuthenticatorIFace
    
    try {
      // This method processes the response, extracts the code, and exchanges it for tokens.
      // handleAuthorizationResponse is part of AuthenticatorIFace
      final credential = await authenticator.handleAuthorizationResponse(responseUri.queryParameters);

      // await _secureStorage.delete(key: _codeVerifierKey); // No longer needed

      if (credential.idToken != null) {
        await _secureStorage.write(key: _idTokenKey, value: credential.idToken!.toString());
      }
      if (credential.accessToken != null) {
        await _secureStorage.write(key: _accessTokenKey, value: credential.accessToken);
      }
      if (credential.refreshToken != null) {
        await _secureStorage.write(key: _refreshTokenKey, value: credential.refreshToken);
      }
      
      // UserInfo from Credential, ensuring client is associated if needed by underlying implementation
      // The authenticator should return a credential with the client already associated.
      final userInfo = await credential.getUserInfo();
      if (userInfo != null) {
        await _secureStorage.write(key: _userInfoKey, value: userInfo.toJson().toString());
        // print('Logged in user: ${userInfo.name}');
        return userInfo;
      }
      return null;
    } catch (e) {
      // print('Error exchanging authorization code or fetching user info: $e');
      // await _secureStorage.delete(key: _codeVerifierKey); // No longer needed
      return null;
    }
  }

  Future<void> logout() async {
    final idTokenHint = await _secureStorage.read(key: _idTokenKey);
    
    await _secureStorage.delete(key: _idTokenKey);
    await _secureStorage.delete(key: _accessTokenKey);
    await _secureStorage.delete(key: _refreshTokenKey);
    await _secureStorage.delete(key: _userInfoKey);
    // await _secureStorage.delete(key: _codeVerifierKey); // Clear verifier on logout too - REMOVED

    final issuer = await _getIssuer();
    final postLogoutRedirectUri = Uri.parse('https://cloudtolocalllm.online/loggedout'); 
    final endSessionUri = issuer.metadata.endSessionEndpoint;

    if (endSessionUri != null) {
      final Map<String, String?> queryParameters = {
        'id_token_hint': idTokenHint,
        'post_logout_redirect_uri': postLogoutRedirectUri.toString(),
        'client_id': _clientId,
      };
      // Remove null values from queryParameters
      queryParameters.removeWhere((key, value) => value == null);

      final logoutUrl = endSessionUri.replace(queryParameters: queryParameters.cast<String, String>());


      if (await canLaunchUrl(logoutUrl)) {
        await launchUrl(logoutUrl, webOnlyWindowName: '_self');
      } else {
        // print('Could not launch logout URL: $logoutUrl');
      }
    }
    // print('User logged out attempt initiated.');
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