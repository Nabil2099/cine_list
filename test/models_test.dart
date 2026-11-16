import 'package:cine_list/core/constants/app_constants.dart';
import 'package:cine_list/features/discover/data/models/movie_model.dart';
import 'package:cine_list/features/discover/data/models/paginated_movies_response.dart';
import 'package:cine_list/features/movie_details/data/models/cast_member_model.dart';
import 'package:cine_list/features/movie_details/data/models/movie_details_model.dart';
import 'package:cine_list/features/movie_details/data/models/movie_video_model.dart';
import 'package:cine_list/features/watchlist/data/models/watchlist_movie_model.dart';
import 'package:cine_list/shared/models/movie_summary.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TMDB JSON Parsing', () {
    test('PaginatedMoviesResponse parses valid TMDB payload', () {
      final json = {
        'page': 1,
        'total_pages': 5,
        'results': [
          {
            'id': 157336,
            'title': 'Interstellar',
            'poster_path': '/poster.jpg',
            'backdrop_path': '/backdrop.jpg',
            'release_date': '2014-11-05',
            'vote_average': 8.4,
            'overview': 'A team of explorers travel through a wormhole.',
            'genre_ids': [12, 18, 878],
          },
        ],
      };

      final parsed = PaginatedMoviesResponse.fromJson(json);

      expect(parsed.page, 1);
      expect(parsed.totalPages, 5);
      expect(parsed.hasMore, isTrue);
      expect(parsed.results, hasLength(1));

      final movie = parsed.results.first;
      expect(movie.id, 157336);
      expect(movie.title, 'Interstellar');
      expect(movie.posterPath, '/poster.jpg');
      expect(movie.voteAverage, 8.4);
      expect(movie.genreIds, [12, 18, 878]);
    });

    test('MovieModel falls back safely when optional fields are missing', () {
      final movie = MovieModel.fromJson({
        'id': 42,
        'original_title': 'Fallback Title',
      });

      expect(movie.id, 42);
      expect(movie.title, 'Fallback Title');
      expect(movie.posterPath, isNull);
      expect(movie.voteAverage, 0.0);
      expect(movie.genreIds, isEmpty);
    });

    test('MovieDetailsModel and CastMemberModel parse details payload', () {
      final details = MovieDetailsModel.fromJson({
        'id': 693134,
        'title': 'Dune: Part Two',
        'release_date': '2024-02-27',
        'runtime': 166,
        'vote_average': 8.3,
        'overview': 'Paul Atreides unites with Chani and the Fremen.',
        'genres': [
          {'id': 878, 'name': 'Science Fiction'},
          {'id': 12, 'name': 'Adventure'},
        ],
      });

      final cast = CastMemberModel.fromJson({
        'id': 1190668,
        'name': 'Timothée Chalamet',
        'character': 'Paul Atreides',
        'profile_path': '/actor.jpg',
      });

      expect(details.runtime, 166);
      expect(details.genres, ['Science Fiction', 'Adventure']);
      expect(cast.name, 'Timothée Chalamet');
      expect(cast.character, 'Paul Atreides');
    });

    test('MovieVideoModel parses YouTube trailer and builds URLs', () {
      final video = MovieVideoModel.fromJson({
        'id': 'vid-1',
        'key': 'zSWdZVtXT7E',
        'name': 'Interstellar - Official Trailer',
        'site': 'YouTube',
        'type': 'Trailer',
        'official': true,
      });

      expect(video.isYouTube, isTrue);
      expect(video.isTrailer, isTrue);
      expect(video.official, isTrue);
      expect(
        video.youtubeUri.toString(),
        'https://www.youtube.com/watch?v=zSWdZVtXT7E',
      );
      expect(
        video.thumbnailUrl,
        'https://img.youtube.com/vi/zSWdZVtXT7E/hqdefault.jpg',
      );
    });
  });

  group('WatchlistMovieModel Serialization', () {
    test('serializes to Firestore map and deserializes back accurately', () {
      const summary = MovieSummary(
        id: 27205,
        title: 'Inception',
        posterPath: '/inception.jpg',
        backdropPath: '/inception_bg.jpg',
        releaseDate: '2010-07-16',
        voteAverage: 8.8,
      );

      final addedAt = DateTime(2026, 1, 15, 20, 30);
      final model = WatchlistMovieModel.fromMovieSummary(
        summary,
        status: WatchlistFilterStatus.wantToWatch,
        addedAt: addedAt,
      );

      final map = model.toFirestoreMap();
      expect(map['movieId'], 27205);
      expect(map['title'], 'Inception');
      expect(map['status'], AppConstants.statusWantToWatch);
      expect(map['addedAt'], isA<Timestamp>());
      expect(map['watchedAt'], isNull);

      final restored = WatchlistMovieModel.fromMap(map);
      expect(restored.movieId, 27205);
      expect(restored.title, 'Inception');
      expect(restored.status, WatchlistFilterStatus.wantToWatch);
      expect(restored.isWatched, isFalse);
      expect(restored.addedAt, addedAt);
    });
  });
}
