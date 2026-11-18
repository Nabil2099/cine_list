import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class AvatarPreset {
  const AvatarPreset({
    required this.key,
    required this.label,
    required this.icon,
    required this.color,
  });

  final String key;
  final String label;
  final IconData icon;
  final Color color;

  static const List<AvatarPreset> presets = [
    AvatarPreset(
      key: 'cinema',
      label: 'Cinema',
      icon: Icons.movie_filter_rounded,
      color: AppColors.pacificBlue,
    ),
    AvatarPreset(
      key: 'director',
      label: 'Director',
      icon: Icons.videocam_rounded,
      color: AppColors.khakiBeige,
    ),
    AvatarPreset(
      key: 'scifi',
      label: 'Sci-Fi',
      icon: Icons.rocket_launch_rounded,
      color: AppColors.softPeriwinkle,
    ),
    AvatarPreset(
      key: 'critic',
      label: 'Critic',
      icon: Icons.rate_review_rounded,
      color: AppColors.starAmber,
    ),
    AvatarPreset(
      key: 'noir',
      label: 'Noir',
      icon: Icons.theaters_rounded,
      color: AppColors.dustyLavender,
    ),
    AvatarPreset(
      key: 'popcorn',
      label: 'Fan',
      icon: Icons.local_movies_rounded,
      color: AppColors.success,
    ),
    AvatarPreset(
      key: 'award',
      label: 'Awards',
      icon: Icons.emoji_events_rounded,
      color: AppColors.warning,
    ),
    AvatarPreset(
      key: 'music',
      label: 'Score',
      icon: Icons.music_note_rounded,
      color: Color(0xFF7B9EA8),
    ),
  ];

  static AvatarPreset fromKey(String? key) {
    return presets.firstWhere((p) => p.key == key, orElse: () => presets.first);
  }
}

/// Community reputation rank tiers unlocked by earning karma points.
enum ReputationTier {
  viewer(0, 'Viewer', Color(0xFF847C8A), Icons.person_outline_rounded),
  critic(25, 'Critic', Color(0xFFCD7F32), Icons.star_half_rounded),
  cinephile(100, 'Cinephile', AppColors.softPeriwinkle, Icons.star_rounded),
  auteur(250, 'Auteur', AppColors.starAmber, Icons.workspace_premium_rounded),
  legend(500, 'Legend', AppColors.pacificBlue, Icons.auto_awesome_rounded);

  const ReputationTier(this.minPoints, this.label, this.color, this.icon);

  final int minPoints;
  final String label;
  final Color color;
  final IconData icon;

  static ReputationTier fromPoints(int points) {
    for (final tier in ReputationTier.values.reversed) {
      if (points >= tier.minPoints) return tier;
    }
    return ReputationTier.viewer;
  }

  ReputationTier? get nextTier {
    final idx = ReputationTier.values.indexOf(this);
    if (idx < 0 || idx >= ReputationTier.values.length - 1) return null;
    return ReputationTier.values[idx + 1];
  }

  double progressToNext(int points) {
    final next = nextTier;
    if (next == null) return 1.0;
    final span = next.minPoints - minPoints;
    if (span <= 0) return 1.0;
    return ((points - minPoints) / span).clamp(0.0, 1.0);
  }
}

/// Public community user profile stored in `users/{uid}`.
class UserProfileModel extends Equatable {
  const UserProfileModel({
    required this.uid,
    required this.displayName,
    this.bio = '',
    this.avatarKey = 'cinema',
    this.photoBase64,
    this.reputation = 0,
    this.updatedAt,
  });

  factory UserProfileModel.fromMap(String uid, Map<String, dynamic> map) {
    return UserProfileModel(
      uid: uid,
      displayName: (map['displayName'] as String?)?.trim().isNotEmpty == true
          ? (map['displayName'] as String).trim()
          : 'Movie Fan',
      bio: (map['bio'] as String?) ?? '',
      avatarKey: (map['avatarKey'] as String?) ?? 'cinema',
      photoBase64: map['photoBase64'] as String?,
      reputation: ((map['reputation'] as num?)?.toInt() ?? 0).clamp(0, 999999),
      updatedAt: _parseTimestamp(map['updatedAt']),
    );
  }

  final String uid;
  final String displayName;
  final String bio;
  final String avatarKey;
  final String? photoBase64;
  final int reputation;
  final DateTime? updatedAt;

  ReputationTier get tier => ReputationTier.fromPoints(reputation);

  Map<String, dynamic> toFirestoreMap() {
    return {
      'displayName': displayName.trim(),
      'bio': bio.trim(),
      'avatarKey': avatarKey,
      'photoBase64': photoBase64,
      'reputation': reputation,
      'updatedAt': Timestamp.fromDate(updatedAt ?? DateTime.now()),
    };
  }

  UserProfileModel copyWith({
    String? displayName,
    String? bio,
    String? avatarKey,
    String? photoBase64,
    bool clearPhoto = false,
    int? reputation,
    DateTime? updatedAt,
  }) {
    return UserProfileModel(
      uid: uid,
      displayName: displayName ?? this.displayName,
      bio: bio ?? this.bio,
      avatarKey: avatarKey ?? this.avatarKey,
      photoBase64: clearPhoto ? null : (photoBase64 ?? this.photoBase64),
      reputation: reputation ?? this.reputation,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static DateTime? _parseTimestamp(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  @override
  List<Object?> get props => [
    uid,
    displayName,
    bio,
    avatarKey,
    photoBase64,
    reputation,
    updatedAt,
  ];
}
