import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/repositories/discover_repository.dart';

/// Category filter pills (Trending, Popular, Top Rated).
class CategoryTabs extends StatelessWidget {
  const CategoryTabs({
    super.key,
    required this.selectedCategory,
    required this.onSelected,
    this.isSearchActive = false,
  });

  final DiscoverCategory selectedCategory;
  final ValueChanged<DiscoverCategory> onSelected;
  final bool isSearchActive;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: DiscoverCategory.values.map((category) {
          final isSelected = !isSearchActive && category == selectedCategory;
          final isAnime = category == DiscoverCategory.anime;
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: InkWell(
              onTap: () => onSelected(category),
              borderRadius: BorderRadius.circular(22),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.pacificBlue
                      : isAnime
                      ? AppColors.khakiBeige.withValues(alpha: 0.14)
                      : AppColors.surfaceCard,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.pacificBlue
                        : isAnime
                        ? AppColors.khakiBeige.withValues(alpha: 0.55)
                        : AppColors.surfaceBorder,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isAnime) ...[
                      Icon(
                        Icons.auto_awesome_rounded,
                        size: 14,
                        color: isSelected
                            ? AppColors.black
                            : AppColors.khakiBeige,
                      ),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      category.label,
                      style: TextStyle(
                        color: isSelected
                            ? AppColors.black
                            : isAnime
                            ? AppColors.khakiBeige
                            : AppColors.textSecondary,
                        fontSize: 13.5,
                        fontWeight: isSelected || isAnime
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
