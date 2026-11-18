import 'package:bloc_test/bloc_test.dart';
import 'package:cine_list/core/error/app_exception.dart';
import 'package:cine_list/features/discover/data/models/movie_model.dart';
import 'package:cine_list/features/discover/data/models/paginated_movies_response.dart';
import 'package:cine_list/features/discover/data/repositories/discover_repository.dart';
import 'package:cine_list/features/discover/presentation/bloc/discover_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockDiscoverRepository extends Mock implements DiscoverRepository {}

void main() {
  late MockDiscoverRepository repository;

  const sampleMovies = [
    MovieModel(
      id: 1,
      title: 'Interstellar',
      releaseDate: '2014-11-05',
      voteAverage: 8.7,
    ),
    MovieModel(
      id: 2,
      title: 'Inception',
      releaseDate: '2010-07-16',
      voteAverage: 8.8,
    ),
  ];

  setUpAll(() {
    registerFallbackValue(DiscoverCategory.trending);
  });

  setUp(() {
    repository = MockDiscoverRepository();
  });

  group('DiscoverBloc', () {
    blocTest<DiscoverBloc, DiscoverState>(
      'emits loading then loaded on successful DiscoverInitialLoaded',
      build: () {
        when(
          () => repository.fetchByCategory(DiscoverCategory.trending, page: 1),
        ).thenAnswer(
          (_) async => const PaginatedMoviesResponse(
            page: 1,
            totalPages: 2,
            results: sampleMovies,
          ),
        );
        return DiscoverBloc(
          repository,
          debounceDuration: const Duration(milliseconds: 10),
        );
      },
      act: (bloc) => bloc.add(const DiscoverInitialLoaded()),
      expect: () => [
        const DiscoverState(status: DiscoverStatus.loading),
        const DiscoverState(
          status: DiscoverStatus.loaded,
          movies: sampleMovies,
          currentPage: 1,
          hasMore: true,
        ),
      ],
    );

    blocTest<DiscoverBloc, DiscoverState>(
      'emits loading then error when repository throws NetworkException',
      build: () {
        when(
          () => repository.fetchByCategory(DiscoverCategory.trending, page: 1),
        ).thenThrow(const NetworkException('No internet connection.'));
        return DiscoverBloc(
          repository,
          debounceDuration: const Duration(milliseconds: 10),
        );
      },
      act: (bloc) => bloc.add(const DiscoverInitialLoaded()),
      expect: () => [
        const DiscoverState(status: DiscoverStatus.loading),
        const DiscoverState(
          status: DiscoverStatus.error,
          errorMessage: 'No internet connection.',
        ),
      ],
    );

    blocTest<DiscoverBloc, DiscoverState>(
      'emits empty state when search returns zero movies',
      build: () {
        when(
          () => repository.searchMovies(
            query: 'nonexistent',
            page: 1,
            cancelToken: any(named: 'cancelToken'),
          ),
        ).thenAnswer(
          (_) async => const PaginatedMoviesResponse(
            page: 1,
            totalPages: 1,
            results: [],
          ),
        );
        return DiscoverBloc(
          repository,
          debounceDuration: const Duration(milliseconds: 10),
        );
      },
      act: (bloc) async {
        bloc.add(const DiscoverSearchChanged('nonexistent'));
        await Future<void>.delayed(const Duration(milliseconds: 40));
      },
      expect: () => [
        const DiscoverState(searchQuery: 'nonexistent'),
        const DiscoverState(
          status: DiscoverStatus.loading,
          searchQuery: 'nonexistent',
        ),
        const DiscoverState(
          status: DiscoverStatus.empty,
          searchQuery: 'nonexistent',
          movies: [],
          currentPage: 1,
          hasMore: false,
        ),
      ],
    );

    blocTest<DiscoverBloc, DiscoverState>(
      'restartable transformer skips intermediate debounced searches',
      build: () {
        when(
          () => repository.searchMovies(
            query: 'dune',
            page: 1,
            cancelToken: any(named: 'cancelToken'),
          ),
        ).thenAnswer(
          (_) async => const PaginatedMoviesResponse(
            page: 1,
            totalPages: 1,
            results: sampleMovies,
          ),
        );
        return DiscoverBloc(
          repository,
          debounceDuration: const Duration(milliseconds: 20),
        );
      },
      act: (bloc) async {
        bloc.add(const DiscoverSearchChanged('du'));
        bloc.add(const DiscoverSearchChanged('dun'));
        bloc.add(const DiscoverSearchChanged('dune'));
        await Future<void>.delayed(const Duration(milliseconds: 60));
      },
      verify: (bloc) {
        verifyNever(
          () => repository.searchMovies(
            query: 'du',
            page: any(named: 'page'),
            cancelToken: any(named: 'cancelToken'),
          ),
        );
        verifyNever(
          () => repository.searchMovies(
            query: 'dun',
            page: any(named: 'page'),
            cancelToken: any(named: 'cancelToken'),
          ),
        );
        verify(
          () => repository.searchMovies(
            query: 'dune',
            page: 1,
            cancelToken: any(named: 'cancelToken'),
          ),
        ).called(1);
        expect(bloc.state.status, DiscoverStatus.loaded);
      },
    );
  });
}

