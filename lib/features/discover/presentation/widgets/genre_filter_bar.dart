import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/repositories/discover_repository.dart';

/// Compact horizontal genre filter chip row in Discover.
class GenreFilterBar extends StatelessWidget {
  const GenreFilterBar({
    super.key,
    required this.selectedGenreId,
    required this.onSelected,
    this.isSearchActive = false,
  });

  final int? selectedGenreId;
  final ValueChanged<int?> onSelected;
  final bool isSearchActive;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: DiscoverGenre.defaults.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final isAll = index == 0;
          final genre = isAll ? null : DiscoverGenre.defaults[index - 1];
          final selected =
              !isSearchActive &&
              (isAll ? selectedGenreId == null : selectedGenreId == genre!.id);

          return InkWell(
            onTap: () => onSelected(isAll ? null : genre!.id),
            borderRadius: BorderRadius.circular(18),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.dustyLavender.withValues(alpha: 0.45)
                    : AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: selected
                      ? AppColors.softPeriwinkle
                      : AppColors.surfaceBorder,
                ),
              ),
              child: Text(
                isAll ? 'All Genres' : genre!.label,
                style: TextStyle(
                  color: selected
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
