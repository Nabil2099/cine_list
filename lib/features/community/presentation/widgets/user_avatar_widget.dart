import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/models/user_profile_model.dart';

/// Circular themed avatar supporting custom uploaded photos, preset icons,
/// reputation rank rings + badges, and a special Admin shield badge.
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.avatarKey,
    this.photoBase64,
    this.reputation = 0,
    this.isAdmin = false,
    this.isModerator = false,
    this.showRankBadge = true,
    this.radius = 22,
  });

  final String avatarKey;
  final String? photoBase64;
  final int reputation;
  final bool isAdmin;
  final bool isModerator;
  final bool showRankBadge;
  final double radius;

  Uint8List? _decodePhoto() {
    final raw = photoBase64?.trim();
    if (raw == null || raw.isEmpty) return null;
    try {
      return base64Decode(raw);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final preset = AvatarPreset.fromKey(avatarKey);
    final tier = ReputationTier.fromPoints(reputation);
    final hasRankRing = isAdmin || isModerator || tier != ReputationTier.viewer;
    final ringColor = isAdmin
        ? AppColors.khakiBeige
        : isModerator
        ? AppColors.pacificBlue
        : hasRankRing
        ? tier.color
        : preset.color;
    final photoBytes = _decodePhoto();

    final circle = Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: ringColor.withValues(alpha: hasRankRing ? 0.95 : 0.65),
          width: hasRankRing ? 2.5 : 1.4,
        ),
        boxShadow:
            isAdmin ||
                isModerator ||
                tier == ReputationTier.auteur ||
                tier == ReputationTier.legend
            ? [
                BoxShadow(
                  color: ringColor.withValues(
                    alpha: isAdmin || isModerator ? 0.4 : 0.35,
                  ),
                  blurRadius: isAdmin ? 12 : 10,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: ClipOval(
        child: photoBytes != null
            ? Image.memory(
                photoBytes,
                fit: BoxFit.cover,
                width: radius * 2,
                height: radius * 2,
                errorBuilder: (_, _, _) =>
                    _PresetCircle(preset: preset, radius: radius),
              )
            : _PresetCircle(preset: preset, radius: radius),
      ),
    );

    final showBadge =
        showRankBadge &&
        radius >= 18 &&
        (isAdmin || isModerator || tier != ReputationTier.viewer);
    if (!showBadge) {
      return circle;
    }

    final badgeSize = (radius * 0.64).clamp(16.0, 25.0);
    final badgeColor = isAdmin
        ? AppColors.khakiBeige
        : isModerator
        ? AppColors.pacificBlue
        : tier.color;
    final badgeIcon = isAdmin
        ? Icons.verified_user_rounded
        : isModerator
        ? Icons.gavel_rounded
        : tier.icon;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        circle,
        Positioned(
          right: -1,
          bottom: -1,
          child: Container(
            width: badgeSize,
            height: badgeSize,
            decoration: BoxDecoration(
              color: badgeColor,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.black, width: 1.6),
            ),
            child: Icon(
              badgeIcon,
              size: badgeSize * 0.62,
              color: AppColors.black,
            ),
          ),
        ),
      ],
    );
  }
}

class _PresetCircle extends StatelessWidget {
  const _PresetCircle({required this.preset, required this.radius});

  final AvatarPreset preset;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: preset.color.withValues(alpha: 0.2),
      child: Icon(preset.icon, color: preset.color, size: radius * 1.05),
    );
  }
}
