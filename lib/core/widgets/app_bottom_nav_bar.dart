import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';

/// Luminous liquid-glass floating bottom navigation bar with a physics-animated
/// sliding capsule, live finger-drag scrubbing, refined micro-badges, and
/// smart scroll auto-hide support.
class AppBottomNavigationBar extends StatefulWidget {
  const AppBottomNavigationBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.onRetapActive,
    this.wantToWatchCount = 0,
    this.visible = true,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback? onRetapActive;
  final int wantToWatchCount;
  final bool visible;

  static const items = <_NavDestination>[
    _NavDestination(
      label: 'Discover',
      icon: Icons.explore_outlined,
      selectedIcon: Icons.explore_rounded,
    ),
    _NavDestination(
      label: 'Watchlist',
      icon: Icons.bookmark_border_rounded,
      selectedIcon: Icons.bookmark_rounded,
    ),
    _NavDestination(
      label: 'AI',
      icon: Icons.auto_awesome_outlined,
      selectedIcon: Icons.auto_awesome_rounded,
      isAiAccent: true,
    ),
    _NavDestination(
      label: 'Feed',
      icon: Icons.dynamic_feed_outlined,
      selectedIcon: Icons.dynamic_feed_rounded,
    ),
    _NavDestination(
      label: 'Community',
      icon: Icons.groups_outlined,
      selectedIcon: Icons.groups_rounded,
    ),
  ];

  @override
  State<AppBottomNavigationBar> createState() => _AppBottomNavigationBarState();
}

class _AppBottomNavigationBarState extends State<AppBottomNavigationBar> {
  double? _dragFractionalIndex;
  int? _lastScrubbedSlot;

  double _fractionForDx(double dx, double slotWidth) {
    final maxIdx = (AppBottomNavigationBar.items.length - 1).toDouble();
    return ((dx / slotWidth) - 0.5).clamp(0.0, maxIdx);
  }

  void _handleDragStart(DragStartDetails details, double slotWidth) {
    final fraction = _fractionForDx(details.localPosition.dx, slotWidth);
    final slot = fraction.round();
    if (slot != widget.currentIndex) {
      HapticFeedback.selectionClick();
    }
    setState(() {
      _dragFractionalIndex = fraction;
      _lastScrubbedSlot = slot;
    });
  }

  void _handleDragUpdate(DragUpdateDetails details, double slotWidth) {
    final current = _dragFractionalIndex ?? widget.currentIndex.toDouble();
    final maxIdx = (AppBottomNavigationBar.items.length - 1).toDouble();
    final next = (current + (details.primaryDelta ?? 0.0) / slotWidth).clamp(
      0.0,
      maxIdx,
    );
    final slot = next.round();
    if (slot != _lastScrubbedSlot) {
      HapticFeedback.selectionClick();
      _lastScrubbedSlot = slot;
    }
    setState(() => _dragFractionalIndex = next);
  }

  void _handleDragEnd() {
    final fraction = _dragFractionalIndex;
    setState(() {
      _dragFractionalIndex = null;
      _lastScrubbedSlot = null;
    });
    if (fraction == null) return;
    final targetSlot = fraction.round().clamp(
      0,
      AppBottomNavigationBar.items.length - 1,
    );
    if (targetSlot != widget.currentIndex) {
      widget.onTap(targetSlot);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isScrubbing = _dragFractionalIndex != null;
    final effectiveFraction =
        _dragFractionalIndex ?? widget.currentIndex.toDouble();
    final activeSlot = effectiveFraction.round().clamp(
      0,
      AppBottomNavigationBar.items.length - 1,
    );
    final aiProximity = (1.0 - (effectiveFraction - 2.0).abs()).clamp(0.0, 1.0);
    final activeAccent = Color.lerp(
      AppColors.pacificBlue,
      AppColors.khakiBeige,
      aiProximity,
    )!;

    return IgnorePointer(
      ignoring: !widget.visible,
      child: AnimatedSlide(
        offset: widget.visible ? Offset.zero : const Offset(0, 1.35),
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        child: AnimatedOpacity(
          opacity: widget.visible ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
              child: Container(
                padding: const EdgeInsets.all(1),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: 0.20),
                      activeAccent.withValues(alpha: 0.30),
                      AppColors.surfaceBorder.withValues(alpha: 0.72),
                    ],
                    stops: const [0.0, 0.38, 1.0],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.54),
                      blurRadius: 26,
                      offset: const Offset(0, 12),
                    ),
                    BoxShadow(
                      color: activeAccent.withValues(alpha: 0.14),
                      blurRadius: 20,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(29),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                    child: Container(
                      height: 64,
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(29),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            AppColors.surfaceElevated.withValues(alpha: 0.88),
                            AppColors.surfaceBase.withValues(alpha: 0.92),
                          ],
                        ),
                      ),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final totalWidth = constraints.maxWidth;
                          final count = AppBottomNavigationBar.items.length;
                          final slotWidth = totalWidth / count;
                          final pillWidth = (slotWidth - 4).clamp(
                            0.0,
                            totalWidth,
                          );

                          return GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onHorizontalDragStart: (d) =>
                                _handleDragStart(d, slotWidth),
                            onHorizontalDragUpdate: (d) =>
                                _handleDragUpdate(d, slotWidth),
                            onHorizontalDragEnd: (_) => _handleDragEnd(),
                            onHorizontalDragCancel: _handleDragEnd,
                            child: Stack(
                              alignment: Alignment.centerLeft,
                              children: [
                                // Top inner specular highlight across the dock
                                Positioned(
                                  top: 0,
                                  left: 18,
                                  right: 18,
                                  child: IgnorePointer(
                                    child: Container(
                                      height: 1,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Colors.white.withValues(alpha: 0.0),
                                            Colors.white.withValues(
                                              alpha: 0.14,
                                            ),
                                            Colors.white.withValues(alpha: 0.0),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                // Sliding Liquid-Glass Capsule
                                AnimatedPositioned(
                                  duration: isScrubbing
                                      ? Duration.zero
                                      : const Duration(milliseconds: 280),
                                  curve: Curves.easeOutCubic,
                                  left: effectiveFraction * slotWidth + 2,
                                  top: 5,
                                  bottom: 5,
                                  width: pillWidth,
                                  child: IgnorePointer(
                                    child: _LiquidGlassCapsule(
                                      accentColor: activeAccent,
                                      isScrubbing: isScrubbing,
                                    ),
                                  ),
                                ),
                                // Interactive Tab Destinations
                                Row(
                                  children: [
                                    for (var i = 0; i < count; i++)
                                      Expanded(
                                        child: _FloatingNavItem(
                                          destination:
                                              AppBottomNavigationBar.items[i],
                                          selected: i == activeSlot,
                                          accentColor:
                                              AppBottomNavigationBar
                                                  .items[i]
                                                  .isAiAccent
                                              ? AppColors.khakiBeige
                                              : AppColors.pacificBlue,
                                          badgeCount: i == 1
                                              ? widget.wantToWatchCount
                                              : 0,
                                          onTap: () {
                                            if (i == widget.currentIndex) {
                                              widget.onRetapActive?.call();
                                            } else {
                                              HapticFeedback.selectionClick();
                                            }
                                            widget.onTap(i);
                                          },
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LiquidGlassCapsule extends StatelessWidget {
  const _LiquidGlassCapsule({
    required this.accentColor,
    required this.isScrubbing,
  });

  final Color accentColor;
  final bool isScrubbing;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: isScrubbing ? 1.04 : 1.0,
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(23),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              accentColor.withValues(alpha: 0.28),
              accentColor.withValues(alpha: 0.11),
            ],
          ),
          border: Border.all(
            color: accentColor.withValues(alpha: 0.52),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: accentColor.withValues(alpha: 0.24),
              blurRadius: 14,
              spreadRadius: -2,
            ),
          ],
        ),
        child: Align(
          alignment: Alignment.topCenter,
          child: Container(
            height: 1.2,
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 1.5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              gradient: LinearGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.0),
                  Colors.white.withValues(alpha: 0.38),
                  Colors.white.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavDestination {
  const _NavDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    this.isAiAccent = false,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final bool isAiAccent;
}

class _FloatingNavItem extends StatelessWidget {
  const _FloatingNavItem({
    required this.destination,
    required this.selected,
    required this.accentColor,
    required this.badgeCount,
    required this.onTap,
  });

  final _NavDestination destination;
  final bool selected;
  final Color accentColor;
  final int badgeCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final effectiveIconColor = selected
        ? accentColor
        : (destination.isAiAccent
              ? AppColors.khakiBeige.withValues(alpha: 0.78)
              : AppColors.textSecondary);

    Widget iconWidget = Icon(
      selected ? destination.selectedIcon : destination.icon,
      size: 21,
      color: effectiveIconColor,
    );

    if (badgeCount > 0) {
      iconWidget = Stack(
        clipBehavior: Clip.none,
        children: [
          iconWidget,
          Positioned(
            top: -4,
            right: -9,
            child: _WatchlistMicroBadge(count: badgeCount),
          ),
        ],
      );
    }

    return Semantics(
      selected: selected,
      button: true,
      label: destination.label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(23),
        splashColor: accentColor.withValues(alpha: 0.14),
        highlightColor: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 5),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedScale(
                scale: selected ? 1.1 : 1.0,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutBack,
                child: iconWidget,
              ),
              const SizedBox(height: 2.5),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                style: TextStyle(
                  color: selected ? accentColor : AppColors.textSecondary,
                  fontSize: 10.2,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  letterSpacing: selected ? 0.15 : 0.0,
                  height: 1.1,
                ),
                child: Text(
                  destination.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WatchlistMicroBadge extends StatelessWidget {
  const _WatchlistMicroBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final label = count > 99 ? '99+' : '$count';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      constraints: const BoxConstraints(minWidth: 15, minHeight: 15),
      decoration: BoxDecoration(
        color: AppColors.pacificBlue,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.surfaceElevated, width: 1.5),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.black,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          height: 1.05,
        ),
      ),
    );
  }
}
