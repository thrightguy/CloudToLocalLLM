# Authentication Architecture

## Overview

CloudToLocalLLM uses a comprehensive, platform-aware authentication system that automatically selects the appropriate authentication method based on the target platform. This architecture supports web, desktop, and mobile platforms with a unified API.

## Architecture Components

### 1. Main Auth Service (`lib/services/auth_service.dart`)
The primary interface that applications interact with. It automatically delegates to platform-specific implementations.

**Features:**
- ✅ Unified API across all platforms
- ✅ Automatic platform detection
- ✅ Consistent authentication state management
- ✅ Platform capability detection

### 2. Platform Detection Service (`lib/services/auth_service_platform.dart`)
Intelligent platform detection and service factory that creates the appropriate authentication service.

**Platform Detection:**
- **Web**: `kIsWeb == true`
- **Mobile**: `Platform.isAndroid || Platform.isIOS`
- **Desktop**: `Platform.isWindows || Platform.isLinux || Platform.isMacOS`

### 3. Platform-Specific Services

#### Web Authentication (`lib/services/auth_service_web.dart`)
- **Method**: Direct Auth0 redirect flow
- **Callback**: `https://app.cloudtolocalllm.online/callback`
- **Features**: Browser-based authentication, no local server required
- **Security**: PKCE flow, state parameter validation

#### Mobile Authentication (`lib/services/auth_service_mobile.dart`)
- **Method**: Auth0 Flutter SDK with Universal Login
- **Callback**: Custom URL scheme (`app://callback`)
- **Features**: 
  - Native iOS/Android authentication
  - Biometric authentication support
  - Secure credential storage (Keychain/Keystore)
  - Automatic token refresh
  - Deep linking support

#### Desktop Authentication (`lib/services/auth_service_desktop.dart`)
- **Method**: OpenID Connect with PKCE
- **Callback**: Local server on port 3025
- **Features**: 
  - Cross-platform compatibility (Windows/Linux/macOS)
  - Local callback server
  - Secure token storage
  - External browser authentication

## Platform Capabilities

| Feature | Web | Mobile | Desktop |
|---------|-----|--------|---------|
| Basic Authentication | ✅ | ✅ | ✅ |
| Biometric Auth | ❌ | ✅ | ❌ |
| Secure Storage | ❌ | ✅ | ✅ |
| Deep Linking | ❌ | ✅ | ✅ |
| Token Refresh | Manual | Automatic | Manual |
| Offline Support | ❌ | ✅ | ✅ |

## Authentication Flow

### Web Flow
1. User clicks "Sign In"
2. Redirect to Auth0 Universal Login
3. User authenticates with Auth0
4. Auth0 redirects to `https://app.cloudtolocalllm.online/callback`
5. Application processes callback and establishes session

### Mobile Flow
1. User clicks "Sign In"
2. Auth0 Flutter SDK opens native browser/in-app browser
3. User authenticates with Auth0
4. Auth0 redirects to `app://callback`
5. Deep link returns to application
6. SDK processes tokens and stores securely
7. Optional: Enable biometric authentication for future logins

### Desktop Flow
1. User clicks "Sign In"
2. Local server starts on port 3025
3. External browser opens Auth0 login
4. User authenticates with Auth0
5. Auth0 redirects to `http://localhost:3025/callback`
6. Local server receives callback and processes tokens
7. Browser can be closed, application continues

## Usage Examples

### Basic Authentication
```dart
final authService = AuthService();

// Login (platform-specific method automatically selected)
await authService.login();

// Check authentication status
if (authService.isAuthenticated.value) {
  final user = authService.currentUser;
  print('Welcome ${user?.name}!');
}

// Logout
await authService.logout();
```

### Mobile-Specific Features
```dart
// Check if biometric authentication is available
if (await authService.isBiometricAvailable()) {
  // Login with biometrics
  await authService.loginWithBiometrics();
}

// Refresh token (mobile only, automatic)
await authService.refreshTokenIfNeeded();
```

### Platform Detection
```dart
final authService = AuthService();

// Check platform capabilities
print('Platform: ${authService.getPlatformInfo()['platform']}');
print('Supports biometrics: ${authService.supportsBiometrics}');
print('Supports deep linking: ${authService.supportsDeepLinking}');
print('Recommended auth method: ${authService.recommendedAuthMethod}');
```

## Configuration

### Auth0 Configuration (`lib/config/app_config.dart`)
```dart
class AppConfig {
  // Auth0 Configuration
  static const String auth0Domain = 'dev-xafu7oedkd5wlrbo.us.auth0.com';
  static const String auth0ClientId = 'ESfES9tnQ4qGxFlwzXpDuRVXCyk0KF29';
  static const String auth0Audience = 'https://api.cloudtolocalllm.online';
  
  // Platform-specific redirect URIs
  static const String auth0WebRedirectUri = 'https://app.cloudtolocalllm.online/callback';
  static const String auth0DesktopRedirectUri = 'http://localhost:3025/';
  
  // OAuth2 Scopes
  static const List<String> auth0Scopes = ['openid', 'profile', 'email'];
}
```

## Future Enhancements

### Planned Features
- [ ] Social login providers (Google, GitHub, etc.)
- [ ] Multi-factor authentication (MFA)
- [ ] Single Sign-On (SSO) support
- [ ] Enterprise authentication (SAML, LDAP)
- [ ] Passwordless authentication
- [ ] Session management and refresh
- [ ] Offline authentication caching

### Mobile Enhancements
- [ ] Face ID / Touch ID integration
- [ ] Push notification authentication
- [ ] Device registration and management
- [ ] Jailbreak/root detection
- [ ] Certificate pinning

### Security Features
- [ ] Advanced threat protection
- [ ] Anomaly detection
- [ ] Geolocation-based security
- [ ] Device fingerprinting
- [ ] Session timeout management

## Troubleshooting

### Common Issues

1. **Web: "Could not launch Auth0 login URL"**
   - Check network connectivity
   - Verify Auth0 domain configuration
   - Ensure popup blockers are disabled

2. **Mobile: "Deep link not working"**
   - Verify URL scheme configuration in `android/app/src/main/AndroidManifest.xml`
   - Check iOS URL scheme in `ios/Runner/Info.plist`
   - Ensure Auth0 callback URL matches app configuration

3. **Desktop: "Port 3025 already in use"**
   - Check if another application is using the port
   - Modify port configuration if needed
   - Ensure firewall allows local connections

### Debug Information
Use `authService.getPlatformInfo()` to get comprehensive debugging information about the current platform and authentication state.
