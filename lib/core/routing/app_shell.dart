import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../constants/app_constants.dart';
import '../theme/app_colors.dart';
import '../widgets/app_bottom_nav_bar.dart';
import '../widgets/web_side_nav_bar.dart';

/// Main authenticated shell using a sidebar on wide Web viewports and the
/// standard bottom navigation bar on mobile apps and mobile web browsers.
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

    if (isWideWeb) {
      return Scaffold(
        backgroundColor: AppColors.black,
        body: Row(
          children: [
            WebSideNavBar(
              currentIndex: navigationShell.currentIndex,
              onTap: _selectTab,
            ),
            Expanded(child: navigationShell),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.black,
      body: navigationShell,
      bottomNavigationBar: AppBottomNavigationBar(
        currentIndex: navigationShell.currentIndex,
        onTap: _selectTab,
      ),
    );
  }
}
