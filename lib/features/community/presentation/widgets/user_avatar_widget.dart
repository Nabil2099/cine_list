import 'package:flutter/material.dart';

import '../../data/models/user_profile_model.dart';

/// Circular themed avatar rendered from an [AvatarPreset] key.
class UserAvatar extends StatelessWidget {
  const UserAvatar({super.key, required this.avatarKey, this.radius = 22});

  final String avatarKey;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final preset = AvatarPreset.fromKey(avatarKey);
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
