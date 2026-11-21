import 'package:bloc_test/bloc_test.dart';
import 'package:cine_list/core/error/app_exception.dart';
import 'package:cine_list/features/watchlist/data/models/watchlist_movie_model.dart';
import 'package:cine_list/features/watchlist/data/repositories/watchlist_repository.dart';
import 'package:cine_list/features/watchlist/presentation/cubit/watchlist_cubit.dart';
import 'package:cine_list/features/watchlist/presentation/cubit/watchlist_state.dart';
import 'package:cine_list/shared/models/movie_summary.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockWatchlistRepository extends Mock implements WatchlistRepository {}

void main() {
  late MockWatchlistRepository repository;

  final savedItem = WatchlistMovieModel(
    movieId: 157336,
    title: 'Interstellar',
    status: WatchlistFilterStatus.wantToWatch,
    addedAt: DateTime(2026, 1, 1),
  );

  setUpAll(() {
    registerFallbackValue(savedItem);
    registerFallbackValue(WatchlistFilterStatus.wantToWatch);
  });

  setUp(() {
    repository = MockWatchlistRepository();
    when(() => repository.watchCollections(any()))
        .thenAnswer((_) => Stream.value(const []));
  });

  group('WatchlistCubit', () {
    blocTest<WatchlistCubit, WatchlistState>(
      'subscribes to user watchlist stream and emits loaded movies',
      build: () {
        when(() => repository.watchWatchlist('uid-123'))
            .thenAnswer((_) => Stream.value([savedItem]));
        return WatchlistCubit(repository);
      },
      act: (cubit) => cubit.bindUser('uid-123'),
      expect: () => [
        const WatchlistState(status: WatchlistLoadStatus.loading),
        WatchlistState(status: WatchlistLoadStatus.loaded, movies: [savedItem]),
      ],
    );

    blocTest<WatchlistCubit, WatchlistState>(
      'addToWatchlist calls repository.saveMovie and emits feedback',
      build: () {
        when(() => repository.watchWatchlist('uid-123'))
            .thenAnswer((_) => Stream.value(const []));
        when(() => repository.saveMovie('uid-123', any()))
            .thenAnswer((_) async {});
        return WatchlistCubit(repository);
      },
      act: (cubit) async {
        cubit.bindUser('uid-123');
        await Future<void>.delayed(Duration.zero);
        await cubit.addToWatchlist(
          const MovieSummary(id: 157336, title: 'Interstellar'),
        );
      },
      verify: (_) {
        verify(() => repository.saveMovie('uid-123', any())).called(1);
      },
      expect: () => [
        const WatchlistState(status: WatchlistLoadStatus.loading),
        const WatchlistState(status: WatchlistLoadStatus.loaded, movies: []),
        const WatchlistState(
          status: WatchlistLoadStatus.loaded,
          mutatingMovieIds: {157336},
        ),
        const WatchlistState(
          status: WatchlistLoadStatus.loaded,
          mutatingMovieIds: {157336},
          feedbackMessage: 'Added "Interstellar" to Watchlist.',
        ),
        const WatchlistState(
          status: WatchlistLoadStatus.loaded,
          mutatingMovieIds: {},
          feedbackMessage: 'Added "Interstellar" to Watchlist.',
        ),
      ],
    );

    blocTest<WatchlistCubit, WatchlistState>(
      'toggleWatchedStatus emits errorMessage when repository fails',
      build: () {
        when(() => repository.watchWatchlist('uid-123'))
            .thenAnswer((_) => Stream.value([savedItem]));
        when(
          () => repository.updateStatus(
            uid: 'uid-123',
            movieId: 157336,
            status: WatchlistFilterStatus.watched,
          ),
        ).thenThrow(const WatchlistException('Permission denied.'));
        return WatchlistCubit(repository);
      },
      act: (cubit) async {
        cubit.bindUser('uid-123');
        await Future<void>.delayed(Duration.zero);
        await cubit.toggleWatchedStatus(savedItem);
      },
      expect: () => [
        const WatchlistState(status: WatchlistLoadStatus.loading),
        WatchlistState(status: WatchlistLoadStatus.loaded, movies: [savedItem]),
        WatchlistState(
          status: WatchlistLoadStatus.loaded,
          movies: [savedItem],
          mutatingMovieIds: const {157336},
        ),
        WatchlistState(
          status: WatchlistLoadStatus.loaded,
          movies: [savedItem],
          mutatingMovieIds: const {157336},
          errorMessage: 'Permission denied.',
        ),
        WatchlistState(
          status: WatchlistLoadStatus.loaded,
          movies: [savedItem],
          mutatingMovieIds: const {},
          errorMessage: 'Permission denied.',
        ),
      ],
    );

    blocTest<WatchlistCubit, WatchlistState>(
      'createCollection persists collection and selects it',
      build: () {
        when(() => repository.watchWatchlist('uid-123'))
            .thenAnswer((_) => Stream.value([savedItem]));
        when(
          () => repository.createCollection(uid: 'uid-123', name: 'Date Night'),
        ).thenAnswer((_) async => 'col-1');
        return WatchlistCubit(repository);
      },
      act: (cubit) async {
        cubit.bindUser('uid-123');
        await Future<void>.delayed(Duration.zero);
        await cubit.createCollection('Date Night');
      },
      verify: (cubit) {
        verify(
          () => repository.createCollection(uid: 'uid-123', name: 'Date Night'),
        ).called(1);
        expect(cubit.state.selectedCollectionId, 'col-1');
        expect(cubit.state.feedbackMessage, 'Created collection "Date Night".');
      },
    );

    test('WatchlistState prioritizes Up Next and counts rewatches in minutes', () {
      final upNextMovie = WatchlistMovieModel(
        movieId: 1,
        title: 'Up Next Film',
        status: WatchlistFilterStatus.wantToWatch,
        addedAt: DateTime(2025, 1, 1),
        isUpNext: true,
      );
      final regularMovie = WatchlistMovieModel(
        movieId: 2,
        title: 'Regular Film',
        status: WatchlistFilterStatus.wantToWatch,
        addedAt: DateTime(2025, 2, 1),
      );
      final watchedRewatched = WatchlistMovieModel(
        movieId: 3,
        title: 'Rewatched Film',
        status: WatchlistFilterStatus.watched,
        addedAt: DateTime(2025, 1, 1),
        runtimeMinutes: 100,
        rewatchCount: 2,
      );

      final state = WatchlistState(
        status: WatchlistLoadStatus.loaded,
        movies: [regularMovie, upNextMovie, watchedRewatched],
      );

      expect(state.upNextCount, 1);
      expect(state.activeTabMovies.map((m) => m.movieId).toList(), [1, 2]);
      expect(state.totalMinutesWatched, 300);
    });

    blocTest<WatchlistCubit, WatchlistState>(
      'toggleUpNext blocks pinning beyond max 5 movies',
      build: () {
        final fiveUpNext = List.generate(
          5,
          (i) => WatchlistMovieModel(
            movieId: i + 1,
            title: 'Movie ${i + 1}',
            status: WatchlistFilterStatus.wantToWatch,
            addedAt: DateTime(2025, 1, i + 1),
            isUpNext: true,
          ),
        );
        when(() => repository.watchWatchlist('uid-123')).thenAnswer(
          (_) => Stream.value([...fiveUpNext, savedItem]),
        );
        return WatchlistCubit(repository);
      },
      act: (cubit) async {
        cubit.bindUser('uid-123');
        await Future<void>.delayed(Duration.zero);
        await cubit.toggleUpNext(savedItem);
      },
      verify: (cubit) {
        verifyNever(
          () => repository.toggleUpNext(
            uid: any(named: 'uid'),
            movieId: any(named: 'movieId'),
            isUpNext: any(named: 'isUpNext'),
          ),
        );
        expect(
          cubit.state.feedbackMessage,
          'Up Next queue is full (max 5 movies).',
        );
      },
    );

    blocTest<WatchlistCubit, WatchlistState>(
      'cloneCuratedList creates collection and saves only unsaved movies',
      build: () {
        when(() => repository.watchWatchlist('uid-123'))
            .thenAnswer((_) => Stream.value([savedItem]));
        when(
          () => repository.cloneCollectionWithMovies(
            uid: 'uid-123',
            name: 'Sci-Fi Picks',
            moviesToSave: any(named: 'moviesToSave'),
            allMovieIds: [157336, 438631],
          ),
        ).thenAnswer((_) async => 'col-cloned');
        return WatchlistCubit(repository);
      },
      act: (cubit) async {
        cubit.bindUser('uid-123');
        await Future<void>.delayed(Duration.zero);
        await cubit.cloneCuratedList(
          title: 'Sci-Fi Picks',
          movies: const [
            MovieSummary(id: 157336, title: 'Interstellar'),
            MovieSummary(id: 438631, title: 'Dune'),
          ],
        );
      },
      verify: (cubit) {
        expect(cubit.state.selectedCollectionId, 'col-cloned');
        expect(
          cubit.state.feedbackMessage,
          'Cloned "Sci-Fi Picks" (1 new movies added).',
        );
      },
    );

    blocTest<WatchlistCubit, WatchlistState>(
      'logWatchedMovie saves unsaved movie directly as Watched with rating & note',
      build: () {
        when(() => repository.watchWatchlist('uid-123'))
            .thenAnswer((_) => Stream.value(const []));
        when(() => repository.saveMovie('uid-123', any()))
            .thenAnswer((_) async {});
        return WatchlistCubit(repository);
      },
      act: (cubit) async {
        cubit.bindUser('uid-123');
        await Future<void>.delayed(Duration.zero);
        await cubit.logWatchedMovie(
          const MovieSummary(id: 157336, title: 'Interstellar'),
          runtimeMinutes: 169,
          userRating: 5,
          userNote: 'Incredible score.',
          updateReviewFields: true,
        );
      },
      verify: (cubit) {
        final captured =
            verify(() => repository.saveMovie('uid-123', captureAny()))
                .captured
                .single as WatchlistMovieModel;
        expect(captured.movieId, 157336);
        expect(captured.status, WatchlistFilterStatus.watched);
        expect(captured.userRating, 5);
        expect(captured.userNote, 'Incredible score.');
        expect(captured.runtimeMinutes, 169);
        expect(
          cubit.state.feedbackMessage,
          'Saved rating & review for "Interstellar".',
        );
      },
    );

    blocTest<WatchlistCubit, WatchlistState>(
      'logWatchedMovie updates existing saved movie via markWatchedWithReview',
      build: () {
        when(() => repository.watchWatchlist('uid-123'))
            .thenAnswer((_) => Stream.value([savedItem]));
        when(
          () => repository.markWatchedWithReview(
            uid: 'uid-123',
            movieId: 157336,
            userRating: 4,
            userNote: 'Worth the wait',
            runtimeMinutes: 169,
          ),
        ).thenAnswer((_) async {});
        return WatchlistCubit(repository);
      },
      act: (cubit) async {
        cubit.bindUser('uid-123');
        await Future<void>.delayed(Duration.zero);
        await cubit.logWatchedMovie(
          const MovieSummary(id: 157336, title: 'Interstellar'),
          runtimeMinutes: 169,
          userRating: 4,
          userNote: 'Worth the wait',
          updateReviewFields: true,
        );
      },
      verify: (cubit) {
        verify(
          () => repository.markWatchedWithReview(
            uid: 'uid-123',
            movieId: 157336,
            userRating: 4,
            userNote: 'Worth the wait',
            runtimeMinutes: 169,
          ),
        ).called(1);
        expect(
          cubit.state.feedbackMessage,
          'Saved rating & review for "Interstellar".',
        );
      },
    );
  });
}
