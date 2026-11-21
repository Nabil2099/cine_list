import 'package:cine_list/core/widgets/app_bottom_nav_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'AppBottomNavigationBar renders all 5 tabs without overflow at 360px and handles taps & badge',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      var selectedIndex = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) => Scaffold(
              extendBody: true,
              body: const SizedBox.expand(),
              bottomNavigationBar: AppBottomNavigationBar(
                currentIndex: selectedIndex,
                wantToWatchCount: 7,
                onTap: (idx) => setState(() => selectedIndex = idx),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Discover'), findsOneWidget);
      expect(find.text('Watchlist'), findsOneWidget);
      expect(find.text('AI'), findsOneWidget);
      expect(find.text('Feed'), findsOneWidget);
      expect(find.text('Community'), findsOneWidget);
      expect(find.text('7'), findsOneWidget);

      await tester.tap(find.text('Community'));
      await tester.pumpAndSettle();
      expect(selectedIndex, 4);
    },
  );
}
