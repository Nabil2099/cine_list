import 'dart:math';

import 'package:cine_list/features/ai_chat/data/repositories/ai_chat_repository.dart';
import 'package:cine_list/features/discover/data/datasources/tmdb_remote_data_source.dart';
import 'package:cine_list/features/discover/data/models/movie_model.dart';
import 'package:cine_list/features/discover/data/models/paginated_movies_response.dart';
import 'package:cine_list/features/discover/data/repositories/recommendation_repository.dart';
import 'package:cine_list/features/watchlist/data/models/watchlist_movie_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockTmdbRemoteDataSource extends Mock implements TmdbRemoteDataSource {}

class MockAiChatRepository extends Mock implements AiChatRepository {}

void main() {
  late MockTmdbRemoteDataSource remote;
  late MockAiChatRepository ai;

  setUp(() {
    remote = MockTmdbRemoteDataSource();
    ai = MockAiChatRepository();
  });

  group('RecommendationRepository', () {
    test('blends AI picks and algorithmic TMDB seed recommendations into 5 unseen movies', () async {
      final repo = RecommendationRepository(remote, ai, random: Random(42));
      final watchlist = [
        WatchlistMovieModel(
          movieId: 10,
          title: 'Inception',
          voteAverage: 8.4,
          userRating: 5,
          status: WatchlistFilterStatus.watched,
          addedAt: DateTime(2026, 1, 1),
        ),
      ];

      when(
        () => ai.recommendMovieTitles(watchlist: watchlist, count: 8),
      ).thenAnswer(
        (_) async => [
          (title: 'Arrival', year: '2016'),
          (title: 'Ex Machina', year: '2014'),
        ],
      );
      when(() => remote.searchMovies(query: 'Arrival', page: 1)).thenAnswer(
        (_) async => const PaginatedMoviesResponse(
          page: 1,
          totalPages: 1,
          results: [
            MovieModel(
              id: 329865,
              title: 'Arrival',
              releaseDate: '2016-11-10',
              voteAverage: 7.9,
            ),
          ],
        ),
      );
      when(() => remote.searchMovies(query: 'Ex Machina', page: 1)).thenAnswer(
        (_) async => const PaginatedMoviesResponse(
          page: 1,
          totalPages: 1,
          results: [
            MovieModel(
              id: 264660,
              title: 'Ex Machina',
              releaseDate: '2014-01-21',
              voteAverage: 7.6,
            ),
          ],
        ),
      );
      when(() => remote.getMovieRecommendations(10)).thenAnswer(
        (_) async => const PaginatedMoviesResponse(
          page: 1,
          totalPages: 1,
          results: [
            MovieModel(id: 10, title: 'Inception', voteAverage: 8.4), // excluded
            MovieModel(id: 157336, title: 'Interstellar', voteAverage: 8.7),
            MovieModel(id: 27205, title: 'Memento', voteAverage: 8.2),
            MovieModel(id: 1124, title: 'The Prestige', voteAverage: 8.5),
            MovieModel(id: 603, title: 'The Matrix', voteAverage: 8.7),
          ],
        ),
      );

      final result = await repo.getRecommendations(watchlist: watchlist);

      expect(result.usedAi, isTrue);
      expect(result.basedOnWatchlist, isTrue);
      expect(result.movies, hasLength(5));
      expect(result.movies.any((m) => m.id == 10), isFalse);
      expect(result.movies.map((m) => m.id).toSet(), hasLength(5));
    });

    test('falls back to algorithmic TMDB picks when AI returns empty', () async {
      final repo = RecommendationRepository(remote, ai, random: Random(7));
      final watchlist = [
        WatchlistMovieModel(
          movieId: 10,
          title: 'Inception',
          voteAverage: 8.4,
          userRating: 5,
          status: WatchlistFilterStatus.watched,
          addedAt: DateTime(2026, 1, 1),
        ),
      ];

      when(
        () => ai.recommendMovieTitles(watchlist: watchlist, count: 8),
      ).thenAnswer((_) async => const []);
      when(() => remote.getMovieRecommendations(10)).thenAnswer(
        (_) async => const PaginatedMoviesResponse(
          page: 1,
          totalPages: 1,
          results: [
            MovieModel(id: 157336, title: 'Interstellar', voteAverage: 8.7),
            MovieModel(id: 27205, title: 'Memento', voteAverage: 8.2),
            MovieModel(id: 1124, title: 'The Prestige', voteAverage: 8.5),
            MovieModel(id: 603, title: 'The Matrix', voteAverage: 8.7),
            MovieModel(id: 77, title: 'Tenet', voteAverage: 7.3),
          ],
        ),
      );

      final result = await repo.getRecommendations(
        watchlist: watchlist,
        excludeIds: {157336},
        shuffle: true,
      );

      expect(result.usedAi, isFalse);
      expect(result.basedOnWatchlist, isTrue);
      expect(result.movies.any((m) => m.id == 157336), isFalse);
    });
  });
}
