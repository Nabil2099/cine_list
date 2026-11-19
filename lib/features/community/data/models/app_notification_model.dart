import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

enum AppNotificationType {
  like('like'),
  reply('reply'),
  follow('follow');

  const AppNotificationType(this.value);

  final String value;

  static AppNotificationType fromString(String? raw) {
    switch (raw) {
      case 'reply':
        return AppNotificationType.reply;
      case 'follow':
        return AppNotificationType.follow;
      default:
        return AppNotificationType.like;
    }
  }
}

/// Real-time activity notification stored under `users/{uid}/notifications/{id}`.
class AppNotificationModel extends Equatable {
  const AppNotificationModel({
    required this.id,
    required this.type,
    required this.actorUid,
    required this.actorName,
    this.actorAvatarKey = 'cinema',
    this.movieId,
    this.movieTitle,
    this.reviewId,
    this.snippet,
    this.isRead = false,
    required this.createdAt,
  });

  factory AppNotificationModel.fromMap(String id, Map<String, dynamic> map) {
    return AppNotificationModel(
      id: id,
      type: AppNotificationType.fromString(map['type'] as String?),
      actorUid: (map['actorUid'] as String?) ?? '',
      actorName: (map['actorName'] as String?) ?? 'Movie Fan',
      actorAvatarKey: (map['actorAvatarKey'] as String?) ?? 'cinema',
      movieId: (map['movieId'] as num?)?.toInt(),
      movieTitle: map['movieTitle'] as String?,
      reviewId: map['reviewId'] as String?,
      snippet: map['snippet'] as String?,
      isRead: map['isRead'] == true,
      createdAt: _parseTimestamp(map['createdAt']) ?? DateTime.now(),
    );
  }

  final String id;
  final AppNotificationType type;
  final String actorUid;
  final String actorName;
  final String actorAvatarKey;
  final int? movieId;
  final String? movieTitle;
  final String? reviewId;
  final String? snippet;
  final bool isRead;
  final DateTime createdAt;

  AppNotificationModel copyWith({bool? isRead}) {
    return AppNotificationModel(
      id: id,
      type: type,
      actorUid: actorUid,
      actorName: actorName,
      actorAvatarKey: actorAvatarKey,
      movieId: movieId,
      movieTitle: movieTitle,
      reviewId: reviewId,
      snippet: snippet,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toFirestoreMap() {
    return {
      'type': type.value,
      'actorUid': actorUid,
      'actorName': actorName.trim(),
      'actorAvatarKey': actorAvatarKey,
      if (movieId != null) 'movieId': movieId,
      if (movieTitle != null) 'movieTitle': movieTitle,
      if (reviewId != null) 'reviewId': reviewId,
      if (snippet != null && snippet!.trim().isNotEmpty)
        'snippet': snippet!.trim(),
      'isRead': isRead,
      'createdAt': Timestamp.fromDate(createdAt),
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
    type,
    actorUid,
    actorName,
    actorAvatarKey,
    movieId,
    movieTitle,
    reviewId,
    snippet,
    isRead,
    createdAt,
  ];
}
