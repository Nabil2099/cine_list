import 'dart:async';

import 'package:cine_list/core/error/app_exception.dart';
import 'package:cine_list/features/discover/data/datasources/tmdb_remote_data_source.dart';
import 'package:cine_list/features/discover/data/models/movie_model.dart';
import 'package:cine_list/features/discover/data/models/paginated_movies_response.dart';
import 'package:cine_list/features/discover/data/repositories/discover_repository.dart';
import 'package:cine_list/features/movie_details/data/models/cast_member_model.dart';
import 'package:cine_list/features/movie_details/data/models/movie_details_model.dart';
import 'package:cine_list/features/movie_details/data/repositories/movie_details_repository.dart';
import 'package:cine_list/features/movie_details/presentation/cubit/movie_details_cubit.dart';
import 'package:cine_list/features/movie_details/presentation/cubit/movie_details_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockTmdbRemoteDataSource extends Mock implements TmdbRemoteDataSource {}

class MockMovieDetailsRepository extends Mock
    implements MovieDetailsRepository {}

void main() {
  late MockTmdbRemoteDataSource remote;

  const samplePage = PaginatedMoviesResponse(
    page: 1,
    totalPages: 2,
    results: [
      MovieModel(id: 157336, title: 'Interstellar', voteAverage: 8.7),
    ],
  );

  setUp(() {
    remote = MockTmdbRemoteDataSource();
  });

  group('DiscoverRepository TTL cache', () {
    test(
      'caches category & genre responses within TTL and bypasses on forceRefresh',
      () async {
        var now = DateTime(2026, 1, 1, 12, 0);
        final repo = DiscoverRepository(
          remote,
          cacheTtl: const Duration(minutes: 5),
          clock: () => now,
        );

        when(() => remote.getTrendingMovies(page: 1))
            .thenAnswer((_) async => samplePage);
        when(() => remote.discoverMoviesByGenre(genreId: 28, page: 1))
            .thenAnswer((_) async => samplePage);

        // First call hits network; second within TTL hits cache.
        final first = await repo.fetchByCategory(DiscoverCategory.trending);
        final second = await repo.fetchByCategory(DiscoverCategory.trending);
        expect(first, samplePage);
        expect(second, samplePage);
        verify(() => remote.getTrendingMovies(page: 1)).called(1);

        // forceRefresh bypasses cache.
        await repo.fetchByCategory(
          DiscoverCategory.trending,
          forceRefresh: true,
        );
        verify(() => remote.getTrendingMovies(page: 1)).called(1);

        // Advancing clock past TTL expires cache.
        now = now.add(const Duration(minutes: 6));
        await repo.fetchByCategory(DiscoverCategory.trending);
        verify(() => remote.getTrendingMovies(page: 1)).called(1);

        // Genre cache works identically.
        await repo.fetchByGenre(28);
        await repo.fetchByGenre(28);
        verify(() => remote.discoverMoviesByGenre(genreId: 28, page: 1))
            .called(1);
      },
    );
  });

  group('MovieDetailsRepository LRU cache', () {
    test('caches movie details and evicts LRU past capacity', () async {
      var now = DateTime(2026, 1, 1, 12, 0);
      final repo = MovieDetailsRepository(
        remote,
        cacheTtl: const Duration(minutes: 10),
        maxCacheEntries: 2,
        clock: () => now,
      );

      Map<String, dynamic> detailsJson(int id, String title) => {
        'id': id,
        'title': title,
        'overview': 'Overview',
        'vote_average': 8.5,
      };

      when(() => remote.getMovieDetailsJson(1))
          .thenAnswer((_) async => detailsJson(1, 'One'));
      when(() => remote.getMovieDetailsJson(2))
          .thenAnswer((_) async => detailsJson(2, 'Two'));
      when(() => remote.getMovieDetailsJson(3))
          .thenAnswer((_) async => detailsJson(3, 'Three'));

      await repo.getMovieDetails(1);
      await repo.getMovieDetails(1); // hit
      verify(() => remote.getMovieDetailsJson(1)).called(1);

      await repo.getMovieDetails(2);
      verify(() => remote.getMovieDetailsJson(2)).called(1);
      // Touch 1 again so 2 becomes least recently used.
      await repo.getMovieDetails(1);
      await repo.getMovieDetails(3); // evicts 2

      await repo.getMovieDetails(1); // still cached
      verifyNever(() => remote.getMovieDetailsJson(1));

      await repo.getMovieDetails(2); // evicted -> refetches
      verify(() => remote.getMovieDetailsJson(2)).called(1);
    });
  });

  group('MovieDetailsCubit parallel load', () {
    test('launches all endpoints concurrently and tolerates auxiliary failures', () async {
      final repo = MockMovieDetailsRepository();
      final detailsCompleter = Completer<MovieDetailsModel>();
      var castStartedBeforeDetailsCompleted = false;

      when(() => repo.getMovieDetails(157336))
          .thenAnswer((_) => detailsCompleter.future);
      when(() => repo.getMovieCast(157336)).thenAnswer((_) async {
        castStartedBeforeDetailsCompleted = !detailsCompleter.isCompleted;
        return const [
          CastMemberModel(id: 1, name: 'Matthew McConaughey', character: 'Cooper'),
        ];
      });
      when(() => repo.getMovieTrailer(157336)).thenAnswer((_) async => null);
      when(() => repo.getSimilarMovies(157336))
          .thenAnswer((_) async => const []);
      when(() => repo.getWatchProviders(157336))
          .thenThrow(const NetworkException('Providers failed'));

      final cubit = MovieDetailsCubit(repo);
      final future = cubit.loadMovie(157336);
      await Future<void>.delayed(Duration.zero);

      expect(castStartedBeforeDetailsCompleted, isTrue);

      detailsCompleter.complete(
        const MovieDetailsModel(
          id: 157336,
          title: 'Interstellar',
          overview: 'Space epic.',
          voteAverage: 8.7,
        ),
      );
      await future;

      expect(cubit.state.status, MovieDetailsStatus.loaded);
      expect(cubit.state.details?.title, 'Interstellar');
      expect(cubit.state.cast, hasLength(1));
      expect(cubit.state.watchProviders, isEmpty);
      await cubit.close();
    });

    test('emits error state when primary movie details fails', () async {
      final repo = MockMovieDetailsRepository();
      when(() => repo.getMovieDetails(999))
          .thenThrow(const NetworkException('Movie not found.'));
      when(() => repo.getMovieCast(999)).thenAnswer((_) async => const []);
      when(() => repo.getMovieTrailer(999)).thenAnswer((_) async => null);
      when(() => repo.getSimilarMovies(999)).thenAnswer((_) async => const []);
      when(() => repo.getWatchProviders(999)).thenAnswer((_) async => const []);

      final cubit = MovieDetailsCubit(repo);
      await cubit.loadMovie(999);

      expect(cubit.state.status, MovieDetailsStatus.error);
      expect(cubit.state.errorMessage, 'Movie not found.');
      await cubit.close();
    });
  });
}
