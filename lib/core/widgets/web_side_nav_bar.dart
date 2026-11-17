import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Left-hand sidebar navigation rendered on Flutter Web.
class WebSideNavBar extends StatelessWidget {
  const WebSideNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  static const _items = [
    (
      icon: Icons.explore_outlined,
      activeIcon: Icons.explore_rounded,
      label: 'Discover',
    ),
    (
      icon: Icons.bookmark_border_rounded,
      activeIcon: Icons.bookmark_rounded,
      label: 'Watchlist',
    ),
    (
      icon: Icons.auto_awesome_outlined,
      activeIcon: Icons.auto_awesome_rounded,
      label: 'AI',
    ),
    (
      icon: Icons.groups_outlined,
      activeIcon: Icons.groups_rounded,
      label: 'Community',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isExpanded = MediaQuery.sizeOf(context).width >= 900;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: isExpanded ? 224 : 78,
      decoration: const BoxDecoration(
        color: AppColors.surfaceBase,
        border: Border(right: BorderSide(color: AppColors.surfaceBorder)),
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isExpanded ? 14 : 10,
            vertical: 18,
          ),
          child: Column(
            crossAxisAlignment: isExpanded
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.center,
            children: [
              // Brand header
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isExpanded ? 6 : 0,
                  vertical: 4,
                ),
                child: Row(
                  mainAxisAlignment: isExpanded
                      ? MainAxisAlignment.start
                      : MainAxisAlignment.center,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.asset(
                        'assets/images/app_icon.png',
                        width: 36,
                        height: 36,
                        fit: BoxFit.cover,
                      ),
                    ),
                    if (isExpanded) ...[
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'CineList',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.4,
                              ),
                            ),
                            Text(
                              'Cinema Hub',
                              style: TextStyle(
                                color: AppColors.khakiBeige,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 28),
              ...List.generate(_items.length, (index) {
                final item = _items[index];
                final selected = index == currentIndex;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Tooltip(
                    message: isExpanded ? '' : item.label,
                    child: InkWell(
                      onTap: () => onTap(index),
                      borderRadius: BorderRadius.circular(14),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: EdgeInsets.symmetric(
                          horizontal: isExpanded ? 14 : 0,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.pacificBlue.withValues(alpha: 0.16)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: selected
                                ? AppColors.pacificBlue.withValues(alpha: 0.45)
                                : Colors.transparent,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: isExpanded
                              ? MainAxisAlignment.start
                              : MainAxisAlignment.center,
                          children: [
                            Icon(
                              selected ? item.activeIcon : item.icon,
                              size: 22,
                              color: selected
                                  ? AppColors.pacificBlue
                                  : AppColors.textSecondary,
                            ),
                            if (isExpanded) ...[
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  item.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: selected
                                        ? AppColors.textPrimary
                                        : AppColors.textSecondary,
                                    fontSize: 14,
                                    fontWeight: selected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
              const Spacer(),
              if (isExpanded)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceCard,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.surfaceBorder),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.movie_filter_rounded,
                        size: 18,
                        color: AppColors.khakiBeige,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Discover · Save · Watch',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
