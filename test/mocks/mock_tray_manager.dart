// Mock implementation for tray_manager plugin
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

class MockTrayManager extends Mock {
  Future<void> setIcon(String iconPath) async {
    // Mock implementation - do nothing
  }

  Future<void> setContextMenu(dynamic menu) async {
    // Mock implementation - do nothing
  }
}
