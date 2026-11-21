import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/auth_gate.dart';
import '../../../../core/widgets/empty_state_view.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../data/models/community_poll_model.dart';
import '../../data/repositories/community_repository.dart';
import '../bloc/community_bloc.dart';

/// Dedicated screen for browsing and voting in Community Polls (`/polls`).
class CommunityPollsScreen extends StatelessWidget {
  const CommunityPollsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUid = context.select<AuthCubit, String?>(
      (c) => c.state.user?.uid,
    );
    final isStaff = context.select<CommunityBloc, bool>(
      (b) => b.state.isStaff,
    );
    final pinnedPoll = context.select<CommunityBloc, CommunityPollModel?>(
      (b) => b.state.pinnedPoll,
    );
    final repo = sl<CommunityRepository>();

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
          'Community Polls',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          if (isStaff)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: TextButton.icon(
                onPressed: () => context.push('/admin'),
                icon: const Icon(
                  Icons.add_chart_rounded,
                  size: 16,
                  color: AppColors.pacificBlue,
                ),
                label: const Text(
                  'Manage',
                  style: TextStyle(
                    color: AppColors.pacificBlue,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppConstants.maxContentWidth,
          ),
          child: StreamBuilder<List<CommunityPollModel>>(
            stream: repo.watchPolls(),
            builder: (context, snapshot) {
              final streamedPolls = snapshot.data;
              final polls = (streamedPolls != null && streamedPolls.isNotEmpty)
                  ? streamedPolls
                  : [?pinnedPoll];

              if (snapshot.connectionState == ConnectionState.waiting &&
                  polls.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }

              if (polls.isEmpty) {
                return const EmptyStateView(
                  icon: Icons.poll_outlined,
                  title: 'No community polls yet',
                  message:
                      'Check back soon for weekly movie polls and community showdowns!',
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                itemCount: polls.length,
                separatorBuilder: (_, _) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  final rawPoll = polls[index];
                  final effectivePoll =
                      (pinnedPoll != null && pinnedPoll.id == rawPoll.id)
                      ? pinnedPoll
                      : rawPoll;

                  return _FullPollCard(
                    poll: effectivePoll,
                    isFeatured: index == 0 && effectivePoll.isPinned,
                    currentUid: currentUid,
                    onVote: (optionIndex) async {
                      final allowed = await AuthGate.requireAuth(
                        context,
                        actionLabel: 'vote in Community Polls',
                      );
                      if (!allowed || !context.mounted) return;
                      context.read<CommunityBloc>().add(
                        CommunityPollVoted(
                          pollId: effectivePoll.id,
                          optionIndex: optionIndex,
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _FullPollCard extends StatelessWidget {
  const _FullPollCard({
    required this.poll,
    required this.isFeatured,
    required this.currentUid,
    required this.onVote,
  });

  final CommunityPollModel poll;
  final bool isFeatured;
  final String? currentUid;
  final ValueChanged<int> onVote;

  @override
  Widget build(BuildContext context) {
    final selectedIndex = poll.selectedOptionFor(currentUid);
    final totalVotes = poll.totalVotes;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isFeatured
              ? AppColors.pacificBlue.withValues(alpha: 0.5)
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
                  horizontal: 9,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: (isFeatured
                          ? AppColors.pacificBlue
                          : AppColors.khakiBeige)
                      .withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.poll_rounded,
                      size: 14,
                      color: isFeatured
                          ? AppColors.pacificBlue
                          : AppColors.khakiBeige,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isFeatured ? 'Weekly Poll' : 'Community Poll',
                      style: TextStyle(
                        color: isFeatured
                            ? AppColors.pacificBlue
                            : AppColors.khakiBeige,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                '$totalVotes ${totalVotes == 1 ? 'vote' : 'votes'}',
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            poll.question,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16.5,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            selectedIndex != null
                ? 'You voted · Tap another option to switch your vote'
                : 'Tap an option below to cast your vote',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 14),
          for (var i = 0; i < poll.options.length; i++) ...[
            _PollOptionTile(
              label: poll.options[i],
              percentage: poll.percentageForOption(i),
              votes: poll.votesForOption(i),
              selected: selectedIndex == i,
              showResults: selectedIndex != null || totalVotes > 0,
              onTap: () => onVote(i),
            ),
            if (i < poll.options.length - 1) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _PollOptionTile extends StatelessWidget {
  const _PollOptionTile({
    required this.label,
    required this.percentage,
    required this.votes,
    required this.selected,
    required this.showResults,
    required this.onTap,
  });

  final String label;
  final double percentage;
  final int votes;
  final bool selected;
  final bool showResults;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pctLabel = '${(percentage * 100).round()}%';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.pacificBlue : AppColors.surfaceBorder,
            width: selected ? 1.4 : 1.0,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            if (showResults)
              Positioned.fill(
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: percentage.clamp(0.0, 1.0),
                  child: Container(
                    color:
                        (selected ? AppColors.pacificBlue : AppColors.textMuted)
                            .withValues(alpha: selected ? 0.22 : 0.12),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    selected
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 17,
                    color: selected
                        ? AppColors.pacificBlue
                        : AppColors.textMuted,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: selected
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                        fontSize: 13.5,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                  if (showResults) ...[
                    const SizedBox(width: 8),
                    Text(
                      '$pctLabel ($votes)',
                      style: TextStyle(
                        color: selected
                            ? AppColors.pacificBlue
                            : AppColors.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
