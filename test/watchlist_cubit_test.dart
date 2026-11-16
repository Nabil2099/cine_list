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
  });
}
