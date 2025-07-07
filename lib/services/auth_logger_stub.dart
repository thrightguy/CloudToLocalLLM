// Stub implementation for non-web platforms
// This file provides empty implementations for web-specific functionality

class Window {
  Navigator get navigator => Navigator();
  Location get location => Location();
  Storage get localStorage => Storage();
  History get history => History();
  void open(String url, String target) {}
}

class Navigator {
  String get userAgent => 'desktop-app';
}

class Location {
  String get href => 'desktop-app';
  set href(String value) {}
}

class Storage {
  void removeItem(String key) {}
  String? getItem(String key) => null;
  void setItem(String key, String value) {}
}

class History {
  void replaceState(dynamic data, String title, String url) {}
}

class Document {
  Element createElement(String tagName) => Element();
}

class Element {
  void setAttribute(String name, String value) {}
  void click() {}
}

// Global instances
final window = Window();
final document = Document();
