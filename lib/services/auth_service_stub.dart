// Stub implementation for non-web platforms
// This file provides empty implementations for web-specific functionality

class PlatformAuth {
  // Stub methods that do nothing on non-web platforms
  static void handleWebCallback() {
    // No-op for non-web platforms
  }
  
  static bool isWebPlatform() {
    return false;
  }
  
  static String? getWebRedirectUri() {
    return null;
  }
}
