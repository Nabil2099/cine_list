import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../shared/models/movie_summary.dart';

enum WatchlistFilterStatus {
  wantToWatch(AppConstants.statusWantToWatch, 'Want to Watch'),
  watched(AppConstants.statusWatched, 'Watched');

  const WatchlistFilterStatus(this.value, this.label);

  final String value;
  final String label;

  static WatchlistFilterStatus fromString(String? raw) {
    return raw == AppConstants.statusWatched
        ? WatchlistFilterStatus.watched
        : WatchlistFilterStatus.wantToWatch;
  }
}

/// Firestore watchlist document model.
class WatchlistMovieModel extends Equatable {
  const WatchlistMovieModel({
    required this.movieId,
    required this.title,
    this.posterPath,
    this.backdropPath,
    this.releaseDate,
    this.voteAverage = 0.0,
    required this.status,
    required this.addedAt,
    this.watchedAt,
    this.userRating,
    this.userNote,
    this.runtimeMinutes,
    this.isUpNext = false,
    this.rewatchCount = 0,
  });

  factory WatchlistMovieModel.fromMovieSummary(
    MovieSummary movie, {
    WatchlistFilterStatus status = WatchlistFilterStatus.wantToWatch,
    DateTime? addedAt,
    DateTime? watchedAt,
    int? userRating,
    String? userNote,
    int? runtimeMinutes,
    bool isUpNext = false,
    int rewatchCount = 0,
  }) {
    final now = DateTime.now();
    return WatchlistMovieModel(
      movieId: movie.id,
      title: movie.title,
      posterPath: movie.posterPath,
      backdropPath: movie.backdropPath,
      releaseDate: movie.releaseDate,
      voteAverage: movie.voteAverage,
      status: status,
      addedAt: addedAt ?? now,
      watchedAt: status == WatchlistFilterStatus.watched
          ? (watchedAt ?? now)
          : null,
      userRating: userRating,
      userNote: userNote,
      runtimeMinutes: runtimeMinutes,
      isUpNext: isUpNext,
      rewatchCount: rewatchCount,
    );
  }

  factory WatchlistMovieModel.fromMap(Map<String, dynamic> map) {
    return WatchlistMovieModel(
      movieId: (map['movieId'] as num?)?.toInt() ?? 0,
      title: (map['title'] as String?) ?? 'Untitled',
      posterPath: map['posterPath'] as String?,
      backdropPath: map['backdropPath'] as String?,
      releaseDate: map['releaseDate'] as String?,
      voteAverage: (map['voteAverage'] as num?)?.toDouble() ?? 0.0,
      status: WatchlistFilterStatus.fromString(map['status'] as String?),
      addedAt: _parseTimestamp(map['addedAt']) ?? DateTime.now(),
      watchedAt: _parseTimestamp(map['watchedAt']),
      userRating: (map['userRating'] as num?)?.toInt(),
      userNote: map['userNote'] as String?,
      runtimeMinutes: (map['runtimeMinutes'] as num?)?.toInt(),
      isUpNext: map['isUpNext'] == true,
      rewatchCount: ((map['rewatchCount'] as num?)?.toInt() ?? 0).clamp(0, 999),
    );
  }

  final int movieId;
  final String title;
  final String? posterPath;
  final String? backdropPath;
  final String? releaseDate;
  final double voteAverage;
  final WatchlistFilterStatus status;
  final DateTime addedAt;
  final DateTime? watchedAt;
  final int? userRating;
  final String? userNote;
  final int? runtimeMinutes;
  final bool isUpNext;
  final int rewatchCount;

  bool get isWatched => status == WatchlistFilterStatus.watched;

  MovieSummary toMovieSummary() {
    return MovieSummary(
      id: movieId,
      title: title,
      posterPath: posterPath,
      backdropPath: backdropPath,
      releaseDate: releaseDate,
      voteAverage: voteAverage,
    );
  }

  Map<String, dynamic> toFirestoreMap() {
    return {
      'movieId': movieId,
      'title': title,
      'posterPath': posterPath,
      'backdropPath': backdropPath,
      'releaseDate': releaseDate,
      'voteAverage': voteAverage,
      'status': status.value,
      'addedAt': Timestamp.fromDate(addedAt),
      'watchedAt': watchedAt != null ? Timestamp.fromDate(watchedAt!) : null,
      'userRating': userRating,
      'userNote': userNote,
      'runtimeMinutes': runtimeMinutes,
      'isUpNext': isUpNext,
      'rewatchCount': rewatchCount,
    };
  }

  WatchlistMovieModel copyWith({
    WatchlistFilterStatus? status,
    DateTime? watchedAt,
    bool clearWatchedAt = false,
    int? userRating,
    bool clearUserRating = false,
    String? userNote,
    bool clearUserNote = false,
    int? runtimeMinutes,
    bool? isUpNext,
    int? rewatchCount,
  }) {
    return WatchlistMovieModel(
      movieId: movieId,
      title: title,
      posterPath: posterPath,
      backdropPath: backdropPath,
      releaseDate: releaseDate,
      voteAverage: voteAverage,
      status: status ?? this.status,
      addedAt: addedAt,
      watchedAt: clearWatchedAt ? null : (watchedAt ?? this.watchedAt),
      userRating: clearUserRating ? null : (userRating ?? this.userRating),
      userNote: clearUserNote ? null : (userNote ?? this.userNote),
      runtimeMinutes: runtimeMinutes ?? this.runtimeMinutes,
      isUpNext: isUpNext ?? this.isUpNext,
      rewatchCount: rewatchCount ?? this.rewatchCount,
    );
  }

  static DateTime? _parseTimestamp(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  @override
  List<Object?> get props => [
    movieId,
    title,
    posterPath,
    backdropPath,
    releaseDate,
    voteAverage,
    status,
    addedAt,
    watchedAt,
    userRating,
    userNote,
    runtimeMinutes,
    isUpNext,
    rewatchCount,
  ];
}
