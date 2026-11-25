import 'package:cine_list/core/widgets/app_bottom_nav_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'AppBottomNavigationBar renders all 5 tabs without overflow at 360px, handles taps, re-tap, drag scrubbing, and visibility',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      var selectedIndex = 0;
      var retapCount = 0;
      var isVisible = true;

      late StateSetter outerSetState;

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              outerSetState = setState;
              return Scaffold(
                extendBody: true,
                body: const SizedBox.expand(),
                bottomNavigationBar: AppBottomNavigationBar(
                  currentIndex: selectedIndex,
                  wantToWatchCount: 7,
                  visible: isVisible,
                  onTap: (idx) => setState(() => selectedIndex = idx),
                  onRetapActive: () => retapCount++,
                ),
              );
            },
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

      // Re-tapping the already active tab (Discover = 0) invokes onRetapActive.
      await tester.tap(find.text('Discover'));
      await tester.pumpAndSettle();
      expect(retapCount, 1);
      expect(selectedIndex, 0);

      // Tapping an inactive tab switches selection.
      await tester.tap(find.text('AI'));
      await tester.pumpAndSettle();
      expect(selectedIndex, 2);

      // Horizontal drag scrubbing from AI (center) to Community (far right).
      final barRect = tester.getRect(find.byType(AppBottomNavigationBar));
      await tester.dragFrom(
        barRect.center,
        Offset(barRect.width * 0.42, 0),
      );
      await tester.pumpAndSettle();
      expect(selectedIndex, 4);

      // Auto-hide (visible: false) disables hit-testing cleanly.
      outerSetState(() => isVisible = false);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discover'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(selectedIndex, 4);
    },
  );
}
