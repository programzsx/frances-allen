import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frances_allen/main.dart';

void main() {
  testWidgets('App launches smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const FrancesAllenApp());
    expect(find.text('题目管理'), findsOneWidget);
  });
}