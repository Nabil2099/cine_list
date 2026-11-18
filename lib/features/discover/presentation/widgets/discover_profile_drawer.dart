import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../community/data/models/user_profile_model.dart';
import '../../../community/presentation/cubit/community_cubit.dart';
import '../../../community/presentation/widgets/user_avatar_widget.dart';
import '../../../watchlist/presentation/cubit/watchlist_cubit.dart';

/// Home endDrawer displaying the user's profile overview, stats, and settings.
class DiscoverProfileDrawer extends StatelessWidget {
  const DiscoverProfileDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final authUser = context.watch<AuthCubit>().state.user;
    final communityState = context.watch<CommunityCubit>().state;
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
            // Profile Overview Card
            Container(
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
                                  _DrawerPill(
                                    label: 'Admin',
                                    color: AppColors.khakiBeige,
                                    icon: Icons.verified_user_rounded,
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

            const SizedBox(height: 14),

            // Quick Stats Row
            Row(
              children: [
                _MiniStat(
                  value: '${watchlistState.movies.length}',
                  label: 'Saved',
                  color: AppColors.pacificBlue,
                ),
                const SizedBox(width: 8),
                _MiniStat(
                  value: '${watchlistState.watchedMovies.length}',
                  label: 'Watched',
                  color: AppColors.khakiBeige,
                ),
                const SizedBox(width: 8),
                _MiniStat(
                  value: '$myReviewsCount',
                  label: 'Reviews',
                  color: AppColors.softPeriwinkle,
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
                    title: const Text('Full Profile & Edit Photo'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {
                      Navigator.of(context).pop();
                      context.push('/profile');
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
                      leading: Icon(
                        communityState.isAdmin
                            ? Icons.admin_panel_settings_outlined
                            : Icons.gavel_rounded,
                        color: communityState.isAdmin
                            ? AppColors.khakiBeige
                            : AppColors.pacificBlue,
                      ),
                      title: Text(
                        communityState.isAdmin
                            ? 'Admin Moderation Panel'
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
    required this.icon,
  });

  final String label;
  final Color color;
  final IconData icon;

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
  });

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
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
    );
  }
}

