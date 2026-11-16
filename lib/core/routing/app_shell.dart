import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../features/ai_chat/presentation/screens/ai_chat_screen.dart';
import '../../features/community/presentation/screens/community_screen.dart';
import '../../features/discover/presentation/screens/discover_screen.dart';
import '../../features/watchlist/presentation/screens/watchlist_screen.dart';
import '../theme/app_colors.dart';
import '../widgets/app_bottom_nav_bar.dart';
import '../widgets/web_side_nav_bar.dart';

/// Main authenticated shell using a sidebar on Web and bottom nav bar on mobile.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = 0;

  void _selectTab(int index) {
    if (index == _currentIndex) return;
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final pages = IndexedStack(
      index: _currentIndex,
      children: [
        const DiscoverScreen(),
        WatchlistScreen(onExploreMovies: () => _selectTab(0)),
        const AiChatScreen(),
        const CommunityScreen(),
      ],
    );

    if (kIsWeb) {
      return Scaffold(
        backgroundColor: AppColors.black,
        body: Row(
          children: [
            WebSideNavBar(currentIndex: _currentIndex, onTap: _selectTab),
            Expanded(child: pages),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.black,
      body: pages,
      bottomNavigationBar: AppBottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _selectTab,
      ),
    );
  }
}
