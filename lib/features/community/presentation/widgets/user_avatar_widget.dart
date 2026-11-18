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
        ? AppColors.creatorEmerald
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
          width: isAdmin
              ? (radius * 0.13).clamp(2.4, 4.2)
              : (hasRankRing ? 2.5 : 1.4),
        ),
        boxShadow:
            isAdmin ||
                isModerator ||
                tier == ReputationTier.auteur ||
                tier == ReputationTier.legend
            ? [
                BoxShadow(
                  color: ringColor.withValues(
                    alpha: isAdmin || isModerator ? 0.42 : 0.35,
                  ),
                  blurRadius: isAdmin ? 14 : 10,
                  spreadRadius: isAdmin ? 1.5 : 1,
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

    if (showRankBadge && isAdmin) {
      final emblemSize = (radius * 0.72).clamp(15.0, 28.0);
      final maskSize = (radius * 0.62).clamp(13.0, 24.0);
      return Stack(
        clipBehavior: Clip.none,
        children: [
          circle,
          Positioned(
            right: -emblemSize * 0.12,
            top: -emblemSize * 0.12,
            child: Container(
              width: emblemSize,
              height: emblemSize,
              decoration: BoxDecoration(
                color: AppColors.surfaceBase,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.creatorEmerald,
                  width: (radius * 0.08).clamp(1.6, 2.8),
                ),
              ),
              child: CustomPaint(
                painter: _CreatorWingEmblemPainter(
                  color: AppColors.creatorEmerald,
                ),
              ),
            ),
          ),
          if (radius >= 20)
            Positioned(
              left: -maskSize * 0.14,
              bottom: -maskSize * 0.08,
              child: SizedBox(
                width: maskSize,
                height: maskSize,
                child: CustomPaint(
                  painter: _CreatorMaskEmblemPainter(
                    color: AppColors.creatorEmerald,
                    cutoutColor: AppColors.surfaceBase,
                  ),
                ),
              ),
            ),
        ],
      );
    }

    final showBadge =
        showRankBadge &&
        radius >= 18 &&
        (isModerator || tier != ReputationTier.viewer);
    if (!showBadge) {
      return circle;
    }

    final badgeSize = (radius * 0.64).clamp(16.0, 25.0);
    final badgeColor = isModerator ? AppColors.pacificBlue : tier.color;
    final badgeIcon = isModerator ? Icons.gavel_rounded : tier.icon;

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

/// Sovereign Creator crest icon matching the emerald winged emblem.
class CreatorEmblemIcon extends StatelessWidget {
  const CreatorEmblemIcon({
    super.key,
    this.size = 14,
    this.color = AppColors.creatorEmerald,
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _CreatorWingEmblemPainter(color: color)),
    );
  }
}

/// Top-right Creator emblem: angular winged/horned shards with center triangle.
class _CreatorWingEmblemPainter extends CustomPainter {
  const _CreatorWingEmblemPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final w = size.width;
    final h = size.height;

    final leftWing = Path()
      ..moveTo(w * 0.16, h * 0.25)
      ..lineTo(w * 0.36, h * 0.42)
      ..lineTo(w * 0.44, h * 0.62)
      ..lineTo(w * 0.28, h * 0.72)
      ..lineTo(w * 0.14, h * 0.48)
      ..close();

    final rightWing = Path()
      ..moveTo(w * 0.84, h * 0.25)
      ..lineTo(w * 0.86, h * 0.48)
      ..lineTo(w * 0.72, h * 0.72)
      ..lineTo(w * 0.56, h * 0.62)
      ..lineTo(w * 0.64, h * 0.42)
      ..close();

    final centerTri = Path()
      ..moveTo(w * 0.50, h * 0.56)
      ..lineTo(w * 0.56, h * 0.72)
      ..lineTo(w * 0.44, h * 0.72)
      ..close();

    canvas
      ..drawPath(leftWing, paint)
      ..drawPath(rightWing, paint)
      ..drawPath(centerTri, paint);
  }

  @override
  bool shouldRepaint(covariant _CreatorWingEmblemPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Bottom-left Creator emblem: stylized geometric mask silhouette.
class _CreatorMaskEmblemPainter extends CustomPainter {
  const _CreatorMaskEmblemPainter({
    required this.color,
    required this.cutoutColor,
  });

  final Color color;
  final Color cutoutColor;

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final cutout = Paint()
      ..color = cutoutColor
      ..style = PaintingStyle.fill;

    final w = size.width;
    final h = size.height;

    final mask = Path()
      ..moveTo(w * 0.22, h * 0.14)
      ..lineTo(w * 0.36, h * 0.26)
      ..lineTo(w * 0.64, h * 0.26)
      ..lineTo(w * 0.78, h * 0.14)
      ..lineTo(w * 0.88, h * 0.40)
      ..lineTo(w * 0.76, h * 0.82)
      ..lineTo(w * 0.50, h * 0.92)
      ..lineTo(w * 0.24, h * 0.82)
      ..lineTo(w * 0.12, h * 0.40)
      ..close();

    canvas.drawPath(mask, fill);

    // Eye slits
    final leftEye = Path()
      ..moveTo(w * 0.26, h * 0.46)
      ..lineTo(w * 0.43, h * 0.50)
      ..lineTo(w * 0.40, h * 0.56)
      ..lineTo(w * 0.28, h * 0.54)
      ..close();
    final rightEye = Path()
      ..moveTo(w * 0.74, h * 0.46)
      ..lineTo(w * 0.72, h * 0.54)
      ..lineTo(w * 0.60, h * 0.56)
      ..lineTo(w * 0.57, h * 0.50)
      ..close();

    // Mouth grill bar
    final mouth = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.34, h * 0.68, w * 0.32, h * 0.11),
      Radius.circular(w * 0.04),
    );

    canvas
      ..drawPath(leftEye, cutout)
      ..drawPath(rightEye, cutout)
      ..drawRRect(mouth, cutout);
  }

  @override
  bool shouldRepaint(covariant _CreatorMaskEmblemPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.cutoutColor != cutoutColor;
}
