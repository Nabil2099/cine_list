import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/cubit/auth_cubit.dart';
import '../../features/auth/presentation/cubit/auth_state.dart';
import '../../features/discover/presentation/widgets/discover_profile_drawer.dart';
import '../../features/watchlist/presentation/cubit/watchlist_cubit.dart';
import '../constants/app_constants.dart';
import '../theme/app_colors.dart';
import '../widgets/app_bottom_nav_bar.dart';
import '../widgets/web_side_nav_bar.dart';

/// Main navigation shell using a sidebar on wide Web viewports and a shared
/// drawer + liquid-glass floating bottom navigation bar on mobile viewports.
class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  bool _isBottomNavVisible = true;
  double _scrollDeltaAccumulator = 0.0;
  final Map<int, ScrollPosition> _tabScrollPositions = {};

  @override
  void didUpdateWidget(covariant AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.navigationShell.currentIndex !=
        widget.navigationShell.currentIndex) {
      _isBottomNavVisible = true;
      _scrollDeltaAccumulator = 0.0;
    }
  }

  void _selectTab(int index) {
    if (!_isBottomNavVisible) {
      setState(() {
        _isBottomNavVisible = true;
        _scrollDeltaAccumulator = 0.0;
      });
    }
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  void _scrollActiveTabToTop() {
    HapticFeedback.lightImpact();
    final pos = _tabScrollPositions[widget.navigationShell.currentIndex];
    if (pos != null && pos.hasPixels && pos.pixels > 0) {
      pos.animateTo(
        0.0,
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
      );
    }
  }

  bool _onScrollNotification(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical || notification.depth != 0) {
      return false;
    }

    final currentIndex = widget.navigationShell.currentIndex;
    final ctx = notification.context;
    if (ctx != null) {
      final scrollable = Scrollable.maybeOf(ctx);
      if (scrollable != null) {
        _tabScrollPositions[currentIndex] = scrollable.position;
      }
    }

    // Keep nav bar always visible on AI Chat so it never fights the input bar.
    if (currentIndex == 2) {
      if (!_isBottomNavVisible) {
        setState(() {
          _isBottomNavVisible = true;
          _scrollDeltaAccumulator = 0.0;
        });
      }
      return false;
    }

    final metrics = notification.metrics;
    if (metrics.pixels <= 24) {
      if (!_isBottomNavVisible) {
        setState(() {
          _isBottomNavVisible = true;
          _scrollDeltaAccumulator = 0.0;
        });
      }
      return false;
    }

    if (notification is ScrollUpdateNotification) {
      final delta = notification.scrollDelta ?? 0.0;
      // Ignore overscroll bounce at top/bottom edges.
      if (metrics.pixels < 0 || metrics.pixels >= metrics.maxScrollExtent) {
        return false;
      }
      if ((delta > 0 && _scrollDeltaAccumulator < 0) ||
          (delta < 0 && _scrollDeltaAccumulator > 0)) {
        _scrollDeltaAccumulator = 0.0;
      }
      _scrollDeltaAccumulator += delta;

      if (_scrollDeltaAccumulator > 20 &&
          metrics.pixels > 40 &&
          _isBottomNavVisible) {
        setState(() {
          _isBottomNavVisible = false;
          _scrollDeltaAccumulator = 0.0;
        });
      } else if (_scrollDeltaAccumulator < -10 && !_isBottomNavVisible) {
        setState(() {
          _isBottomNavVisible = true;
          _scrollDeltaAccumulator = 0.0;
        });
      }
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = widget.navigationShell.currentIndex;
    final isWideWeb =
        kIsWeb &&
        MediaQuery.sizeOf(context).width >= AppConstants.tabletBreakpoint;
    final isSignedIn = context.select<AuthCubit, bool>(
      (c) => c.state.status == AuthStatus.authenticated,
    );
    final rawWantToWatchCount = context.select<WatchlistCubit, int>(
      (w) => w.state.wantToWatchMovies.length,
    );
    final wantToWatchCount = isSignedIn ? rawWantToWatchCount : 0;

    if (isWideWeb) {
      return Scaffold(
        backgroundColor: AppColors.black,
        body: Row(
          children: [
            WebSideNavBar(
              currentIndex: currentIndex,
              onTap: _selectTab,
              wantToWatchCount: wantToWatchCount,
            ),
            Expanded(child: widget.navigationShell),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.black,
      extendBody: currentIndex != 2,
      drawer: const DiscoverProfileDrawer(),
      body: NotificationListener<ScrollNotification>(
        onNotification: _onScrollNotification,
        child: widget.navigationShell,
      ),
      bottomNavigationBar: AppBottomNavigationBar(
        currentIndex: currentIndex,
        onTap: _selectTab,
        onRetapActive: _scrollActiveTabToTop,
        wantToWatchCount: wantToWatchCount,
        visible: currentIndex == 2 ? true : _isBottomNavVisible,
      ),
    );
  }
}
