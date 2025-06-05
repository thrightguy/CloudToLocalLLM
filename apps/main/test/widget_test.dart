// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cloudtolocalllm_main/main.dart';

void main() {
  testWidgets('CloudToLocalLLM main app smoke test', (
    WidgetTester tester,
  ) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const CloudToLocalLLMMainApp());

    // Verify that our app loads correctly.
    expect(find.text('CloudToLocalLLM'), findsWidgets);
    expect(find.text('Your Personal AI Powerhouse'), findsOneWidget);
    expect(find.byIcon(Icons.chat), findsOneWidget);
  });
}
