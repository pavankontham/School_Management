// Basic Flutter widget test for School Management App

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:school_management/main.dart';

void main() {
  testWidgets('App loads successfully', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      const ProviderScope(
        child: SchoolManagementApp(),
      ),
    );

    // Wait for the app to load
    await tester.pump();

    // Verify that the app loads (splash screen or login screen)
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
