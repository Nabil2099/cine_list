import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

enum ReportReason {
  sexualHarassment('sexual_harassment', 'Sexual Harassment'),
  hateSpeech('hate_speech', 'Hate Speech'),
  childAbuse('child_abuse', 'Child Abuse');

  const ReportReason(this.key, this.label);

  final String key;
  final String label;

  static ReportReason fromKey(String? key) {
    return ReportReason.values.firstWhere(
      (r) => r.key == key,
      orElse: () => ReportReason.hateSpeech,
    );
  }
}

/// Safety report filed against a community review (`reports/{reviewId}_{reporterUid}`).
class ReviewReportModel extends Equatable {
  const ReviewReportModel({
    required this.id,
    required this.reviewId,
    required this.reportedUid,
    required this.reportedAuthorName,
    required this.movieTitle,
    required this.reviewComment,
    required this.reporterUid,
    required this.reason,
    this.details = '',
    required this.createdAt,
    this.status = 'pending',
  });

  final String id;
  final String reviewId;
  final String reportedUid;
  final String reportedAuthorName;
  final String movieTitle;
  final String reviewComment;
  final String reporterUid;
  final ReportReason reason;
  final String details;
  final DateTime createdAt;
  final String status;

  bool get isPending => status == 'pending';

  static String docIdFor(String reviewId, String reporterUid) =>
      '${reviewId}_$reporterUid';

  Map<String, dynamic> toFirestoreMap() {
    return {
      'reviewId': reviewId,
      'reportedUid': reportedUid,
      'reportedAuthorName': reportedAuthorName,
      'movieTitle': movieTitle,
      'reviewComment': reviewComment,
      'reporterUid': reporterUid,
      'reason': reason.key,
      'details': details.trim(),
      'createdAt': Timestamp.fromDate(createdAt),
      'status': status,
    };
  }

  factory ReviewReportModel.fromMap(String id, Map<String, dynamic> map) {
    final rawCreatedAt = map['createdAt'];
    final createdAt = rawCreatedAt is Timestamp
        ? rawCreatedAt.toDate()
        : DateTime.now();

    return ReviewReportModel(
      id: id,
      reviewId: (map['reviewId'] as String?) ?? '',
      reportedUid: (map['reportedUid'] as String?) ?? '',
      reportedAuthorName:
          (map['reportedAuthorName'] as String?) ?? 'Unknown User',
      movieTitle: (map['movieTitle'] as String?) ?? 'Untitled',
      reviewComment: (map['reviewComment'] as String?) ?? '',
      reporterUid: (map['reporterUid'] as String?) ?? '',
      reason: ReportReason.fromKey(map['reason'] as String?),
      details: (map['details'] as String?) ?? '',
      createdAt: createdAt,
      status: (map['status'] as String?) ?? 'pending',
    );
  }

  @override
  List<Object?> get props => [
    id,
    reviewId,
    reportedUid,
    reportedAuthorName,
    movieTitle,
    reviewComment,
    reporterUid,
    reason,
    details,
    createdAt,
    status,
  ];
}

