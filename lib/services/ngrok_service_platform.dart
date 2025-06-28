// Platform-specific ngrok service factory using conditional imports
// This file automatically imports the correct platform implementation

// Conditional imports - Dart will choose the right one at compile time
export 'ngrok_service_platform_web.dart' // Default for web
    if (dart.library.io) 'ngrok_service_platform_io.dart'; // For mobile/desktop
