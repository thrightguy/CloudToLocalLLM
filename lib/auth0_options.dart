/// Configuration for Auth0 authentication.
///
/// This class provides the necessary configuration parameters for connecting
/// to the Auth0 authentication service. These values should match the
/// settings configured in your Auth0 tenant dashboard.
class Auth0Options {
  /// The Auth0 domain (e.g., 'example.us.auth0.com')
  static const String domain = 'dev-xafu7oedkd5wlrbo.us.auth0.com';

  /// The Auth0 client ID for your application
  static const String clientId = 'HlOeY1pG9e2g6MvFKPDFbJ3ASIhxDgNu';

  /// The Auth0 client secret
  static const String clientSecret =
      '3VlOjLSbftdbL4RobOeLczBwvQc9p31IN191tD08QE7Dv4HL8pLjIO69jHu_Kn9x';

  /// The redirect URI for authentication callbacks
  /// For web applications, this should be registered in Auth0 dashboard
  static const String redirectUri =
      'https://app.cloudtolocalllm.online/callback';

  /// The audience (API identifier) for securing API requests
  /// Only required if you need to access a protected API
  static const String audience =
      'https://dev-xafu7oedkd5wlrbo.us.auth0.com/api/v2/';

  /// The scope of access being requested
  /// Common scopes include 'openid profile email'
  static const String scope = 'openid profile email';

  // Private constructor to prevent instantiation
  Auth0Options._();
}
