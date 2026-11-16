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

/// Public community user profile stored in `users/{uid}`.
class UserProfileModel extends Equatable {
  const UserProfileModel({
    required this.uid,
    required this.displayName,
    this.bio = '',
    this.avatarKey = 'cinema',
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
      updatedAt: _parseTimestamp(map['updatedAt']),
    );
  }

  final String uid;
  final String displayName;
  final String bio;
  final String avatarKey;
  final DateTime? updatedAt;

  Map<String, dynamic> toFirestoreMap() {
    return {
      'displayName': displayName.trim(),
      'bio': bio.trim(),
      'avatarKey': avatarKey,
      'updatedAt': Timestamp.fromDate(updatedAt ?? DateTime.now()),
    };
  }

  UserProfileModel copyWith({
    String? displayName,
    String? bio,
    String? avatarKey,
    DateTime? updatedAt,
  }) {
    return UserProfileModel(
      uid: uid,
      displayName: displayName ?? this.displayName,
      bio: bio ?? this.bio,
      avatarKey: avatarKey ?? this.avatarKey,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static DateTime? _parseTimestamp(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  @override
  List<Object?> get props => [uid, displayName, bio, avatarKey, updatedAt];
}
