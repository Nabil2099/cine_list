import 'package:cine_list/features/watchlist/data/models/watchlist_movie_model.dart';
import 'package:cine_list/features/watchlist/presentation/screens/cinema_stats_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CinemaStatsSummary', () {
    test('computes rating distribution, hours with rewatches, and streak', () {
      final now = DateTime(2026, 11, 18);
      final movies = [
        WatchlistMovieModel(
          movieId: 1,
          title: 'Interstellar',
          status: WatchlistFilterStatus.watched,
          addedAt: DateTime(2026, 10, 1),
          watchedAt: DateTime(2026, 11, 5),
          userRating: 5,
          runtimeMinutes: 169,
          rewatchCount: 1,
        ),
        WatchlistMovieModel(
          movieId: 2,
          title: 'Arrival',
          status: WatchlistFilterStatus.watched,
          addedAt: DateTime(2026, 10, 2),
          watchedAt: DateTime(2026, 10, 14),
          userRating: 4,
          runtimeMinutes: 116,
        ),
        WatchlistMovieModel(
          movieId: 3,
          title: 'Unwatched Pick',
          status: WatchlistFilterStatus.wantToWatch,
          addedAt: DateTime(2026, 11, 10),
        ),
      ];

      final summary = CinemaStatsSummary.fromMovies(movies, now: now);

      expect(summary.totalWatched, 2);
      expect(summary.totalWatchesWithRewatches, 3);
      expect(summary.totalHours, closeTo((169 * 2 + 116) / 60, 0.01));
      expect(summary.averageRating, 4.5);
      expect(summary.ratingCounts[5], 1);
      expect(summary.ratingCounts[4], 1);
      expect(summary.ratingCounts[3], 0);
      expect(summary.currentMonthStreak, 2);
      expect(summary.topFavorites.map((m) => m.movieId), [1, 2]);
      expect(summary.mostRewatched.map((m) => m.movieId), [1]);
      expect(summary.monthlyCounts, hasLength(6));
      expect(summary.monthlyCounts.last.label, 'Nov');
      expect(summary.monthlyCounts.last.count, 1);
    });

    test('handles empty watchlist safely', () {
      final summary = CinemaStatsSummary.fromMovies(const []);
      expect(summary.totalWatched, 0);
      expect(summary.totalHours, 0);
      expect(summary.averageRating, isNull);
      expect(summary.currentMonthStreak, 0);
      expect(summary.topFavorites, isEmpty);
      expect(summary.mostRewatched, isEmpty);
    });
  });
}
