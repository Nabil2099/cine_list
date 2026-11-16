import 'package:equatable/equatable.dart';

import '../../../../shared/models/movie_summary.dart';
import '../../data/models/match_room_model.dart';

enum MatchRoomStatus { idle, loading, active, error }

class MatchRoomState extends Equatable {
  const MatchRoomState({
    this.status = MatchRoomStatus.idle,
    this.room,
    this.currentUid,
    this.latestMatch,
    this.seenMatchIds = const {},
    this.errorMessage,
  });

  final MatchRoomStatus status;
  final MatchRoomModel? room;
  final String? currentUid;
  final MovieSummary? latestMatch;
  final Set<int> seenMatchIds;
  final String? errorMessage;

  List<MovieSummary> get unvotedMovies {
    final activeRoom = room;
    final uid = currentUid;
    if (activeRoom == null || uid == null) return const [];
    return activeRoom.unvotedMoviesFor(uid);
  }

  MovieSummary? get currentCard => unvotedMovies.firstOrNull;

  List<MovieSummary> get matchedMovies => room?.matchedMovies ?? const [];

  MatchRoomState copyWith({
    MatchRoomStatus? status,
    MatchRoomModel? room,
    bool clearRoom = false,
    String? currentUid,
    MovieSummary? latestMatch,
    bool clearLatestMatch = false,
    Set<int>? seenMatchIds,
    String? errorMessage,
    bool clearError = false,
  }) {
    return MatchRoomState(
      status: status ?? this.status,
      room: clearRoom ? null : (room ?? this.room),
      currentUid: currentUid ?? this.currentUid,
      latestMatch: clearLatestMatch ? null : (latestMatch ?? this.latestMatch),
      seenMatchIds: seenMatchIds ?? this.seenMatchIds,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [
    status,
    room,
    currentUid,
    latestMatch,
    seenMatchIds,
    errorMessage,
  ];
}
