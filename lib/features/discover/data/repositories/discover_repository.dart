import 'package:dio/dio.dart';

import '../datasources/tmdb_remote_data_source.dart';
import '../models/paginated_movies_response.dart';

enum DiscoverCategory {
  trending('trending', 'Trending'),
  nowPlaying('now_playing', 'Now Playing'),
  upcoming('upcoming', 'Upcoming'),
  popular('popular', 'Popular'),
  topRated('top_rated', 'Top Rated');

  const DiscoverCategory(this.key, this.label);

  final String key;
  final String label;

  static DiscoverCategory fromKey(String key) {
    return DiscoverCategory.values.firstWhere(
      (c) => c.key == key,
      orElse: () => DiscoverCategory.trending,
    );
  }
}

class DiscoverGenre {
  const DiscoverGenre(this.id, this.label);

  static const int arabicGenreId = -1;

  final int id;
  final String label;

  static const List<DiscoverGenre> defaults = [
    DiscoverGenre(arabicGenreId, 'Arabic'),
    DiscoverGenre(28, 'Action'),
    DiscoverGenre(878, 'Sci-Fi'),
    DiscoverGenre(53, 'Thriller'),
    DiscoverGenre(35, 'Comedy'),
    DiscoverGenre(18, 'Drama'),
    DiscoverGenre(27, 'Horror'),
    DiscoverGenre(16, 'Animation'),
    DiscoverGenre(10749, 'Romance'),
    DiscoverGenre(80, 'Crime'),
    DiscoverGenre(9648, 'Mystery'),
    DiscoverGenre(12, 'Adventure'),
    DiscoverGenre(14, 'Fantasy'),
    DiscoverGenre(99, 'Documentary'),
  ];
}

/// Repository for movie discovery, genre filtering, and search.
class DiscoverRepository {
  DiscoverRepository(this._remoteDataSource);

  final TmdbRemoteDataSource _remoteDataSource;

  Future<PaginatedMoviesResponse> fetchByCategory(
    DiscoverCategory category, {
    int page = 1,
  }) {
    switch (category) {
      case DiscoverCategory.trending:
        return _remoteDataSource.getTrendingMovies(page: page);
      case DiscoverCategory.nowPlaying:
        return _remoteDataSource.getNowPlayingMovies(page: page);
      case DiscoverCategory.upcoming:
        return _remoteDataSource.getUpcomingMovies(page: page);
      case DiscoverCategory.popular:
        return _remoteDataSource.getPopularMovies(page: page);
      case DiscoverCategory.topRated:
        return _remoteDataSource.getTopRatedMovies(page: page);
    }
  }

  Future<PaginatedMoviesResponse> fetchByGenre(int genreId, {int page = 1}) {
    if (genreId == DiscoverGenre.arabicGenreId) {
      return _remoteDataSource.discoverArabicMovies(page: page);
    }
    return _remoteDataSource.discoverMoviesByGenre(
      genreId: genreId,
      page: page,
    );
  }

  Future<PaginatedMoviesResponse> searchMovies({
    required String query,
    int page = 1,
    CancelToken? cancelToken,
  }) {
    return _remoteDataSource.searchMovies(
      query: query,
      page: page,
      cancelToken: cancelToken,
    );
  }
}
