import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// Admin/moderator-created poll pinned at the top of Community (`community_polls/{id}`).
class CommunityPollModel extends Equatable {
  const CommunityPollModel({
    required this.id,
    required this.question,
    required this.options,
    this.votesByUid = const {},
    required this.createdByUid,
    required this.createdAt,
    this.isPinned = true,
  });

  factory CommunityPollModel.fromMap(String id, Map<String, dynamic> map) {
    final rawOptions = map['options'];
    final options = rawOptions is List
        ? rawOptions
              .whereType<String>()
              .map((o) => o.trim())
              .where((o) => o.isNotEmpty)
              .toList()
        : const <String>[];

    final rawVotes = map['votesByUid'];
    final votesByUid = <String, int>{};
    if (rawVotes is Map) {
      for (final entry in rawVotes.entries) {
        final key = entry.key;
        final val = entry.value;
        if (key is String && val is num) {
          final idx = val.toInt();
          if (idx >= 0 && idx < options.length) {
            votesByUid[key] = idx;
          }
        }
      }
    }

    final rawCreatedAt = map['createdAt'];
    final createdAt = rawCreatedAt is Timestamp
        ? rawCreatedAt.toDate()
        : DateTime.now();

    return CommunityPollModel(
      id: id,
      question: (map['question'] as String?)?.trim() ?? '',
      options: options,
      votesByUid: votesByUid,
      createdByUid: (map['createdByUid'] as String?) ?? '',
      createdAt: createdAt,
      isPinned: map['isPinned'] != false,
    );
  }

  final String id;
  final String question;
  final List<String> options;
  final Map<String, int> votesByUid;
  final String createdByUid;
  final DateTime createdAt;
  final bool isPinned;

  int get totalVotes => votesByUid.length;

  int? selectedOptionFor(String? uid) {
    if (uid == null) return null;
    return votesByUid[uid];
  }

  int votesForOption(int index) {
    var count = 0;
    for (final v in votesByUid.values) {
      if (v == index) count++;
    }
    return count;
  }

  double percentageForOption(int index) {
    if (votesByUid.isEmpty) return 0;
    return votesForOption(index) / votesByUid.length;
  }

  CommunityPollModel copyWith({Map<String, int>? votesByUid, bool? isPinned}) {
    return CommunityPollModel(
      id: id,
      question: question,
      options: options,
      votesByUid: votesByUid ?? this.votesByUid,
      createdByUid: createdByUid,
      createdAt: createdAt,
      isPinned: isPinned ?? this.isPinned,
    );
  }

  Map<String, dynamic> toFirestoreMap() {
    return {
      'question': question.trim(),
      'options': options
          .map((o) => o.trim())
          .where((o) => o.isNotEmpty)
          .toList(),
      'votesByUid': votesByUid,
      'createdByUid': createdByUid,
      'createdAt': Timestamp.fromDate(createdAt),
      'isPinned': isPinned,
    };
  }

  @override
  List<Object?> get props => [
    id,
    question,
    options,
    votesByUid,
    createdByUid,
    createdAt,
    isPinned,
  ];
}
