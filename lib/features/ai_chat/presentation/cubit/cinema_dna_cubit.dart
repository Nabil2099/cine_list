import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../shared/models/movie_summary.dart';
import '../../../discover/data/repositories/discover_repository.dart';
import '../../../watchlist/data/models/watchlist_movie_model.dart';
import '../../data/models/cinema_dna_model.dart';
import '../../data/repositories/ai_chat_repository.dart';

enum CinemaDnaStatus { initial, loading, loaded, error }

class CinemaDnaState extends Equatable {
  const CinemaDnaState({
    this.status = CinemaDnaStatus.initial,
    this.profile,
    this.errorMessage,
  });

  final CinemaDnaStatus status;
  final CinemaDnaProfile? profile;
  final String? errorMessage;

  CinemaDnaState copyWith({
    CinemaDnaStatus? status,
    CinemaDnaProfile? profile,
    String? errorMessage,
    bool clearError = false,
  }) {
    return CinemaDnaState(
      status: status ?? this.status,
      profile: profile ?? this.profile,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [status, profile, errorMessage];
}

/// Generates the user's Cinema DNA profile and resolves blind-spot TMDB posters
/// concurrently.
class CinemaDnaCubit extends Cubit<CinemaDnaState> {
  CinemaDnaCubit(this._aiRepository, this._discoverRepository)
    : super(const CinemaDnaState());

  final AiChatRepository _aiRepository;
  final DiscoverRepository _discoverRepository;

  Future<void> analyze(List<WatchlistMovieModel> watchlist) async {
    emit(state.copyWith(status: CinemaDnaStatus.loading, clearError: true));

    try {
      final dna = await _aiRepository.analyzeCinemaDna(watchlist: watchlist);
      final resolvedBlindSpots = await Future.wait(
        dna.blindSpots.map((spot) async {
          try {
            final res = await _discoverRepository.searchMovies(
              query: spot.title,
              page: 1,
            );
            if (res.results.isEmpty) return spot;
            MovieSummary match = res.results.first;
            if (spot.year != null) {
              for (final candidate in res.results) {
                if ((candidate.releaseDate ?? '').startsWith(spot.year!)) {
                  match = candidate;
                  break;
                }
              }
            }
            return spot.copyWith(movie: match);
          } catch (_) {
            return spot;
          }
        }),
      );

      if (isClosed) return;
      emit(
        state.copyWith(
          status: CinemaDnaStatus.loaded,
          profile: dna.copyWith(blindSpots: resolvedBlindSpots),
          clearError: true,
        ),
      );
    } on AppException catch (e) {
      if (isClosed) return;
      emit(
        state.copyWith(
          status: CinemaDnaStatus.error,
          errorMessage: e.message,
        ),
      );
    } catch (_) {
      if (isClosed) return;
      emit(
        state.copyWith(
          status: CinemaDnaStatus.error,
          errorMessage: 'Unable to analyze Cinema DNA right now.',
        ),
      );
    }
  }
}
