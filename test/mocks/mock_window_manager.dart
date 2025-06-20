// Mock implementation for window_manager plugin
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

class MockWindowManager extends Mock {
  Future<void> ensureInitialized() async {
    // Mock implementation - do nothing
  }

  Future<void> show() async {
    // Mock implementation - do nothing
  }

  Future<void> hide() async {
    // Mock implementation - do nothing
  }
}
