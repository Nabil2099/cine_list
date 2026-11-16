import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Persistent bottom navigation bar for Discover, Watchlist, AI, and Community.
class AppBottomNavigationBar extends StatelessWidget {
  const AppBottomNavigationBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

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
        height: 68,
        backgroundColor: Colors.transparent,
        indicatorColor: AppColors.pacificBlue.withValues(alpha: 0.16),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined, color: AppColors.textSecondary),
            selectedIcon: Icon(
              Icons.home_rounded,
              color: AppColors.pacificBlue,
            ),
            label: 'Discover',
          ),
          NavigationDestination(
            icon: Icon(
              Icons.bookmark_border_rounded,
              color: AppColors.textSecondary,
            ),
            selectedIcon: Icon(
              Icons.bookmark_rounded,
              color: AppColors.pacificBlue,
            ),
            label: 'Watchlist',
          ),
          NavigationDestination(
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
          NavigationDestination(
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
