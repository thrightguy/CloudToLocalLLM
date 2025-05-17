import 'dart:async';
import 'package:flutter/foundation.dart'; // Required for kIsWeb
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// Import the entire library with an alias
import 'package:openid_client/openid_client.dart' as openid;

// For kIsWeb and other Flutter-specific functionalities.
// For browser-specific functionalities if needed for Authenticator
import 'package:openid_client/openid_client_browser.dart' as openid_browser;

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


  // Initialize Authenticator
  Future<openid.Authenticator> _getAuthenticator() async {
    final issuer = await _getIssuer();
    // For web, we use openid_browser.createAuthenticator, for others, openid.Authenticator
    // However, openid.Authenticator should pick the correct flow based on platform.
    // Let's try with the generic one first and see if it requires platform-specific instantiation.
    // The openid_client usually uses conditional imports for dart:io vs dart:html.
    
    // The openid_client 0.4.9 `Authenticator` constructor directly takes issuer, clientId, scopes, and redirectUri.
    // It will create its own client internally.
    // Client secret is not directly passed to Authenticator for public clients (which is typical for mobile/SPA).
    // If our client is confidential and needs the secret for the token exchange part of the auth code flow,
    // this needs to be handled carefully. The `openid_client`'s `Authenticator` is more geared towards public clients.
    // Let's assume for now the PKCE flow doesn't need client_secret for the browser part.
    // If token endpoint requires client_secret, then the `Authenticator` might need a custom `Future<openid.Client> clientGetter()`
    // that provides a pre-configured client.

    // Simpler approach: openid_client may handle this if clientSecret is provided to its internal client.
    // Let's try creating a client and passing it if Authenticator supports it.
    // openid.Authenticator does not directly take a client or clientSecret in its constructor.
    // It's designed for flows where client secret is not used in the browser (public clients)
    // or where the platform specific implementation (like openid_client_io) handles it.

    // For PKCE, the client secret is typically NOT used in the authorization request
    // but IS used at the token endpoint.
    // The `Authenticator` might need a custom `openid.Client` if the default one it creates
    // doesn't include the client secret for the token exchange.

    // Let's try providing a client getter.
    Future<openid.Client> clientFactory() async {
      return openid.Client(issuer, _clientId, clientSecret: _clientSecret);
    }

    return openid.Authenticator(
      clientFactory, // Pass the factory
      redirectUri: Uri.parse(_redirectUriString),
      scopes: _scopes,
      port: kIsWeb ? null : 4000, // Port for local web server on non-web, null for web as redirect is direct
      urlLancher: _launchUrl, // Use our existing url_launcher
    );
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
    final authenticator = await _getAuthenticator();
    
    try {
      // This method processes the response, extracts the code, and exchanges it for tokens.
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
      
      // UserInfo might be directly available from credential or fetched
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
        final decoded = openid.json.decode(userInfoString); // Use openid.json.decode
        return openid.UserInfo.fromJson(decoded); // Assuming UserInfo has fromJson
      } catch (e) {
        // print('Error parsing stored user info: $e. Fetching fresh.');
      }
    }
    
    // print('Fetching fresh user info...');
    try {
      final issuer = await _getIssuer();
      // We need a client to get user info from an existing access token.
      // The Authenticator is for the auth flow, not necessarily for this.
      // So, _getClient is still useful.
      final client = openid.Client(issuer, _clientId, clientSecret: _clientSecret); // Re-instantiate client here
      
      // Create a credential object with the stored access token.
      // The `openid_client` typically has a way to do this.
      // `credential.getUserInfo()` is usually called on a credential obtained after auth.
      // To get UserInfo from just an access token, we might need client.getUserInfo(accessToken)
      // or construct a credential manually.

      // openid.Credential.fromAccessToken(client, accessToken) or similar.
      // Looking at openid_client, Client itself has a `getUserInfo` method if you have an Credential.
      // A simple Credential can be created:
      final credential = openid.Credential.fromJson({
        'access_token': accessToken,
        // Other token parts like id_token, refresh_token can be added if available and needed
        // but for getUserInfo, accessToken is primary.
      });
      
      // Attach the client to the credential for it to make calls
      credential.client = client;

      final userInfo = await credential.getUserInfo();
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