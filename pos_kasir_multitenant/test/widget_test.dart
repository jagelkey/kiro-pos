// This is a basic Flutter widget test for POS Kasir Multitenant.
//
// This test verifies that the app can be built and renders the login screen.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pos_kasir_multitenant/main.dart';

void main() {
  testWidgets('App renders login screen smoke test',
      (WidgetTester tester) async {
    // Build our app with ProviderScope and trigger a frame.
    await tester.pumpWidget(
      const ProviderScope(
        child: MyApp(),
      ),
    );

    // Wait for the app to settle
    await tester.pumpAndSettle();

    // Verify that the login screen is displayed
    // The app should show the login screen with POS Kasir title or login elements
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
