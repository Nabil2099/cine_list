import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

import '../../../../shared/models/movie_summary.dart';

/// Public movie review stored in `reviews/{movieId}_{uid}`.
class MovieReviewModel extends Equatable {
  const MovieReviewModel({
    required this.id,
    required this.movieId,
    required this.movieTitle,
    this.posterPath,
    required this.uid,
    required this.authorName,
    this.authorAvatarKey = 'cinema',
    required this.rating,
    required this.comment,
    required this.createdAt,
    this.likedBy = const [],
    this.dislikedBy = const [],
    this.hasSpoilers = false,
    this.isVerifiedWatch = false,
    this.replyCount = 0,
    this.mediaType = MediaType.movie,
  });

  factory MovieReviewModel.fromMap(String id, Map<String, dynamic> map) {
    final rawLikes = map['likedBy'];
    final likedBy = rawLikes is List
        ? rawLikes.whereType<String>().toList()
        : const <String>[];
    final rawDislikes = map['dislikedBy'];
    final dislikedBy = rawDislikes is List
        ? rawDislikes.whereType<String>().toList()
        : const <String>[];

    return MovieReviewModel(
      id: id,
      movieId: (map['movieId'] as num?)?.toInt() ?? 0,
      movieTitle: (map['movieTitle'] as String?) ?? 'Untitled',
      posterPath: map['posterPath'] as String?,
      uid: (map['uid'] as String?) ?? '',
      authorName: (map['authorName'] as String?) ?? 'Movie Fan',
      authorAvatarKey: (map['authorAvatarKey'] as String?) ?? 'cinema',
      rating: ((map['rating'] as num?)?.toInt() ?? 5).clamp(1, 5),
      comment: (map['comment'] as String?) ?? '',
      createdAt: _parseTimestamp(map['createdAt']) ?? DateTime.now(),
      likedBy: likedBy,
      dislikedBy: dislikedBy,
      hasSpoilers: map['hasSpoilers'] == true,
      isVerifiedWatch: map['isVerifiedWatch'] == true,
      replyCount: ((map['replyCount'] as num?)?.toInt() ?? 0).clamp(0, 999999),
      mediaType: MediaType.fromString(map['mediaType'] as String?),
    );
  }

  final String id;
  final int movieId;
  final String movieTitle;
  final String? posterPath;
  final String uid;
  final String authorName;
  final String authorAvatarKey;
  final int rating;
  final String comment;
  final DateTime createdAt;
  final List<String> likedBy;
  final List<String> dislikedBy;
  final bool hasSpoilers;
  final bool isVerifiedWatch;
  final int replyCount;
  final MediaType mediaType;

  bool isLikedBy(String? uid) => uid != null && likedBy.contains(uid);
  bool isDislikedBy(String? uid) => uid != null && dislikedBy.contains(uid);

  static String docIdFor(int movieId, String uid) => '${movieId}_$uid';

  Map<String, dynamic> toFirestoreMap() {
    return {
      'movieId': movieId,
      'movieTitle': movieTitle,
      'posterPath': posterPath,
      'uid': uid,
      'authorName': authorName.trim(),
      'authorAvatarKey': authorAvatarKey,
      'rating': rating.clamp(1, 5),
      'comment': comment.trim(),
      'createdAt': Timestamp.fromDate(createdAt),
      'likedBy': likedBy,
      'dislikedBy': dislikedBy,
      'hasSpoilers': hasSpoilers,
      'isVerifiedWatch': isVerifiedWatch,
      'replyCount': replyCount,
      'mediaType': mediaType.name,
    };
  }

  static DateTime? _parseTimestamp(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  MovieReviewModel copyWith({
    List<String>? likedBy,
    List<String>? dislikedBy,
    bool? hasSpoilers,
    bool? isVerifiedWatch,
    int? replyCount,
  }) {
    return MovieReviewModel(
      id: id,
      movieId: movieId,
      movieTitle: movieTitle,
      posterPath: posterPath,
      uid: uid,
      authorName: authorName,
      authorAvatarKey: authorAvatarKey,
      rating: rating,
      comment: comment,
      createdAt: createdAt,
      likedBy: likedBy ?? this.likedBy,
      dislikedBy: dislikedBy ?? this.dislikedBy,
      hasSpoilers: hasSpoilers ?? this.hasSpoilers,
      isVerifiedWatch: isVerifiedWatch ?? this.isVerifiedWatch,
      replyCount: replyCount ?? this.replyCount,
    );
  }

  @override
  List<Object?> get props => [
    id,
    movieId,
    movieTitle,
    posterPath,
    uid,
    authorName,
    authorAvatarKey,
    rating,
    comment,
    createdAt,
    likedBy,
    dislikedBy,
    hasSpoilers,
    isVerifiedWatch,
    replyCount,
  ];
}
