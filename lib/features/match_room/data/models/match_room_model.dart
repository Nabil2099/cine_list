import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

import '../../../../shared/models/movie_summary.dart';

/// Real-time multiplayer Movie Night Match Room stored at `match_rooms/{code}`.
class MatchRoomModel extends Equatable {
  const MatchRoomModel({
    required this.code,
    required this.hostUid,
    required this.hostName,
    this.participantUids = const [],
    this.participantNames = const {},
    this.deck = const [],
    this.likesByUser = const {},
    this.passesByUser = const {},
    required this.createdAt,
  });

  final String code;
  final String hostUid;
  final String hostName;
  final List<String> participantUids;
  final Map<String, String> participantNames;
  final List<MovieSummary> deck;
  final Map<String, List<int>> likesByUser;
  final Map<String, List<int>> passesByUser;
  final DateTime createdAt;

  /// Returns movies liked by at least 2 participants in the room.
  List<MovieSummary> get matchedMovies {
    if (participantUids.length < 2) return const [];
    final likeCounts = <int, int>{};
    for (final uid in participantUids) {
      final liked = likesByUser[uid]?.toSet() ?? const <int>{};
      for (final movieId in liked) {
        likeCounts[movieId] = (likeCounts[movieId] ?? 0) + 1;
      }
    }
    return deck.where((m) => (likeCounts[m.id] ?? 0) >= 2).toList();
  }

  List<MovieSummary> unvotedMoviesFor(String uid) {
    final liked = likesByUser[uid]?.toSet() ?? const <int>{};
    final passed = passesByUser[uid]?.toSet() ?? const <int>{};
    return deck
        .where((m) => !liked.contains(m.id) && !passed.contains(m.id))
        .toList();
  }

  int votedCountFor(String uid) {
    final liked = likesByUser[uid]?.toSet() ?? const <int>{};
    final passed = passesByUser[uid]?.toSet() ?? const <int>{};
    return liked.union(passed).length;
  }

  Map<String, dynamic> toFirestoreMap() {
    return {
      'code': code,
      'hostUid': hostUid,
      'hostName': hostName,
      'participantUids': participantUids,
      'participantNames': participantNames,
      'deck': deck
          .map(
            (m) => {
              'id': m.id,
              'title': m.title,
              'posterPath': m.posterPath,
              'backdropPath': m.backdropPath,
              'releaseDate': m.releaseDate,
              'voteAverage': m.voteAverage,
              'overview': m.overview,
              'genreIds': m.genreIds,
            },
          )
          .toList(),
      'likesByUser': likesByUser,
      'passesByUser': passesByUser,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory MatchRoomModel.fromMap(String code, Map<String, dynamic> map) {
    final rawParticipants = map['participantUids'];
    final participantUids = rawParticipants is List
        ? rawParticipants.whereType<String>().toList()
        : const <String>[];

    final rawNames = map['participantNames'];
    final participantNames = rawNames is Map
        ? rawNames.map(
            (k, v) => MapEntry(k.toString(), v?.toString() ?? 'Guest'),
          )
        : const <String, String>{};

    final rawDeck = map['deck'];
    final deck = rawDeck is List
        ? rawDeck
              .whereType<Map>()
              .map((item) {
                final m = Map<String, dynamic>.from(item);
                final rawGenres = m['genreIds'];
                return MovieSummary(
                  id: (m['id'] as num?)?.toInt() ?? 0,
                  title: (m['title'] as String?) ?? 'Untitled',
                  posterPath: m['posterPath'] as String?,
                  backdropPath: m['backdropPath'] as String?,
                  releaseDate: m['releaseDate'] as String?,
                  voteAverage: (m['voteAverage'] as num?)?.toDouble() ?? 0.0,
                  overview: (m['overview'] as String?) ?? '',
                  genreIds: rawGenres is List
                      ? rawGenres
                            .whereType<num>()
                            .map((e) => e.toInt())
                            .toList()
                      : const [],
                );
              })
              .where((m) => m.id > 0)
              .toList()
        : const <MovieSummary>[];

    Map<String, List<int>> parseVotes(dynamic raw) {
      if (raw is! Map) return const {};
      final result = <String, List<int>>{};
      raw.forEach((key, value) {
        if (value is List) {
          result[key.toString()] = value
              .whereType<num>()
              .map((e) => e.toInt())
              .toList();
        }
      });
      return result;
    }

    final rawCreatedAt = map['createdAt'];
    final createdAt = rawCreatedAt is Timestamp
        ? rawCreatedAt.toDate()
        : DateTime.now();

    return MatchRoomModel(
      code: (map['code'] as String?) ?? code,
      hostUid: (map['hostUid'] as String?) ?? '',
      hostName: (map['hostName'] as String?) ?? 'Host',
      participantUids: participantUids,
      participantNames: participantNames,
      deck: deck,
      likesByUser: parseVotes(map['likesByUser']),
      passesByUser: parseVotes(map['passesByUser']),
      createdAt: createdAt,
    );
  }

  @override
  List<Object?> get props => [
    code,
    hostUid,
    hostName,
    participantUids,
    participantNames,
    deck,
    likesByUser,
    passesByUser,
    createdAt,
  ];
}
