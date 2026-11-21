import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Persistent bottom navigation bar for Discover, Watchlist, AI, Feed, and Community.
class AppBottomNavigationBar extends StatelessWidget {
  const AppBottomNavigationBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.wantToWatchCount = 0,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final int wantToWatchCount;

  Widget _watchlistIcon({required bool selected}) {
    final baseIcon = Icon(
      selected ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
      color: selected ? AppColors.pacificBlue : AppColors.textSecondary,
    );
    if (wantToWatchCount <= 0) return baseIcon;
    return Badge.count(
      count: wantToWatchCount > 99 ? 99 : wantToWatchCount,
      backgroundColor: AppColors.pacificBlue,
      textColor: AppColors.black,
      child: baseIcon,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceElevated,
        border: Border(
          top: BorderSide(color: AppColors.surfaceBorder, width: 0.8),
        ),
      ),
      child: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: onTap,
        height: 60,
        backgroundColor: Colors.transparent,
        indicatorColor: AppColors.pacificBlue.withValues(alpha: 0.16),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.explore_outlined, color: AppColors.textSecondary),
            selectedIcon: Icon(
              Icons.explore_rounded,
              color: AppColors.pacificBlue,
            ),
            label: 'Discover',
          ),
          NavigationDestination(
            icon: _watchlistIcon(selected: false),
            selectedIcon: _watchlistIcon(selected: true),
            label: 'Watchlist',
          ),
          const NavigationDestination(
            icon: Icon(
              Icons.auto_awesome_outlined,
              color: AppColors.textSecondary,
            ),
            selectedIcon: Icon(
              Icons.auto_awesome_rounded,
              color: AppColors.pacificBlue,
            ),
            label: 'AI',
          ),
          const NavigationDestination(
            icon: Icon(
              Icons.dynamic_feed_outlined,
              color: AppColors.textSecondary,
            ),
            selectedIcon: Icon(
              Icons.dynamic_feed_rounded,
              color: AppColors.pacificBlue,
            ),
            label: 'Feed',
          ),
          const NavigationDestination(
            icon: Icon(Icons.groups_outlined, color: AppColors.textSecondary),
            selectedIcon: Icon(
              Icons.groups_rounded,
              color: AppColors.pacificBlue,
            ),
            label: 'Community',
          ),
        ],
      ),
    );
  }
}
