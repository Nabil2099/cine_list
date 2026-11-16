import 'package:equatable/equatable.dart';

import '../../../../shared/models/movie_summary.dart';
import '../../data/models/cast_member_model.dart';
import '../../data/models/movie_details_model.dart';
import '../../data/models/movie_video_model.dart';
import '../../data/models/watch_provider_model.dart';

enum MovieDetailsStatus { initial, loading, loaded, error }

class MovieDetailsState extends Equatable {
  const MovieDetailsState({
    this.status = MovieDetailsStatus.initial,
    this.details,
    this.cast = const [],
    this.trailer,
    this.similarMovies = const [],
    this.watchProviders = const [],
    this.errorMessage,
  });

  final MovieDetailsStatus status;
  final MovieDetailsModel? details;
  final List<CastMemberModel> cast;
  final MovieVideoModel? trailer;
  final List<MovieSummary> similarMovies;
  final List<WatchProviderModel> watchProviders;
  final String? errorMessage;

  MovieDetailsState copyWith({
    MovieDetailsStatus? status,
    MovieDetailsModel? details,
    List<CastMemberModel>? cast,
    MovieVideoModel? trailer,
    bool clearTrailer = false,
    List<MovieSummary>? similarMovies,
    List<WatchProviderModel>? watchProviders,
    String? errorMessage,
    bool clearError = false,
  }) {
    return MovieDetailsState(
      status: status ?? this.status,
      details: details ?? this.details,
      cast: cast ?? this.cast,
      trailer: clearTrailer ? null : (trailer ?? this.trailer),
      similarMovies: similarMovies ?? this.similarMovies,
      watchProviders: watchProviders ?? this.watchProviders,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [
    status,
    details,
    cast,
    trailer,
    similarMovies,
    watchProviders,
    errorMessage,
  ];
}
