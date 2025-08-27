import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:litten/main.dart';
import 'package:litten/services/app_state_provider.dart';

void main() {
  testWidgets('Litten app smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (context) => AppStateProvider(),
        child: const LittenApp(),
      ),
    );

    // Wait for initialization
    await tester.pumpAndSettle();

    // Verify basic app structure
    expect(find.text('Litten'), findsWidgets);
  });
}