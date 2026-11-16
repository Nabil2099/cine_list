import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../shared/models/movie_summary.dart';
import '../../../discover/data/models/movie_model.dart';
import '../../data/models/cast_member_model.dart';
import '../../data/models/movie_video_model.dart';
import '../../data/models/watch_provider_model.dart';
import '../../data/repositories/movie_details_repository.dart';
import 'movie_details_state.dart';

/// Fetches TMDB movie details, cast, trailer, watch providers, and similar picks.
class MovieDetailsCubit extends Cubit<MovieDetailsState> {
  MovieDetailsCubit(this._repository) : super(const MovieDetailsState());

  final MovieDetailsRepository _repository;

  Future<void> loadMovie(int movieId) async {
    emit(
      state.copyWith(
        status: MovieDetailsStatus.loading,
        clearError: true,
        clearTrailer: true,
      ),
    );

    try {
      final details = await _repository.getMovieDetails(movieId);

      List<CastMemberModel> cast = const [];
      MovieVideoModel? trailer;
      List<MovieSummary> similarMovies = const [];
      List<WatchProviderModel> watchProviders = const [];

      await Future.wait([
        _repository.getMovieCast(movieId).then((v) => cast = v).catchError((
          Object _,
        ) {
          return const <CastMemberModel>[];
        }),
        _repository
            .getMovieTrailer(movieId)
            .then((v) => trailer = v)
            .catchError((Object _) {
              return null;
            }),
        _repository
            .getSimilarMovies(movieId)
            .then((v) => similarMovies = v)
            .catchError((Object _) {
              return const <MovieModel>[];
            }),
        _repository
            .getWatchProviders(movieId)
            .then((v) => watchProviders = v)
            .catchError((Object _) {
              return const <WatchProviderModel>[];
            }),
      ]);

      if (isClosed) return;
      emit(
        state.copyWith(
          status: MovieDetailsStatus.loaded,
          details: details,
          cast: cast,
          trailer: trailer,
          similarMovies: similarMovies,
          watchProviders: watchProviders,
          clearError: true,
        ),
      );
    } on AppException catch (e) {
      if (isClosed) return;
      emit(
        state.copyWith(
          status: MovieDetailsStatus.error,
          errorMessage: e.message,
        ),
      );
    } catch (_) {
      if (isClosed) return;
      emit(
        state.copyWith(
          status: MovieDetailsStatus.error,
          errorMessage: 'Unable to load movie details. Please try again.',
        ),
      );
    }
  }
}
