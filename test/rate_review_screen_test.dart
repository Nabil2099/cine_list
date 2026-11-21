import 'package:cine_list/core/theme/app_theme.dart';
import 'package:cine_list/features/community/presentation/screens/rate_review_screen.dart';
import 'package:cine_list/shared/models/movie_summary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const testMovie = MovieSummary(
    id: 157336,
    title: 'Interstellar',
    releaseDate: '2014-11-05',
    voteAverage: 8.7,
  );

  testWidgets(
    'RateReviewScreen renders without overflow with keyboard open, validates community post, and toggles spoilers clearly',
    (tester) async {
      UnifiedReviewResult? capturedResult;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(360, 640),
              viewInsets: EdgeInsets.only(bottom: 280),
            ),
            child: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () async {
                      capturedResult = await RateReviewScreen.open(
                        context,
                        movie: testMovie,
                      );
                    },
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Interstellar'), findsOneWidget);
      expect(find.text('PRIVATE'), findsOneWidget);

      // Select 4 stars
      final starButtons = find.byIcon(Icons.star_border_rounded);
      await tester.tap(starButtons.at(3));
      await tester.pump();
      expect(find.text('4/5 · Great'), findsOneWidget);

      // Toggle Post to Community ON
      await tester.ensureVisible(find.text('Post to Community'));
      await tester.tap(find.text('Post to Community'));
      await tester.pumpAndSettle();
      expect(find.text('PUBLIC'), findsOneWidget);
      expect(find.text('Contains Spoilers'), findsOneWidget);
      expect(find.text('OFF'), findsOneWidget);

      // Toggle Spoilers ON and check unmistakable SPOILERS ON badge
      await tester.ensureVisible(find.text('Contains Spoilers'));
      await tester.tap(find.text('Contains Spoilers'));
      await tester.pumpAndSettle();
      expect(find.text('SPOILERS ON'), findsOneWidget);

      // Try posting without >= 5 characters -> shows inline validation error
      await tester.tap(find.text('Post'));
      await tester.pump();
      expect(
        find.text('Write at least 5 characters to share a review with Community.'),
        findsOneWidget,
      );

      // Enter valid review text and submit
      await tester.enterText(
        find.byType(TextField),
        'Mind-bending visuals and unforgettable Hans Zimmer score.',
      );
      await tester.pump();
      await tester.tap(find.text('Post'));
      await tester.pumpAndSettle();

      expect(capturedResult, isNotNull);
      expect(capturedResult!.rating, 4);
      expect(capturedResult!.publishToCommunity, isTrue);
      expect(capturedResult!.hasSpoilers, isTrue);
      expect(
        capturedResult!.reviewText,
        'Mind-bending visuals and unforgettable Hans Zimmer score.',
      );
    },
  );
}
