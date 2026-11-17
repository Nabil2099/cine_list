import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../data/models/user_profile_model.dart';

/// Circular themed avatar supporting both custom uploaded photos and presets.
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.avatarKey,
    this.photoBase64,
    this.radius = 22,
  });

  final String avatarKey;
  final String? photoBase64;
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
    final photoBytes = _decodePhoto();

    if (photoBytes != null) {
      return Container(
        width: radius * 2,
        height: radius * 2,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: preset.color.withValues(alpha: 0.75),
            width: 1.6,
          ),
        ),
        child: ClipOval(
          child: Image.memory(
            photoBytes,
            fit: BoxFit.cover,
            width: radius * 2,
            height: radius * 2,
            errorBuilder: (_, _, _) => _PresetCircle(
              preset: preset,
              radius: radius,
            ),
          ),
        ),
      );
    }

    return _PresetCircle(preset: preset, radius: radius);
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
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: preset.color.withValues(alpha: 0.65),
            width: 1.4,
          ),
        ),
        alignment: Alignment.center,
        child: Icon(preset.icon, color: preset.color, size: radius * 1.05),
      ),
    );
  }
}
