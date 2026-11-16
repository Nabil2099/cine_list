import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../shared/models/movie_summary.dart';
import '../../data/models/match_room_model.dart';
import '../../data/repositories/match_room_repository.dart';
import 'match_room_state.dart';

/// Manages real-time Movie Night Match Room creation, joining, and voting.
class MatchRoomCubit extends Cubit<MatchRoomState> {
  MatchRoomCubit(this._repository) : super(const MatchRoomState());

  final MatchRoomRepository _repository;
  StreamSubscription<MatchRoomModel?>? _roomSub;

  Future<void> createRoom({
    required String uid,
    required String displayName,
    List<MovieSummary> seedMovies = const [],
  }) async {
    emit(
      state.copyWith(
        status: MatchRoomStatus.loading,
        currentUid: uid,
        clearError: true,
        clearLatestMatch: true,
      ),
    );
    try {
      final room = await _repository.createRoom(
        hostUid: uid,
        hostName: displayName,
        seedMovies: seedMovies,
      );
      _subscribeToRoom(room.code, uid: uid, initialRoom: room);
    } on AppException catch (e) {
      emit(
        state.copyWith(status: MatchRoomStatus.error, errorMessage: e.message),
      );
    } catch (_) {
      emit(
        state.copyWith(
          status: MatchRoomStatus.error,
          errorMessage: 'Could not create Match Room.',
        ),
      );
    }
  }

  Future<void> joinRoom({
    required String code,
    required String uid,
    required String displayName,
  }) async {
    emit(
      state.copyWith(
        status: MatchRoomStatus.loading,
        currentUid: uid,
        clearError: true,
        clearLatestMatch: true,
      ),
    );
    try {
      final room = await _repository.joinRoom(
        code: code,
        uid: uid,
        displayName: displayName,
      );
      _subscribeToRoom(room.code, uid: uid, initialRoom: room);
    } on AppException catch (e) {
      emit(
        state.copyWith(status: MatchRoomStatus.error, errorMessage: e.message),
      );
    } catch (_) {
      emit(
        state.copyWith(
          status: MatchRoomStatus.error,
          errorMessage: 'Could not join Match Room.',
        ),
      );
    }
  }

  void _subscribeToRoom(
    String code, {
    required String uid,
    MatchRoomModel? initialRoom,
  }) {
    _roomSub?.cancel();
    final initialMatchedIds =
        initialRoom?.matchedMovies.map((m) => m.id).toSet() ?? <int>{};

    emit(
      state.copyWith(
        status: MatchRoomStatus.active,
        room: initialRoom,
        currentUid: uid,
        seenMatchIds: initialMatchedIds,
        clearError: true,
      ),
    );

    _roomSub = _repository
        .watchRoom(code)
        .listen(
          (room) {
            if (room == null) return;
            final currentMatched = room.matchedMovies;
            MovieSummary? newMatch;
            final nextSeen = Set<int>.from(state.seenMatchIds);
            for (final m in currentMatched) {
              if (nextSeen.add(m.id)) {
                newMatch = m;
              }
            }

            emit(
              state.copyWith(
                status: MatchRoomStatus.active,
                room: room,
                seenMatchIds: nextSeen,
                latestMatch: newMatch ?? state.latestMatch,
                clearError: true,
              ),
            );
          },
          onError: (Object error) {
            emit(
              state.copyWith(
                status: MatchRoomStatus.error,
                errorMessage: error is AppException
                    ? error.message
                    : 'Lost connection to Match Room.',
              ),
            );
          },
        );
  }

  Future<void> vote({required int movieId, required bool liked}) async {
    final room = state.room;
    final uid = state.currentUid;
    if (room == null || uid == null) return;

    try {
      await _repository.vote(
        code: room.code,
        uid: uid,
        movieId: movieId,
        liked: liked,
      );
    } on AppException catch (e) {
      emit(state.copyWith(errorMessage: e.message));
    }
  }

  void dismissLatestMatch() {
    emit(state.copyWith(clearLatestMatch: true));
  }

  void leaveRoom() {
    _roomSub?.cancel();
    _roomSub = null;
    emit(const MatchRoomState());
  }

  @override
  Future<void> close() {
    _roomSub?.cancel();
    return super.close();
  }
}
