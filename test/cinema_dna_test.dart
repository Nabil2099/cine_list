import 'package:cine_list/features/ai_chat/data/models/cinema_dna_model.dart';
import 'package:cine_list/features/ai_chat/data/repositories/ai_chat_repository.dart';
import 'package:cine_list/features/ai_chat/presentation/cubit/cinema_dna_cubit.dart';
import 'package:cine_list/features/discover/data/models/movie_model.dart';
import 'package:cine_list/features/discover/data/models/paginated_movies_response.dart';
import 'package:cine_list/features/discover/data/repositories/discover_repository.dart';
import 'package:cine_list/features/watchlist/data/models/watchlist_movie_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAiChatRepository extends Mock implements AiChatRepository {}

class MockDiscoverRepository extends Mock implements DiscoverRepository {}

void main() {
  group('CinemaDnaCubit', () {
    test('analyzes watchlist and resolves blind-spot TMDB posters concurrently', () async {
      final ai = MockAiChatRepository();
      final discover = MockDiscoverRepository();
      final watchlist = [
        WatchlistMovieModel(
          movieId: 10,
          title: 'Inception',
          userRating: 5,
          status: WatchlistFilterStatus.watched,
          addedAt: DateTime(2026, 1, 1),
        ),
        WatchlistMovieModel(
          movieId: 20,
          title: 'Blade Runner 2049',
          userRating: 5,
          status: WatchlistFilterStatus.watched,
          addedAt: DateTime(2026, 1, 2),
        ),
      ];

      when(() => ai.analyzeCinemaDna(watchlist: watchlist)).thenAnswer(
        (_) async => const CinemaDnaProfile(
          archetype: 'The Neo-Noir Architect',
          tagline: 'You love mind-bending sci-fi worlds.',
          traits: [
            CinemaDnaTrait(label: 'Cerebral Sci-Fi', score: 94),
          ],
          blindSpots: [
            CinemaDnaBlindSpot(
              title: 'Dark City',
              year: '1998',
              reason: 'Essential neo-noir sci-fi precursor to your favorites.',
            ),
          ],
          totalMovies: 2,
          watchedCount: 2,
          averageRating: 5.0,
          topDecade: '2010s',
        ),
      );
      when(() => discover.searchMovies(query: 'Dark City', page: 1)).thenAnswer(
        (_) async => const PaginatedMoviesResponse(
          page: 1,
          totalPages: 1,
          results: [
            MovieModel(
              id: 2666,
              title: 'Dark City',
              releaseDate: '1998-02-27',
              voteAverage: 7.3,
            ),
          ],
        ),
      );

      final cubit = CinemaDnaCubit(ai, discover);
      await cubit.analyze(watchlist);

      expect(cubit.state.status, CinemaDnaStatus.loaded);
      expect(cubit.state.profile?.archetype, 'The Neo-Noir Architect');
      expect(cubit.state.profile?.blindSpots.first.movie?.id, 2666);
      await cubit.close();
    });
  });
}
