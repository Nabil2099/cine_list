import 'package:flutter/material.dart';

import '../../features/ai_chat/presentation/screens/ai_chat_screen.dart';
import '../../features/community/presentation/screens/community_screen.dart';
import '../../features/discover/presentation/screens/discover_screen.dart';
import '../../features/watchlist/presentation/screens/watchlist_screen.dart';
import '../theme/app_colors.dart';
import '../widgets/app_bottom_nav_bar.dart';

/// Main authenticated shell with two persistent destinations: Discover & Watchlist.
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
    return Scaffold(
      backgroundColor: AppColors.black,
      body: IndexedStack(
        index: _currentIndex,
        children: [
          const DiscoverScreen(),
          WatchlistScreen(onExploreMovies: () => _selectTab(0)),
          const AiChatScreen(),
          const CommunityScreen(),
        ],
      ),
      bottomNavigationBar: AppBottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _selectTab,
      ),
    );
  }
}
