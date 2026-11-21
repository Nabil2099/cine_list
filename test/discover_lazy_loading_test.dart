import 'package:cine_list/features/discover/data/models/movie_model.dart';
import 'package:cine_list/features/discover/data/models/paginated_movies_response.dart';
import 'package:cine_list/features/discover/data/repositories/discover_repository.dart';
import 'package:cine_list/features/discover/presentation/bloc/discover_bloc.dart';
import 'package:cine_list/shared/models/movie_summary.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockDiscoverRepository extends Mock implements DiscoverRepository {}

void main() {
  group('DiscoverBloc.mergeExplorePage', () {
    test('keeps Featured + Top 5 in natural order and sorts Explore More by rating on page 1', () {
      final incoming = [
        for (var i = 1; i <= 6; i++)
          MovieSummary(id: i, title: 'Head $i', voteAverage: 5.0 + i * 0.1),
        const MovieSummary(id: 7, title: 'Low', voteAverage: 6.1),
        const MovieSummary(id: 8, title: 'High', voteAverage: 8.9),
        const MovieSummary(id: 9, title: 'Mid', voteAverage: 7.4),
      ];

      final merged = DiscoverBloc.mergeExplorePage(
        existing: const [],
        incoming: incoming,
        page: 1,
      );

      expect(merged.take(6).map((m) => m.id), [1, 2, 3, 4, 5, 6]);
      expect(merged.skip(6).map((m) => m.id), [8, 9, 7]);
    });

    test('deduplicates and appends page 2 sorted without shifting page 1 items', () {
      final page1 = [
        for (var i = 1; i <= 6; i++)
          MovieSummary(id: i, title: 'Head $i', voteAverage: 7.0),
        const MovieSummary(id: 7, title: 'Page1 A', voteAverage: 7.5),
      ];
      final page2 = [
        const MovieSummary(id: 7, title: 'Duplicate', voteAverage: 9.9),
        const MovieSummary(id: 10, title: 'Page2 Low', voteAverage: 6.2),
        const MovieSummary(id: 11, title: 'Page2 High', voteAverage: 9.1),
      ];

      final merged = DiscoverBloc.mergeExplorePage(
        existing: page1,
        incoming: page2,
        page: 2,
      );

      expect(merged.map((m) => m.id), [1, 2, 3, 4, 5, 6, 7, 11, 10]);
    });
  });

  group('DiscoverBloc infinite-scroll pagination', () {
    test('loads page 1 and lazily appends page 2 via DiscoverNextPageLoaded', () async {
      final repo = MockDiscoverRepository();
      when(
        () => repo.fetchByCategory(DiscoverCategory.trending, page: 1),
      ).thenAnswer(
        (_) async => const PaginatedMoviesResponse(
          page: 1,
          totalPages: 3,
          results: [
            MovieModel(id: 1, title: 'One', voteAverage: 7.5),
            MovieModel(id: 2, title: 'Two', voteAverage: 8.0),
          ],
        ),
      );
      when(
        () => repo.fetchByCategory(DiscoverCategory.trending, page: 2),
      ).thenAnswer(
        (_) async => const PaginatedMoviesResponse(
          page: 2,
          totalPages: 3,
          results: [
            MovieModel(id: 3, title: 'Three', voteAverage: 6.8),
            MovieModel(id: 4, title: 'Four', voteAverage: 9.0),
          ],
        ),
      );

      final bloc = DiscoverBloc(repo);
      bloc.add(const DiscoverInitialLoaded());
      await Future<void>.delayed(Duration.zero);

      expect(bloc.state.status, DiscoverStatus.loaded);
      expect(bloc.state.hasMore, isTrue);
      expect(bloc.state.movies.map((m) => m.id), [1, 2]);

      bloc.add(const DiscoverNextPageLoaded());
      await Future<void>.delayed(Duration.zero);

      expect(bloc.state.currentPage, 2);
      expect(bloc.state.isLoadingMore, isFalse);
      expect(bloc.state.movies.map((m) => m.id), [1, 2, 4, 3]);
      await bloc.close();
    });
  });
}
