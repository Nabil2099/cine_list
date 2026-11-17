import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/repositories/discover_repository.dart';

/// Expandable/shrinkable genre filter bar in Discover.
class GenreFilterBar extends StatefulWidget {
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
  State<GenreFilterBar> createState() => _GenreFilterBarState();
}

class _GenreFilterBarState extends State<GenreFilterBar> {
  bool _expanded = false;

  Widget _buildChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    IconData? trailingIcon,
    bool isToggle = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
        decoration: BoxDecoration(
          color: isToggle
              ? AppColors.pacificBlue.withValues(alpha: 0.14)
              : selected
              ? AppColors.dustyLavender.withValues(alpha: 0.45)
              : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isToggle
                ? AppColors.pacificBlue.withValues(alpha: 0.45)
                : selected
                ? AppColors.softPeriwinkle
                : AppColors.surfaceBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isToggle
                    ? AppColors.pacificBlue
                    : selected
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
                fontSize: 12,
                fontWeight: selected || isToggle
                    ? FontWeight.w700
                    : FontWeight.w500,
              ),
            ),
            if (trailingIcon != null) ...[
              const SizedBox(width: 4),
              Icon(trailingIcon, size: 15, color: AppColors.pacificBlue),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allChip = _buildChip(
      label: 'All Genres',
      selected: !widget.isSearchActive && widget.selectedGenreId == null,
      onTap: () => widget.onSelected(null),
    );

    final genreChips = DiscoverGenre.defaults
        .map(
          (genre) => _buildChip(
            label: genre.label,
            selected:
                !widget.isSearchActive && widget.selectedGenreId == genre.id,
            onTap: () => widget.onSelected(genre.id),
          ),
        )
        .toList();

    final toggleChip = _buildChip(
      label: _expanded ? 'Less' : 'More',
      selected: false,
      isToggle: true,
      trailingIcon: _expanded
          ? Icons.unfold_less_rounded
          : Icons.unfold_more_rounded,
      onTap: () => setState(() => _expanded = !_expanded),
    );

    return AnimatedSize(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topLeft,
      child: _expanded
          ? Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [allChip, ...genreChips, toggleChip],
            )
          : Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 34,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: genreChips.length + 1,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (context, index) =>
                          index == 0 ? allChip : genreChips[index - 1],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                toggleChip,
              ],
            ),
    );
  }
}
