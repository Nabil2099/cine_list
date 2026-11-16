import '../../../discover/data/datasources/tmdb_remote_data_source.dart';
import '../../../discover/data/models/movie_model.dart';
import '../models/cast_member_model.dart';
import '../models/movie_details_model.dart';
import '../models/movie_video_model.dart';
import '../models/person_details_model.dart';
import '../models/watch_provider_model.dart';

/// Repository fetching full movie details, cast, trailers, providers, and
/// recommendations from TMDB.
class MovieDetailsRepository {
  MovieDetailsRepository(this._remoteDataSource);

  final TmdbRemoteDataSource _remoteDataSource;

  Future<MovieDetailsModel> getMovieDetails(int movieId) async {
    final json = await _remoteDataSource.getMovieDetailsJson(movieId);
    return MovieDetailsModel.fromJson(json);
  }

  Future<List<CastMemberModel>> getMovieCast(int movieId) async {
    final json = await _remoteDataSource.getMovieCreditsJson(movieId);
    final rawCast = json['cast'];
    if (rawCast is! List) return const [];
    return rawCast
        .whereType<Map>()
        .take(12)
        .map((e) => CastMemberModel.fromJson(Map<String, dynamic>.from(e)))
        .where((c) => c.id > 0)
        .toList();
  }

  Future<MovieVideoModel?> getMovieTrailer(int movieId) async {
    final json = await _remoteDataSource.getMovieVideosJson(movieId);
    final rawResults = json['results'];
    if (rawResults is! List) return null;

    final youtubeVideos = rawResults
        .whereType<Map>()
        .map((e) => MovieVideoModel.fromJson(Map<String, dynamic>.from(e)))
        .where((v) => v.isYouTube)
        .toList();

    if (youtubeVideos.isEmpty) return null;

    return youtubeVideos.firstWhere(
      (v) => v.isTrailer && v.official,
      orElse: () => youtubeVideos.firstWhere(
        (v) => v.isTrailer,
        orElse: () => youtubeVideos.firstWhere(
          (v) => v.isTeaser && v.official,
          orElse: () => youtubeVideos.first,
        ),
      ),
    );
  }

  Future<List<MovieModel>> getSimilarMovies(int movieId) async {
    final response = await _remoteDataSource.getMovieRecommendations(movieId);
    return response.results.take(10).toList();
  }

  Future<List<WatchProviderModel>> getWatchProviders(int movieId) async {
    final json = await _remoteDataSource.getMovieWatchProvidersJson(movieId);
    final results = json['results'];
    if (results is! Map || results.isEmpty) return const [];

    Map<String, dynamic>? regionData;
    if (results['US'] is Map) {
      regionData = Map<String, dynamic>.from(results['US'] as Map);
    } else {
      final firstEntry = results.values.whereType<Map>().firstOrNull;
      if (firstEntry != null) {
        regionData = Map<String, dynamic>.from(firstEntry);
      }
    }
    if (regionData == null) return const [];

    final providers = <WatchProviderModel>[];
    final seenIds = <int>{};

    void addFromKey(String key, WatchProviderType type) {
      final raw = regionData?[key];
      if (raw is! List) return;
      for (final item in raw.whereType<Map>()) {
        final model = WatchProviderModel.fromJson(
          Map<String, dynamic>.from(item),
          type: type,
        );
        if (model.providerId > 0 && seenIds.add(model.providerId)) {
          providers.add(model);
        }
      }
    }

    addFromKey('flatrate', WatchProviderType.stream);
    addFromKey('rent', WatchProviderType.rent);
    addFromKey('buy', WatchProviderType.buy);

    return providers.take(10).toList();
  }

  Future<PersonDetailsModel> getPersonDetails(int personId) async {
    final json = await _remoteDataSource.getPersonDetailsJson(personId);
    return PersonDetailsModel.fromJson(json);
  }

  Future<List<MovieModel>> getPersonFilmography(int personId) async {
    final json = await _remoteDataSource.getPersonMovieCreditsJson(personId);
    final rawCast = json['cast'];
    final rawCrew = json['crew'];
    final list = <Map<String, dynamic>>[
      if (rawCast is List)
        ...rawCast.whereType<Map>().map((e) => Map<String, dynamic>.from(e)),
      if (rawCast is! List || rawCast.isEmpty)
        if (rawCrew is List)
          ...rawCrew.whereType<Map>().map((e) => Map<String, dynamic>.from(e)),
    ];

    final seenIds = <int>{};
    final movies = <MovieModel>[];
    for (final item in list) {
      final movie = MovieModel.fromJson(item);
      if (movie.id > 0 && seenIds.add(movie.id)) {
        movies.add(movie);
      }
    }
    movies.sort((a, b) => b.voteAverage.compareTo(a.voteAverage));
    return movies.take(15).toList();
  }
}
