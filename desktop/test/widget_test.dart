// This is a basic Flutter widget test.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frances_allen_desktop/main.dart';

void main() {
  testWidgets('App loads successfully', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const DesktopApp());

    // Verify that the app builds without errors.
    expect(find.text('知识问答'), findsOneWidget);
  });
}
