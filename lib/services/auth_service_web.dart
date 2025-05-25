// Web-specific implementation for auth service
import 'package:web/web.dart' as web;

class PlatformAuth {
  // Web-specific methods
  static void handleWebCallback() {
    // Handle web-specific callback logic
    final urlParams = web.window.location.search;
    if (urlParams.contains('code=') && urlParams.contains('state=')) {
      // Process Auth0 callback
      final url = Uri.parse(web.window.location.href);
      final code = url.queryParameters['code'];
      final state = url.queryParameters['state'];
      
      if (code != null && state != null) {
        // Store in session storage for processing
        web.window.sessionStorage.setItem('auth0_code', code);
        web.window.sessionStorage.setItem('auth0_state', state);
        
        // Clean up URL
        web.window.history.replaceState(null, '', '/');
      }
    }
  }
  
  static bool isWebPlatform() {
    return true;
  }
  
  static String? getWebRedirectUri() {
    return web.window.location.origin + '/callback';
  }
}
