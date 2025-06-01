// Platform stub for web environments where dart:io is not available
// This file provides a minimal Platform class interface for web compatibility

/// Stub Platform class for web environments
class Platform {
  static bool get isAndroid => false;
  static bool get isIOS => false;
  static bool get isWindows => false;
  static bool get isLinux => false;
  static bool get isMacOS => false;
  static bool get isFuchsia => false;
  
  static String get operatingSystem => 'web';
  static String get operatingSystemVersion => 'unknown';
  static String get localHostname => 'localhost';
  static Map<String, String> get environment => <String, String>{};
  static String get executable => '';
  static String get resolvedExecutable => '';
  static Uri get script => Uri();
  static List<String> get executableArguments => <String>[];
  static String? get packageConfig => null;
  static String get version => '';
  static int get numberOfProcessors => 1;
  static String get pathSeparator => '/';
  static String get localeName => 'en_US';
}
