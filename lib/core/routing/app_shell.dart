import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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
/// drawer + bottom navigation bar on mobile apps and mobile web browsers.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _selectTab(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
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
              currentIndex: navigationShell.currentIndex,
              onTap: _selectTab,
              wantToWatchCount: wantToWatchCount,
            ),
            Expanded(child: navigationShell),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.black,
      drawer: const DiscoverProfileDrawer(),
      body: navigationShell,
      bottomNavigationBar: AppBottomNavigationBar(
        currentIndex: navigationShell.currentIndex,
        onTap: _selectTab,
        wantToWatchCount: wantToWatchCount,
      ),
    );
  }
}
