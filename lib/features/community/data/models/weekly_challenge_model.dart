import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

import '../../../../shared/models/movie_summary.dart';

/// Weekly "Movie of the Week" Watch Party challenge (`community_challenges/{id}`).
class WeeklyChallengeModel extends Equatable {
  const WeeklyChallengeModel({
    required this.id,
    required this.title,
    required this.movieId,
    required this.movieTitle,
    this.posterPath,
    required this.prompt,
    this.bonusPoints = 15,
    this.participantUids = const [],
    required this.createdByUid,
    required this.createdAt,
    this.endsAt,
    this.isActive = true,
  });

  factory WeeklyChallengeModel.fromMap(String id, Map<String, dynamic> map) {
    final rawParticipants = map['participantUids'];
    final participantUids = rawParticipants is List
        ? rawParticipants.whereType<String>().toList()
        : const <String>[];

    return WeeklyChallengeModel(
      id: id,
      title: (map['title'] as String?)?.trim().isNotEmpty == true
          ? (map['title'] as String).trim()
          : 'Movie of the Week',
      movieId: (map['movieId'] as num?)?.toInt() ?? 0,
      movieTitle: (map['movieTitle'] as String?)?.trim() ?? 'Featured Film',
      posterPath: map['posterPath'] as String?,
      prompt: (map['prompt'] as String?)?.trim() ?? '',
      bonusPoints: ((map['bonusPoints'] as num?)?.toInt() ?? 15).clamp(1, 50),
      participantUids: participantUids,
      createdByUid: (map['createdByUid'] as String?) ?? '',
      createdAt: _parseTimestamp(map['createdAt']) ?? DateTime.now(),
      endsAt: _parseTimestamp(map['endsAt']),
      isActive: map['isActive'] != false,
    );
  }

  final String id;
  final String title;
  final int movieId;
  final String movieTitle;
  final String? posterPath;
  final String prompt;
  final int bonusPoints;
  final List<String> participantUids;
  final String createdByUid;
  final DateTime createdAt;
  final DateTime? endsAt;
  final bool isActive;

  bool isCompletedBy(String? uid) =>
      uid != null && participantUids.contains(uid);

  MovieSummary toMovieSummary() =>
      MovieSummary(id: movieId, title: movieTitle, posterPath: posterPath);

  Map<String, dynamic> toFirestoreMap() {
    return {
      'title': title.trim(),
      'movieId': movieId,
      'movieTitle': movieTitle.trim(),
      'posterPath': posterPath,
      'prompt': prompt.trim(),
      'bonusPoints': bonusPoints,
      'participantUids': participantUids,
      'createdByUid': createdByUid,
      'createdAt': Timestamp.fromDate(createdAt),
      'endsAt': endsAt != null ? Timestamp.fromDate(endsAt!) : null,
      'isActive': isActive,
    };
  }

  static DateTime? _parseTimestamp(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  @override
  List<Object?> get props => [
    id,
    title,
    movieId,
    movieTitle,
    posterPath,
    prompt,
    bonusPoints,
    participantUids,
    createdByUid,
    createdAt,
    endsAt,
    isActive,
  ];
}
