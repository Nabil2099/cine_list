import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// Reply comment stored under `reviews/{reviewId}/comments/{commentId}`.
class ReviewCommentModel extends Equatable {
  const ReviewCommentModel({
    required this.id,
    required this.reviewId,
    required this.uid,
    required this.authorName,
    this.authorAvatarKey = 'cinema',
    required this.text,
    required this.createdAt,
  });

  factory ReviewCommentModel.fromMap(
    String id,
    String reviewId,
    Map<String, dynamic> map,
  ) {
    return ReviewCommentModel(
      id: id,
      reviewId: reviewId,
      uid: (map['uid'] as String?) ?? '',
      authorName: (map['authorName'] as String?) ?? 'Movie Fan',
      authorAvatarKey: (map['authorAvatarKey'] as String?) ?? 'cinema',
      text: (map['text'] as String?) ?? '',
      createdAt: _parseTimestamp(map['createdAt']) ?? DateTime.now(),
    );
  }

  final String id;
  final String reviewId;
  final String uid;
  final String authorName;
  final String authorAvatarKey;
  final String text;
  final DateTime createdAt;

  Map<String, dynamic> toFirestoreMap() {
    return {
      'uid': uid,
      'authorName': authorName.trim(),
      'authorAvatarKey': authorAvatarKey,
      'text': text.trim(),
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
    reviewId,
    uid,
    authorName,
    authorAvatarKey,
    text,
    createdAt,
  ];
}
