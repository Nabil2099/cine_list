import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';

/// Web-only landing page showcasing everything CineList provides before login.
class WebLandingScreen extends StatelessWidget {
  const WebLandingScreen({
    super.key,
    required this.onSignIn,
    required this.onGetStarted,
  });

  final VoidCallback onSignIn;
  final VoidCallback onGetStarted;

  static const _features = [
    (
      icon: Icons.explore_rounded,
      color: AppColors.pacificBlue,
      title: 'Smart Discovery',
      description: 'Browse Trending, Now Playing, Upcoming, Popular, and Top Rated films with instant genre filtering and quick-save.',
    ),
    (
      icon: Icons.bookmark_added_rounded,
      color: AppColors.khakiBeige,
      title: 'Watchlist & Collections',
      description: 'Organize Want to Watch and Watched titles, create custom themed lists, rate 1–5★, and spin Tonight\'s Pick.',
    ),
    (
      icon: Icons.auto_awesome_rounded,
      color: AppColors.softPeriwinkle,
      title: 'CineList AI Concierge',
      description: 'Get personalized Gemini recommendations tailored to your watchlist and ratings—or pick a 1-tap mood.',
    ),
    (
      icon: Icons.play_circle_fill_rounded,
      color: AppColors.pacificBlue,
      title: 'Trailers & Where to Watch',
      description: 'Watch official trailers, check streaming/rent/buy providers, and tap any cast member for their full filmography.',
    ),
    (
      icon: Icons.groups_rounded,
      color: AppColors.khakiBeige,
      title: 'Community & Reviews',
      description: 'Customize your avatar and bio, publish star-rated movie reviews, upvote helpful takes, and share picks.',
    ),
    (
      icon: Icons.sync_rounded,
      color: AppColors.softPeriwinkle,
      title: 'Real-Time Cloud Sync',
      description: 'Your watchlist, custom collections, ratings, and profile stay synced across Web and Android in real time.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= 920;

    return Scaffold(
      backgroundColor: AppColors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Cinematic ambient background glow
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -0.7),
                radius: 1.15,
                colors: [
                  AppColors.pacificBlue.withValues(alpha: 0.16),
                  AppColors.softPeriwinkle.withValues(alpha: 0.08),
                  AppColors.surfaceBase,
                  AppColors.black,
                ],
                stops: const [0.0, 0.35, 0.72, 1.0],
              ),
            ),
          ),
          SingleChildScrollView(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: AppConstants.maxContentWidth,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 22,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Top navigation bar
                      _LandingTopBar(
                        onSignIn: onSignIn,
                        onGetStarted: onGetStarted,
                      ),
                      SizedBox(height: isWide ? 64 : 40),

                      // Hero section
                      if (isWide)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              flex: 6,
                              child: _HeroCopy(
                                onSignIn: onSignIn,
                                onGetStarted: onGetStarted,
                              ),
                            ),
                            const SizedBox(width: 40),
                            const Expanded(flex: 5, child: _HeroShowcaseCard()),
                          ],
                        )
                      else ...[
                        _HeroCopy(
                          onSignIn: onSignIn,
                          onGetStarted: onGetStarted,
                        ),
                        const SizedBox(height: 32),
                        const _HeroShowcaseCard(),
                      ],

                      SizedBox(height: isWide ? 76 : 52),

                      // Features section header
                      const Text(
                        'EVERYTHING YOU NEED FOR MOVIE NIGHT',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.khakiBeige,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2.2,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'What CineList Provides',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 28),

                      // Features Grid
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final cols = constraints.maxWidth >= 900
                              ? 3
                              : constraints.maxWidth >= 580
                              ? 2
                              : 1;
                          const spacing = 18.0;
                          final itemWidth =
                              (constraints.maxWidth - (spacing * (cols - 1))) /
                              cols;

                          return Wrap(
                            spacing: spacing,
                            runSpacing: spacing,
                            children: _features
                                .map(
                                  (f) => SizedBox(
                                    width: itemWidth,
                                    child: _FeatureCard(
                                      icon: f.icon,
                                      accentColor: f.color,
                                      title: f.title,
                                      description: f.description,
                                    ),
                                  ),
                                )
                                .toList(),
                          );
                        },
                      ),

                      const SizedBox(height: 56),

                      // Bottom CTA Banner
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 28,
                          vertical: 34,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppColors.pacificBlue.withValues(alpha: 0.18),
                              AppColors.surfaceCard,
                              AppColors.softPeriwinkle.withValues(alpha: 0.14),
                            ],
                          ),
                          border: Border.all(color: AppColors.surfaceBorder),
                        ),
                        child: Column(
                          children: [
                            Text(
                              'Ready to build your watchlist?',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Sign in or create a free account to sync your movies, AI picks, and community reviews.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 14.5,
                              ),
                            ),
                            const SizedBox(height: 22),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              alignment: WrapAlignment.center,
                              children: [
                                FilledButton.icon(
                                  onPressed: onGetStarted,
                                  icon: const Icon(Icons.rocket_launch_rounded),
                                  label: const Text('Get Started Free'),
                                ),
                                OutlinedButton(
                                  onPressed: onSignIn,
                                  child: const Text('Sign In'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 34),
                      const Text(
                        'CineList  ·  Discover. Save. Watch.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LandingTopBar extends StatelessWidget {
  const _LandingTopBar({required this.onSignIn, required this.onGetStarted});

  final VoidCallback onSignIn;
  final VoidCallback onGetStarted;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.asset(
            'assets/images/app_icon.png',
            width: 38,
            height: 38,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(width: 12),
        const Text(
          'CineList',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.4,
          ),
        ),
        const Spacer(),
        TextButton(onPressed: onSignIn, child: const Text('Sign In')),
        const SizedBox(width: 8),
        FilledButton(onPressed: onGetStarted, child: const Text('Get Started')),
      ],
    );
  }
}

class _HeroCopy extends StatelessWidget {
  const _HeroCopy({required this.onSignIn, required this.onGetStarted});

  final VoidCallback onSignIn;
  final VoidCallback onGetStarted;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.pacificBlue.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: AppColors.pacificBlue.withValues(alpha: 0.4),
            ),
          ),
          child: const Text(
            'TMDB · GEMINI AI · REAL-TIME WATCHLIST',
            style: TextStyle(
              color: AppColors.pacificBlue,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Discover, Track & Discuss Every Film You Love.',
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
            height: 1.12,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'CineList brings together smart TMDB discovery, custom watchlist collections, AI-powered mood recommendations, streaming availability, and a community of film lovers—all in one dark cinematic hub.',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 15.5,
            height: 1.55,
          ),
        ),
        const SizedBox(height: 26),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton.icon(
              onPressed: onGetStarted,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 15,
                ),
              ),
              icon: const Icon(Icons.arrow_forward_rounded),
              label: const Text('Start Your Watchlist'),
            ),
            OutlinedButton(
              onPressed: onSignIn,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 15,
                ),
              ),
              child: const Text('I Already Have an Account'),
            ),
          ],
        ),
      ],
    );
  }
}

class _HeroShowcaseCard extends StatelessWidget {
  const _HeroShowcaseCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.surfaceBorder),
        boxShadow: [
          BoxShadow(
            color: AppColors.pacificBlue.withValues(alpha: 0.12),
            blurRadius: 36,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.movie_creation_outlined,
                color: AppColors.khakiBeige,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Inside CineList',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Live Sync',
                  style: TextStyle(
                    color: AppColors.success,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const _ShowcaseRow(
            icon: Icons.local_movies_rounded,
            color: AppColors.pacificBlue,
            title: 'Discover & Upcoming',
            subtitle: 'Trending, Now Playing, Upcoming & Genre chips',
          ),
          const SizedBox(height: 12),
          const _ShowcaseRow(
            icon: Icons.casino_rounded,
            color: AppColors.khakiBeige,
            title: 'Tonight\'s Pick & Collections',
            subtitle: 'Randomize movie night & organize custom lists',
          ),
          const SizedBox(height: 12),
          const _ShowcaseRow(
            icon: Icons.auto_awesome_rounded,
            color: AppColors.softPeriwinkle,
            title: 'AI Mood Concierge',
            subtitle: 'Instant Gemini picks based on your ratings',
          ),
          const SizedBox(height: 12),
          const _ShowcaseRow(
            icon: Icons.rate_review_rounded,
            color: AppColors.pacificBlue,
            title: 'Community Reviews',
            subtitle: 'Share takes, upvote helpful reviews & view profiles',
          ),
        ],
      ),
    );
  }
}

class _ShowcaseRow extends StatelessWidget {
  const _ShowcaseRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.icon,
    required this.accentColor,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final Color accentColor;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: accentColor, size: 23),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13.5,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
