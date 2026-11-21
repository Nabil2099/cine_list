import 'package:cine_list/features/discover/data/datasources/tmdb_remote_data_source.dart';
import 'package:cine_list/features/discover/data/models/movie_model.dart';
import 'package:cine_list/features/discover/data/models/paginated_movies_response.dart';
import 'package:cine_list/features/discover/data/repositories/discover_repository.dart';
import 'package:cine_list/features/movie_details/data/repositories/movie_details_repository.dart';
import 'package:cine_list/shared/models/movie_summary.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockTmdbRemoteDataSource extends Mock implements TmdbRemoteDataSource {}

void main() {
  late MockTmdbRemoteDataSource remote;

  setUp(() {
    remote = MockTmdbRemoteDataSource();
  });

  group('Anime TV & Movie JSON parsing', () {
    test('MovieModel.fromJson parses TMDB TV series payload as MediaType.tv', () {
      final model = MovieModel.fromJson({
        'id': 1429,
        'name': 'Attack on Titan',
        'first_air_date': '2013-04-07',
        'vote_average': 8.7,
        'genre_ids': [16, 10759],
      });

      expect(model.id, 1429);
      expect(model.title, 'Attack on Titan');
      expect(model.releaseDate, '2013-04-07');
      expect(model.mediaType, MediaType.tv);
    });
  });

  group('DiscoverRepository.fetchAnime', () {
    const tvPage = PaginatedMoviesResponse(
      page: 1,
      totalPages: 3,
      results: [
        MovieModel(
          id: 95479,
          title: 'Jujutsu Kaisen',
          mediaType: MediaType.tv,
        ),
      ],
    );
    const moviePage = PaginatedMoviesResponse(
      page: 1,
      totalPages: 2,
      results: [
        MovieModel(
          id: 129,
          title: 'Spirited Away',
          mediaType: MediaType.movie,
        ),
      ],
    );

    test('interleaves series and movies for AnimeMediaFilter.all and caches result', () async {
      final repo = DiscoverRepository(remote);

      when(
        () => remote.discoverAnimeSeries(genreId: 28, page: 1),
      ).thenAnswer((_) async => tvPage);
      when(
        () => remote.discoverAnimeMovies(genreId: 28, page: 1),
      ).thenAnswer((_) async => moviePage);

      final first = await repo.fetchAnime(
        filter: AnimeMediaFilter.all,
        genreId: 28,
      );
      final second = await repo.fetchAnime(
        filter: AnimeMediaFilter.all,
        genreId: 28,
      );

      expect(first.results.map((m) => m.title), [
        'Jujutsu Kaisen',
        'Spirited Away',
      ]);
      expect(first.results.map((m) => m.mediaType), [
        MediaType.tv,
        MediaType.movie,
      ]);
      expect(second, first);
      verify(() => remote.discoverAnimeSeries(genreId: 28, page: 1)).called(1);
      verify(() => remote.discoverAnimeMovies(genreId: 28, page: 1)).called(1);
    });

    test('returns empty response when Arabic filter is selected under Anime', () async {
      final repo = DiscoverRepository(remote);

      final result = await repo.fetchAnime(
        filter: AnimeMediaFilter.all,
        genreId: DiscoverGenre.arabicGenreId,
      );

      expect(result.results, isEmpty);
      expect(result.hasMore, isFalse);
      verifyNever(
        () => remote.discoverAnimeSeries(
          genreId: any(named: 'genreId'),
          page: any(named: 'page'),
        ),
      );
      verifyNever(
        () => remote.discoverAnimeMovies(
          genreId: any(named: 'genreId'),
          page: any(named: 'page'),
        ),
      );
    });
  });

  group('MovieDetailsRepository TV vs Movie cache isolation', () {
    test('separates cached details for identical movie and TV IDs', () async {
      final repo = MovieDetailsRepository(remote);

      when(() => remote.getMovieDetailsJson(100)).thenAnswer(
        (_) async => {'id': 100, 'title': 'Movie 100', 'runtime': 110},
      );
      when(() => remote.getTvDetailsJson(100)).thenAnswer(
        (_) async => {
          'id': 100,
          'name': 'Anime Series 100',
          'number_of_seasons': 2,
          'number_of_episodes': 24,
        },
      );

      final movieDetails = await repo.getMovieDetails(
        100,
        mediaType: MediaType.movie,
      );
      final tvDetails = await repo.getMovieDetails(
        100,
        mediaType: MediaType.tv,
      );

      expect(movieDetails.title, 'Movie 100');
      expect(movieDetails.mediaType, MediaType.movie);
      expect(tvDetails.title, 'Anime Series 100');
      expect(tvDetails.mediaType, MediaType.tv);
      expect(tvDetails.numberOfSeasons, 2);
      expect(tvDetails.numberOfEpisodes, 24);
    });
  });
}
