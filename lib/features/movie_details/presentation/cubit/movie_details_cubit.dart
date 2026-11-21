import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../shared/models/movie_summary.dart';
import '../../data/models/cast_member_model.dart';
import '../../data/models/movie_details_model.dart';
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
      MovieDetailsModel? details;
      Object? detailsError;
      List<CastMemberModel> cast = const [];
      MovieVideoModel? trailer;
      List<MovieSummary> similarMovies = const [];
      List<WatchProviderModel> watchProviders = const [];

      await Future.wait([
        () async {
          try {
            details = await _repository.getMovieDetails(movieId);
          } catch (e) {
            detailsError = e;
          }
        }(),
        () async {
          try {
            cast = await _repository.getMovieCast(movieId);
          } catch (_) {}
        }(),
        () async {
          try {
            trailer = await _repository.getMovieTrailer(movieId);
          } catch (_) {}
        }(),
        () async {
          try {
            similarMovies = await _repository.getSimilarMovies(movieId);
          } catch (_) {}
        }(),
        () async {
          try {
            watchProviders = await _repository.getWatchProviders(movieId);
          } catch (_) {}
        }(),
      ]);

      if (detailsError != null) {
        throw detailsError!;
      }
      if (details == null) {
        throw const NetworkException(
          'Unable to load movie details. Please try again.',
        );
      }

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
