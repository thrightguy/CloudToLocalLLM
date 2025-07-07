// Web-specific implementation using dart:html
import 'dart:html' as html;

class Window {
  Navigator get navigator => Navigator();
  Location get location => Location();
  Storage get localStorage => Storage();
  History get history => History();
  void open(String url, String target) => html.window.open(url, target);
}

class Navigator {
  String get userAgent => html.window.navigator.userAgent;
}

class Location {
  String get href => html.window.location.href;
  set href(String value) => html.window.location.href = value;
}

class Storage {
  void removeItem(String key) => html.window.localStorage.remove(key);
  String? getItem(String key) => html.window.localStorage[key];
  void setItem(String key, String value) =>
      html.window.localStorage[key] = value;
}

class History {
  void replaceState(dynamic data, String title, String url) =>
      html.window.history.replaceState(data, title, url);
}

class Document {
  Element createElement(String tagName) =>
      Element(html.document.createElement(tagName));
}

class Element {
  final html.Element _element;
  Element(this._element);

  void setAttribute(String name, String value) =>
      _element.setAttribute(name, value);
  void click() {
    // Use click method directly
    _element.click();
  }
}

// Global instances
final window = Window();
final document = Document();
