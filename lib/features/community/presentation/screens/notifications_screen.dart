import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/routing/movie_details_route.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/empty_state_view.dart';
import '../../../../shared/models/movie_summary.dart';
import '../../data/models/app_notification_model.dart';
import '../bloc/community_bloc.dart';
import '../widgets/user_avatar_widget.dart';
import '../widgets/user_profile_dialog.dart';

/// Instagram-style Activity / Notifications screen (`/notifications`).
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<CommunityBloc>().add(
          const CommunityNotificationsMarkedRead(),
        );
      }
    });
  }

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inDays < 1) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${(diff.inDays / 7).floor()}w';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(
        backgroundColor: AppColors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/discover'),
        ),
        title: const Text(
          'Notifications',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppConstants.maxContentWidth,
            ),
            child: BlocBuilder<CommunityBloc, CommunityState>(
              builder: (context, state) {
                final items = state.notifications;
                if (items.isEmpty) {
                  return const EmptyStateView(
                    icon: Icons.favorite_border_rounded,
                    title: 'No notifications yet',
                    message:
                        'When someone likes your review, replies to your take, or follows you, it will appear here.',
                  );
                }

                final following =
                    state.profile?.followingUids.toSet() ?? const <String>{};

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final actorProfile =
                        state.userProfilesByUid[item.actorUid];
                    final actorName =
                        actorProfile?.displayName ?? item.actorName;
                    final isFollowingActor = following.contains(item.actorUid);

                    return InkWell(
                      onTap: () {
                        if (item.movieId != null && item.movieId! > 0) {
                          MovieDetailsRoute.push(
                            context,
                            movieId: item.movieId!,
                            initialMovie: MovieSummary(
                              id: item.movieId!,
                              title: item.movieTitle ?? 'Movie',
                            ),
                          );
                        } else {
                          UserProfileDialog.show(
                            context,
                            uid: item.actorUid,
                            fallbackName: actorName,
                            fallbackAvatarKey: item.actorAvatarKey,
                          );
                        }
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: item.isRead
                              ? AppColors.surfaceCard
                              : AppColors.pacificBlue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: item.isRead
                                ? AppColors.surfaceBorder
                                : AppColors.pacificBlue.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: () => UserProfileDialog.show(
                                context,
                                uid: item.actorUid,
                                fallbackName: actorName,
                                fallbackAvatarKey: item.actorAvatarKey,
                              ),
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  UserAvatar(
                                    avatarKey:
                                        actorProfile?.avatarKey ??
                                        item.actorAvatarKey,
                                    photoBase64: actorProfile?.photoBase64,
                                    reputation: actorProfile?.reputation ?? 0,
                                    isAdmin: state.adminUids.contains(
                                      item.actorUid,
                                    ),
                                    isModerator: state.moderatorUids.contains(
                                      item.actorUid,
                                    ),
                                    radius: 21,
                                  ),
                                  Positioned(
                                    right: -3,
                                    bottom: -3,
                                    child: _TypeBadge(type: item.type),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  RichText(
                                    text: TextSpan(
                                      style: const TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 13.5,
                                        height: 1.35,
                                      ),
                                      children: [
                                        TextSpan(
                                          text: actorName,
                                          style: const TextStyle(
                                            color: AppColors.textPrimary,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        TextSpan(text: _actionCopy(item)),
                                        if (item.movieTitle != null &&
                                            item.movieTitle!.isNotEmpty)
                                          TextSpan(
                                            text: item.movieTitle,
                                            style: const TextStyle(
                                              color: AppColors.khakiBeige,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        TextSpan(
                                          text:
                                              '  ${_relativeTime(item.createdAt)}',
                                          style: const TextStyle(
                                            color: AppColors.textMuted,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (item.snippet != null &&
                                      item.snippet!.trim().isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      item.type == AppNotificationType.reply
                                          ? '"${item.snippet!.trim()}"'
                                          : item.snippet!.trim(),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: AppColors.textMuted,
                                        fontSize: 12,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            if (item.type == AppNotificationType.follow) ...[
                              const SizedBox(width: 10),
                              isFollowingActor
                                  ? OutlinedButton(
                                      onPressed: () =>
                                          context.read<CommunityBloc>().add(
                                            CommunityFollowToggled(
                                              item.actorUid,
                                            ),
                                          ),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor:
                                            AppColors.textSecondary,
                                        side: const BorderSide(
                                          color: AppColors.surfaceBorder,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        minimumSize: Size.zero,
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      child: const Text(
                                        'Following',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    )
                                  : FilledButton(
                                      onPressed: () =>
                                          context.read<CommunityBloc>().add(
                                            CommunityFollowToggled(
                                              item.actorUid,
                                            ),
                                          ),
                                      style: FilledButton.styleFrom(
                                        backgroundColor: AppColors.pacificBlue,
                                        foregroundColor: AppColors.black,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        minimumSize: Size.zero,
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      child: const Text(
                                        'Follow Back',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  String _actionCopy(AppNotificationModel item) {
    switch (item.type) {
      case AppNotificationType.follow:
        return ' started following you.';
      case AppNotificationType.reply:
        return ' replied to your review of ';
      case AppNotificationType.like:
        return item.movieTitle != null
            ? ' liked your review of '
            : ' liked your curated list.';
    }
  }
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.type});

  final AppNotificationType type;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (type) {
      AppNotificationType.like => (Icons.favorite_rounded, AppColors.error),
      AppNotificationType.reply => (
        Icons.chat_bubble_rounded,
        AppColors.pacificBlue,
      ),
      AppNotificationType.follow => (
        Icons.person_add_alt_1_rounded,
        AppColors.khakiBeige,
      ),
    };
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.black,
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 1.2),
      ),
      child: Icon(icon, size: 11, color: color),
    );
  }
}
