// Web-specific implementation using package:web
import 'package:web/web.dart' as web;

class Window {
  Navigator get navigator => Navigator();
  Location get location => Location();
  Storage get localStorage => Storage();
  History get history => History();
  void open(String url, String target) => web.window.open(url, target);
}

class Navigator {
  String get userAgent => web.window.navigator.userAgent;
}

class Location {
  String get href => web.window.location.href;
  set href(String value) => web.window.location.href = value;
}

class Storage {
  void removeItem(String key) => web.window.localStorage.removeItem(key);
  String? getItem(String key) => web.window.localStorage.getItem(key);
  void setItem(String key, String value) =>
      web.window.localStorage.setItem(key, value);
}

class History {
  void replaceState(dynamic data, String title, String url) =>
      web.window.history.replaceState(data, title, url);
}

class Document {
  Element createElement(String tagName) =>
      Element(web.document.createElement(tagName));
}

class Element {
  final web.Element _element;
  Element(this._element);

  void setAttribute(String name, String value) =>
      _element.setAttribute(name, value);
  void click() {
    // Use click method directly - cast to HTMLElement for click support
    (_element as web.HTMLElement).click();
  }
}

// Global instances
final window = Window();
final document = Document();
