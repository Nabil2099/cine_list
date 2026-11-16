import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/models/watchlist_movie_model.dart';

/// Pill segmented tabs for Want to Watch and Watched counts.
class WatchlistTabs extends StatelessWidget {
  const WatchlistTabs({
    super.key,
    required this.selectedTab,
    required this.wantToWatchCount,
    required this.watchedCount,
    required this.onTabSelected,
  });

  final WatchlistFilterStatus selectedTab;
  final int wantToWatchCount;
  final int watchedCount;
  final ValueChanged<WatchlistFilterStatus> onTabSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: _TabPill(
              label: 'Want to Watch ($wantToWatchCount)',
              selected: selectedTab == WatchlistFilterStatus.wantToWatch,
              onTap: () => onTabSelected(WatchlistFilterStatus.wantToWatch),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _TabPill(
              label: 'Watched ($watchedCount)',
              selected: selectedTab == WatchlistFilterStatus.watched,
              onTap: () => onTabSelected(WatchlistFilterStatus.watched),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabPill extends StatelessWidget {
  const _TabPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.pacificBlue : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: selected ? AppColors.black : AppColors.textSecondary,
            fontSize: 13,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
