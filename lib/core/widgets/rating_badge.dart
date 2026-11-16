import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../utils/formatters.dart';

/// Compact star + rating badge used on movie cards and details.
class RatingBadge extends StatelessWidget {
  const RatingBadge({
    super.key,
    required this.rating,
    this.fontSize = 12,
    this.iconSize = 14,
    this.filled = false,
  });

  final double rating;
  final double fontSize;
  final double iconSize;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final text = Formatters.rating(rating);
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.star_rounded, color: AppColors.starAmber, size: iconSize),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            color: AppColors.khakiBeige,
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );

    if (!filled) return content;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.black.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.surfaceBorder.withValues(alpha: 0.8),
        ),
      ),
      child: content,
    );
  }
}
