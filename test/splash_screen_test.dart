import 'package:cine_list/core/widgets/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('AnimatedSplashScreen renders branding and loading indicator', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: AnimatedSplashScreen()));

    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('CineList'), findsOneWidget);
    expect(find.text('DISCOVER · SAVE · WATCH'), findsOneWidget);
    expect(find.textContaining('Loading your cinema'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 800));
    expect(tester.takeException(), isNull);
  });
}
