import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/auth_gate.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../auth/presentation/cubit/auth_state.dart';
import '../../../community/data/models/user_profile_model.dart';
import '../../../community/presentation/bloc/community_bloc.dart';
import '../../../community/presentation/widgets/user_avatar_widget.dart';
import '../../../watchlist/data/models/watchlist_movie_model.dart';
import '../../../watchlist/presentation/cubit/watchlist_cubit.dart';

/// Shared Drawer displaying the user's profile overview, quick jumps, and settings
/// (or a Guest Mode sign-in card when browsing unauthenticated).
class DiscoverProfileDrawer extends StatelessWidget {
  const DiscoverProfileDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthCubit>().state;
    final isSignedIn = authState.status == AuthStatus.authenticated;

    if (!isSignedIn) {
      return Drawer(
        backgroundColor: AppColors.surfaceBase,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 24),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.surfaceCard,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.surfaceBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppColors.pacificBlue.withValues(
                              alpha: 0.16,
                            ),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: AppColors.pacificBlue.withValues(
                                alpha: 0.45,
                              ),
                            ),
                          ),
                          child: const Icon(
                            Icons.movie_filter_rounded,
                            color: AppColors.khakiBeige,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Browsing as Guest',
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Sign in to unlock your personal cinema hub',
                                style: TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const _GuestBenefitRow(
                      icon: Icons.bookmark_added_rounded,
                      text: 'Sync Watchlist & custom collections across devices',
                    ),
                    const SizedBox(height: 8),
                    const _GuestBenefitRow(
                      icon: Icons.rate_review_rounded,
                      text: 'Rate movies, log watched films & write reviews',
                    ),
                    const SizedBox(height: 8),
                    const _GuestBenefitRow(
                      icon: Icons.auto_awesome_rounded,
                      text: 'Get AI picks tailored to your Watchlist',
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          AuthGate.openAuth(context, register: false);
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.pacificBlue,
                          foregroundColor: AppColors.black,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'Sign In',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          AuthGate.openAuth(context, register: true);
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textPrimary,
                          side: const BorderSide(
                            color: AppColors.surfaceBorder,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'Create Free Account',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (kIsWeb) ...[
                const SizedBox(height: 18),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceCard,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.surfaceBorder),
                  ),
                  child: ListTile(
                    leading: const Icon(
                      Icons.info_outline_rounded,
                      color: AppColors.khakiBeige,
                    ),
                    title: const Text('About CineList'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {
                      Navigator.of(context).pop();
                      context.go('/welcome');
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    final authUser = authState.user;
    final communityState = context.watch<CommunityBloc>().state;
    final watchlistState = context.watch<WatchlistCubit>().state;

    final uid = authUser?.uid ?? '';
    final email = authUser?.email ?? '';
    final profile =
        communityState.profile ??
        UserProfileModel(
          uid: uid,
          displayName: authUser?.displayName?.trim().isNotEmpty == true
              ? authUser!.displayName!.trim()
              : 'Movie Fan',
        );
    final tier = profile.tier;
    final next = tier.nextTier;
    final myReviewsCount = communityState.reviews
        .where((r) => r.uid == uid)
        .length;

    return Drawer(
      backgroundColor: AppColors.surfaceBase,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 24),
          children: [
            // Profile Overview Card (1-tap jump to Profile)
            InkWell(
              onTap: () {
                Navigator.of(context).pop();
                context.push('/profile');
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceCard,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.surfaceBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        UserAvatar(
                          avatarKey: profile.avatarKey,
                          photoBase64: profile.photoBase64,
                          reputation: profile.reputation,
                          isAdmin: communityState.isAdmin,
                          isModerator: communityState.isModerator,
                          radius: 28,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                profile.displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              if (email.isNotEmpty)
                                Text(
                                  email,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 11.5,
                                  ),
                                ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: [
                                  if (communityState.isAdmin)
                                    const _DrawerPill(
                                      label: 'Creator',
                                      color: AppColors.creatorEmerald,
                                      leading: CreatorEmblemIcon(size: 12),
                                    )
                                  else if (communityState.isModerator)
                                    _DrawerPill(
                                      label: 'Moderator',
                                      color: AppColors.pacificBlue,
                                      icon: Icons.gavel_rounded,
                                    ),
                                  _DrawerPill(
                                    label:
                                        '${tier.label} · ${profile.reputation} pts',
                                    color: tier.color,
                                    icon: tier.icon,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.textMuted,
                          size: 20,
                        ),
                      ],
                    ),
                    if (profile.bio.trim().isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        profile.bio.trim(),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12.5,
                          height: 1.4,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: tier.progressToNext(profile.reputation),
                        minHeight: 6,
                        backgroundColor: AppColors.surfaceElevated,
                        color: tier.color,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      next == null
                          ? 'Max rank unlocked!'
                          : '${next.minPoints - profile.reputation} pts to ${next.label}',
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 14),

            // Tappable Quick Stats Shortcuts
            Row(
              children: [
                _MiniStat(
                  value: '${watchlistState.wantToWatchMovies.length}',
                  label: 'Want List',
                  color: AppColors.pacificBlue,
                  onTap: () {
                    Navigator.of(context).pop();
                    context.read<WatchlistCubit>().selectTab(
                      WatchlistFilterStatus.wantToWatch,
                    );
                    context.go('/watchlist');
                  },
                ),
                const SizedBox(width: 8),
                _MiniStat(
                  value: '${watchlistState.watchedMovies.length}',
                  label: 'Watched',
                  color: AppColors.khakiBeige,
                  onTap: () {
                    Navigator.of(context).pop();
                    context.read<WatchlistCubit>().selectTab(
                      WatchlistFilterStatus.watched,
                    );
                    context.go('/watchlist');
                  },
                ),
                const SizedBox(width: 8),
                _MiniStat(
                  value: '$myReviewsCount',
                  label: 'Reviews',
                  color: AppColors.softPeriwinkle,
                  onTap: () {
                    Navigator.of(context).pop();
                    context.push('/profile');
                  },
                ),
              ],
            ),

            const SizedBox(height: 22),

            const Padding(
              padding: EdgeInsets.only(left: 6, bottom: 8),
              child: Text(
                'SETTINGS & ACCOUNT',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
              ),
            ),

            Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceCard,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.surfaceBorder),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(
                      Icons.person_outline_rounded,
                      color: AppColors.pacificBlue,
                    ),
                    title: const Text('My Profile'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {
                      Navigator.of(context).pop();
                      context.push('/profile');
                    },
                  ),
                  const Divider(height: 1, color: AppColors.surfaceBorder),
                  ListTile(
                    leading: const Icon(
                      Icons.auto_graph_rounded,
                      color: AppColors.softPeriwinkle,
                    ),
                    title: const Text('Cinema Wrapped'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {
                      Navigator.of(context).pop();
                      context.push('/stats');
                    },
                  ),
                  if (email.isNotEmpty) ...[
                    const Divider(height: 1, color: AppColors.surfaceBorder),
                    ListTile(
                      leading: const Icon(
                        Icons.lock_reset_rounded,
                        color: AppColors.khakiBeige,
                      ),
                      title: const Text('Reset Password'),
                      onTap: () async {
                        Navigator.of(context).pop();
                        await context.read<AuthCubit>().sendPasswordReset(
                          email,
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context)
                            ..hideCurrentSnackBar()
                            ..showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Password reset link sent to $email.',
                                ),
                              ),
                            );
                        }
                      },
                    ),
                  ],
                  if (communityState.isStaff) ...[
                    const Divider(height: 1, color: AppColors.surfaceBorder),
                    ListTile(
                      leading: communityState.isAdmin
                          ? const CreatorEmblemIcon(size: 20)
                          : const Icon(
                              Icons.gavel_rounded,
                              color: AppColors.pacificBlue,
                            ),
                      title: Text(
                        communityState.isAdmin
                            ? 'Creator Moderation Panel'
                            : 'Moderation Panel',
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () {
                        Navigator.of(context).pop();
                        context.push('/admin');
                      },
                    ),
                  ],
                  const Divider(height: 1, color: AppColors.surfaceBorder),
                  ListTile(
                    leading: const Icon(
                      Icons.logout_rounded,
                      color: AppColors.error,
                    ),
                    title: const Text(
                      'Sign Out',
                      style: TextStyle(color: AppColors.error),
                    ),
                    onTap: () {
                      Navigator.of(context).pop();
                      context.read<AuthCubit>().signOut();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerPill extends StatelessWidget {
  const _DrawerPill({
    required this.label,
    required this.color,
    this.icon,
    this.leading,
  });

  final String label;
  final Color color;
  final IconData? icon;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leading != null)
            leading!
          else if (icon != null)
            Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.value,
    required this.label,
    required this.color,
    this.onTap,
  });

  final String value;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.surfaceBorder),
          ),
          child: Column(
            children: [
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GuestBenefitRow extends StatelessWidget {
  const _GuestBenefitRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 17, color: AppColors.pacificBlue),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12.5,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}
