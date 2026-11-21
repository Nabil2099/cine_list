import 'package:flutter_dotenv/flutter_dotenv.dart';

/// TMDB API configuration and image URL helpers.
abstract final class ApiConstants {
  static String get baseUrl {
    final fromEnv = dotenv.isInitialized
        ? dotenv.env['TMDB_BASE_URL']?.trim()
        : null;
    if (fromEnv != null && fromEnv.isNotEmpty) return fromEnv;
    return const String.fromEnvironment(
      'TMDB_BASE_URL',
      defaultValue: 'https://api.themoviedb.org/3',
    );
  }

  /// TMDB v3 API key loaded from `.env` (`TMDB_API_KEY`) or `--dart-define`.
  static String get tmdbApiKey {
    final fromEnv = dotenv.isInitialized
        ? dotenv.env['TMDB_API_KEY']?.trim()
        : null;
    if (fromEnv != null && fromEnv.isNotEmpty) return fromEnv;
    return const String.fromEnvironment('TMDB_API_KEY');
  }

  /// Optional TMDB v4 Read Access Token loaded from `.env` or `--dart-define`.
  static String get tmdbAccessToken {
    final fromEnv = dotenv.isInitialized
        ? dotenv.env['TMDB_ACCESS_TOKEN']?.trim()
        : null;
    if (fromEnv != null && fromEnv.isNotEmpty) return fromEnv;
    return const String.fromEnvironment('TMDB_ACCESS_TOKEN');
  }

  /// Google Gemini API key loaded from `.env` (`GEMINI_API_KEY`).
  static String get geminiApiKey {
    final fromEnv = dotenv.isInitialized
        ? dotenv.env['GEMINI_API_KEY']?.trim()
        : null;
    if (fromEnv != null && fromEnv.isNotEmpty) return fromEnv;
    return const String.fromEnvironment('GEMINI_API_KEY');
  }

  /// Optional Google AI Studio File Search store resource name.
  static String get geminiFileSearchStore {
    final fromEnv = dotenv.isInitialized
        ? dotenv.env['GEMINI_FILE_SEARCH_STORE']?.trim()
        : null;
    if (fromEnv != null && fromEnv.isNotEmpty) return fromEnv;
    return const String.fromEnvironment('GEMINI_FILE_SEARCH_STORE');
  }

  static String get geminiModel {
    final fromEnv = dotenv.isInitialized
        ? dotenv.env['GEMINI_MODEL']?.trim()
        : null;
    if (fromEnv != null && fromEnv.isNotEmpty) return fromEnv;
    return const String.fromEnvironment(
      'GEMINI_MODEL',
      defaultValue: 'gemini-3.5-flash-lite',
    );
  }

  static const String geminiBaseUrl =
      'https://generativelanguage.googleapis.com/v1beta';

  static const String imageBaseUrl = 'https://image.tmdb.org/t/p';
  static const String posterThumbSize = 'w185';
  static const String posterCardSize = 'w342';
  static const String posterSize = 'w500';
  static const String backdropSize = 'w780';
  static const String profileSize = 'w185';
  static const String logoSize = 'w92';

  // Endpoints
  static const String trendingMoviesWeek = '/trending/movie/week';
  static const String popularMovies = '/movie/popular';
  static const String topRatedMovies = '/movie/top_rated';
  static const String nowPlayingMovies = '/movie/now_playing';
  static const String upcomingMovies = '/movie/upcoming';
  static const String discoverMovies = '/discover/movie';
  static const String searchMovies = '/search/movie';

  static String movieDetails(int movieId) => '/movie/$movieId';
  static String movieCredits(int movieId) => '/movie/$movieId/credits';
  static String personDetails(int personId) => '/person/$personId';
  static String personMovieCredits(int personId) =>
      '/person/$personId/movie_credits';
  static String movieVideos(int movieId) => '/movie/$movieId/videos';
  static String movieRecommendations(int movieId) =>
      '/movie/$movieId/recommendations';
  static String movieWatchProviders(int movieId) =>
      '/movie/$movieId/watch/providers';

  static bool get hasCredentials =>
      tmdbApiKey.trim().isNotEmpty || tmdbAccessToken.trim().isNotEmpty;

  static String? posterUrl(String? path, {String size = posterSize}) {
    if (path == null || path.trim().isEmpty) return null;
    final normalized = path.startsWith('/') ? path : '/$path';
    return '$imageBaseUrl/$size$normalized';
  }

  static String? backdropUrl(String? path) {
    if (path == null || path.trim().isEmpty) return null;
    final normalized = path.startsWith('/') ? path : '/$path';
    return '$imageBaseUrl/$backdropSize$normalized';
  }

  static String? profileUrl(String? path) {
    if (path == null || path.trim().isEmpty) return null;
    final normalized = path.startsWith('/') ? path : '/$path';
    return '$imageBaseUrl/$profileSize$normalized';
  }

  static String? logoUrl(String? path) {
    if (path == null || path.trim().isEmpty) return null;
    final normalized = path.startsWith('/') ? path : '/$path';
    return '$imageBaseUrl/$logoSize$normalized';
  }
}
