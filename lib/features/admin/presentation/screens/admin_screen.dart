import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/empty_state_view.dart';
import '../../../community/data/models/movie_review_model.dart';
import '../../../community/data/models/review_report_model.dart';
import '../../../community/data/models/user_profile_model.dart';
import '../../../community/data/repositories/community_repository.dart';
import '../../../community/presentation/cubit/community_cubit.dart';
import '../../../community/presentation/widgets/user_avatar_widget.dart';

/// Admin moderation panel (`/admin`) for reviewing reports, deleting reviews,
/// and removing/banning offending users.
class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _repo = sl<CommunityRepository>();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _confirmDeleteReview(String reviewId, String title) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: const Text('Delete Review'),
        content: Text('Permanently delete review on "$title"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dCtx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(dCtx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await _repo.adminDeleteReview(reviewId);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Review deleted.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _confirmBanAndDeleteUser(
    String uid,
    String displayName,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: const Text(
          'Delete & Ban User',
          style: TextStyle(color: AppColors.error),
        ),
        content: Text(
          'Delete "$displayName" ($uid), remove all their reviews, and ban them from CineList Community?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dCtx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(dCtx).pop(true),
            child: const Text('Delete & Ban'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await _repo.adminDeleteAndBanUser(uid);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('User "$displayName" deleted & banned.')),
        );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.select<CommunityCubit, bool>(
      (c) => c.state.isAdmin,
    );

    if (!isAdmin) {
      return Scaffold(
        backgroundColor: AppColors.black,
        appBar: AppBar(title: const Text('Admin Panel')),
        body: EmptyStateView(
          icon: Icons.lock_outline_rounded,
          title: 'Admin Access Required',
          message: 'This panel is restricted to CineList administrators.',
          actionLabel: 'Go Back',
          onAction: () =>
              context.canPop() ? context.pop() : context.go('/discover'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(
        backgroundColor: AppColors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/community'),
        ),
        title: const Text(
          'Admin Moderation Panel',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.pacificBlue,
          labelColor: AppColors.pacificBlue,
          unselectedLabelColor: AppColors.textSecondary,
          tabs: const [
            Tab(text: 'Reports'),
            Tab(text: 'Reviews'),
            Tab(text: 'Users'),
          ],
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppConstants.maxContentWidth,
          ),
          child: TabBarView(
            controller: _tabController,
            children: [
              _ReportsTab(
                repo: _repo,
                onDeleteReview: _confirmDeleteReview,
                onBanUser: _confirmBanAndDeleteUser,
              ),
              _AllReviewsTab(
                repo: _repo,
                onDeleteReview: _confirmDeleteReview,
              ),
              _UsersTab(repo: _repo, onBanUser: _confirmBanAndDeleteUser),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReportsTab extends StatelessWidget {
  const _ReportsTab({
    required this.repo,
    required this.onDeleteReview,
    required this.onBanUser,
  });

  final CommunityRepository repo;
  final Future<void> Function(String reviewId, String title) onDeleteReview;
  final Future<void> Function(String uid, String displayName) onBanUser;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ReviewReportModel>>(
      stream: repo.watchReports(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final reports = snapshot.data ?? const [];
        if (reports.isEmpty) {
          return const EmptyStateView(
            icon: Icons.verified_user_outlined,
            title: 'No reports yet',
            message: 'Reported reviews will appear here for moderation.',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: reports.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final r = reports[index];
            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surfaceCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: r.isPending
                      ? AppColors.error.withValues(alpha: 0.5)
                      : AppColors.surfaceBorder,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          r.reason.label,
                          style: const TextStyle(
                            color: AppColors.error,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: r.isPending
                              ? AppColors.warning.withValues(alpha: 0.18)
                              : AppColors.success.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          r.isPending ? 'Pending' : 'Resolved',
                          style: TextStyle(
                            color: r.isPending
                                ? AppColors.warning
                                : AppColors.success,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${r.reportedAuthorName} on "${r.movieTitle}"',
                    style: const TextStyle(
                      color: AppColors.khakiBeige,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '"${r.reviewComment}"',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13.5,
                    ),
                  ),
                  if (r.details.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Reporter note: ${r.details}',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () =>
                            onDeleteReview(r.reviewId, r.movieTitle),
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          size: 16,
                          color: AppColors.error,
                        ),
                        label: const Text(
                          'Delete Review',
                          style: TextStyle(color: AppColors.error),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () =>
                            onBanUser(r.reportedUid, r.reportedAuthorName),
                        icon: const Icon(
                          Icons.person_off_outlined,
                          size: 16,
                          color: AppColors.error,
                        ),
                        label: const Text(
                          'Ban User',
                          style: TextStyle(color: AppColors.error),
                        ),
                      ),
                      if (r.isPending)
                        TextButton(
                          onPressed: () => repo.resolveReport(r.id),
                          child: const Text('Dismiss'),
                        ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _AllReviewsTab extends StatelessWidget {
  const _AllReviewsTab({required this.repo, required this.onDeleteReview});

  final CommunityRepository repo;
  final Future<void> Function(String reviewId, String title) onDeleteReview;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<MovieReviewModel>>(
      stream: repo.watchRecentReviews(limit: 100),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final reviews = snapshot.data ?? const [];
        if (reviews.isEmpty) {
          return const EmptyStateView(
            icon: Icons.rate_review_outlined,
            title: 'No reviews',
            message: 'Community reviews will appear here.',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: reviews.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final review = reviews[index];
            return ListTile(
              tileColor: AppColors.surfaceCard,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: AppColors.surfaceBorder),
              ),
              leading: UserAvatar(
                avatarKey: review.authorAvatarKey,
                radius: 18,
              ),
              title: Text(
                '${review.authorName} · ${review.movieTitle} (${review.rating}★)',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                ),
              ),
              subtitle: Text(
                review.comment,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12.5,
                ),
              ),
              trailing: IconButton(
                tooltip: 'Delete review',
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: AppColors.error,
                ),
                onPressed: () => onDeleteReview(review.id, review.movieTitle),
              ),
            );
          },
        );
      },
    );
  }
}

class _UsersTab extends StatelessWidget {
  const _UsersTab({required this.repo, required this.onBanUser});

  final CommunityRepository repo;
  final Future<void> Function(String uid, String displayName) onBanUser;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<UserProfileModel>>(
      stream: repo.watchAllUsers(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final users = snapshot.data ?? const [];
        if (users.isEmpty) {
          return const EmptyStateView(
            icon: Icons.people_outline_rounded,
            title: 'No user profiles',
            message: 'Registered user profiles will appear here.',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: users.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final u = users[index];
            return ListTile(
              tileColor: AppColors.surfaceCard,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: AppColors.surfaceBorder),
              ),
              leading: UserAvatar(avatarKey: u.avatarKey, radius: 18),
              title: Text(
                u.displayName,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: Text(
                u.bio.isNotEmpty ? '${u.bio}\nUID: ${u.uid}' : 'UID: ${u.uid}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              trailing: IconButton(
                tooltip: 'Delete & Ban User',
                icon: const Icon(
                  Icons.person_off_outlined,
                  color: AppColors.error,
                ),
                onPressed: () => onBanUser(u.uid, u.displayName),
              ),
            );
          },
        );
      },
    );
  }
}

