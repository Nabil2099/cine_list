import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/models/app_notification_model.dart';
import '../../data/models/movie_review_model.dart';
import '../../data/models/review_comment_model.dart';
import '../../data/repositories/community_repository.dart';
import '../bloc/community_bloc.dart';
import 'user_avatar_widget.dart';

/// Modal bottom sheet displaying and composing replies for a community review.
class ReviewRepliesSheet extends StatefulWidget {
  const ReviewRepliesSheet({
    super.key,
    required this.review,
    required this.repository,
  });

  final MovieReviewModel review;
  final CommunityRepository repository;

  static Future<void> show(
    BuildContext context, {
    required MovieReviewModel review,
    required CommunityRepository repository,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => BlocProvider.value(
        value: context.read<CommunityBloc>(),
        child: ReviewRepliesSheet(review: review, repository: repository),
      ),
    );
  }

  @override
  State<ReviewRepliesSheet> createState() => _ReviewRepliesSheetState();
}

class _ReviewRepliesSheetState extends State<ReviewRepliesSheet> {
  final _controller = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submitReply() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isSubmitting) return;

    final bloc = context.read<CommunityBloc>();
    final uid = bloc.currentUid;
    final profile = bloc.state.profile;
    if (uid == null) return;

    setState(() => _isSubmitting = true);
    try {
      await widget.repository.addReviewComment(
        reviewId: widget.review.id,
        comment: ReviewCommentModel(
          id: '',
          reviewId: widget.review.id,
          uid: uid,
          authorName: profile?.displayName ?? 'Movie Fan',
          authorAvatarKey: profile?.avatarKey ?? 'cinema',
          text: text,
          createdAt: DateTime.now(),
        ),
      );
      await widget.repository.createNotification(
        recipientUid: widget.review.uid,
        notification: AppNotificationModel(
          id: '',
          type: AppNotificationType.reply,
          actorUid: uid,
          actorName: profile?.displayName ?? 'Movie Fan',
          actorAvatarKey: profile?.avatarKey ?? 'cinema',
          movieId: widget.review.movieId,
          movieTitle: widget.review.movieTitle,
          reviewId: widget.review.id,
          snippet: text,
          createdAt: DateTime.now(),
        ),
      );
      if (mounted) {
        _controller.clear();
      }
    } on AppException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final bloc = context.watch<CommunityBloc>();
    final currentUid = bloc.currentUid;
    final isStaff = bloc.state.isStaff;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.surfaceBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Replies to ${widget.review.authorName}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            widget.review.movieTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.surfaceBorder),
              Expanded(
                child: StreamBuilder<List<ReviewCommentModel>>(
                  stream: widget.repository.watchReviewComments(
                    widget.review.id,
                  ),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting &&
                        !snapshot.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.pacificBlue,
                        ),
                      );
                    }
                    final comments = snapshot.data ?? const [];
                    if (comments.isEmpty) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'No replies yet. Start the discussion!',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 13.5,
                            ),
                          ),
                        ),
                      );
                    }
                    return ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: comments.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final c = comments[index];
                        final authorProfile =
                            bloc.state.userProfilesByUid[c.uid];
                        final canDelete = c.uid == currentUid || isStaff;
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceElevated,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.surfaceBorder),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              UserAvatar(
                                avatarKey:
                                    authorProfile?.avatarKey ??
                                    c.authorAvatarKey,
                                photoBase64: authorProfile?.photoBase64,
                                reputation: authorProfile?.reputation ?? 0,
                                isAdmin: bloc.state.adminUids.contains(c.uid),
                                isModerator:
                                    bloc.state.moderatorUids.contains(c.uid),
                                radius: 15,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      authorProfile?.displayName ??
                                          c.authorName,
                                      style: const TextStyle(
                                        color: AppColors.textPrimary,
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      c.text,
                                      style: const TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 13,
                                        height: 1.35,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (canDelete)
                                IconButton(
                                  onPressed: () =>
                                      widget.repository.deleteReviewComment(
                                        reviewId: widget.review.id,
                                        commentId: c.id,
                                      ),
                                  icon: const Icon(
                                    Icons.delete_outline_rounded,
                                    size: 16,
                                    color: AppColors.textMuted,
                                  ),
                                  visualDensity: VisualDensity.compact,
                                  tooltip: 'Delete reply',
                                ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                decoration: const BoxDecoration(
                  color: AppColors.surfaceElevated,
                  border: Border(
                    top: BorderSide(color: AppColors.surfaceBorder),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        maxLength: 300,
                        minLines: 1,
                        maxLines: 3,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13.5,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Write a reply...',
                          counterText: '',
                          isDense: true,
                          filled: true,
                          fillColor: AppColors.surfaceCard,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: const BorderSide(
                              color: AppColors.surfaceBorder,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: _isSubmitting ? null : _submitReply,
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.pacificBlue,
                        foregroundColor: AppColors.black,
                      ),
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.black,
                              ),
                            )
                          : const Icon(Icons.send_rounded, size: 18),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
