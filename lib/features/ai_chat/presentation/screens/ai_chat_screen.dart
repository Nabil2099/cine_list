import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/routing/movie_details_route.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../discover/data/repositories/discover_repository.dart';
import '../../../watchlist/presentation/cubit/watchlist_cubit.dart';
import '../../data/models/chat_message_model.dart';
import '../cubit/ai_chat_cubit.dart';
import '../cubit/ai_chat_state.dart';
import '../widgets/formatted_chat_text.dart';

class _MoodOption {
  const _MoodOption(this.label, this.emoji, this.prompt);

  final String label;
  final String emoji;
  final String prompt;
}

class _RecommendedMoviePick {
  const _RecommendedMoviePick({required this.title, this.year});

  final String title;
  final String? year;

  String get displayLabel => year != null ? '$title ($year)' : title;
}

/// AI Movie Concierge chatbot screen grounded in the user's watchlist.
class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();

  static const _quickPrompts = [
    'Recommend 5 movies based on my watchlist',
    'What should I watch tonight?',
    'Suggest hidden gems similar to my watched movies',
    'Pick something from my Want to Watch list',
  ];

  static const _moods = [
    _MoodOption(
      'Mind-Bending',
      '🧠',
      'I want a mind-bending movie tonight based on my watchlist.',
    ),
    _MoodOption(
      'Cozy Comfort',
      '☕',
      'Recommend a cozy, feel-good comfort movie tailored to my taste.',
    ),
    _MoodOption(
      'Adrenaline',
      '⚡',
      'Give me high-energy action or thriller picks based on my watchlist.',
    ),
    _MoodOption(
      '90-Min Quick Watch',
      '⏱️',
      'Suggest great movies around 90 minutes long that match my watchlist.',
    ),
    _MoodOption(
      'Hidden Gem',
      '💎',
      'Recommend underrated hidden gems I probably have not seen yet.',
    ),
  ];

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _send([String? overrideText]) {
    final text = (overrideText ?? _inputController.text).trim();
    if (text.isEmpty) return;

    if (overrideText == null) {
      _inputController.clear();
    }

    final watchlist = context.read<WatchlistCubit>().state.movies;
    context.read<AiChatCubit>().sendMessage(text, watchlist: watchlist);
    _scrollToBottom();
  }

  Future<void> _openRecommendedMovie(_RecommendedMoviePick pick) async {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Looking up "${pick.displayLabel}" on TMDB...'),
          duration: const Duration(seconds: 2),
        ),
      );

    try {
      final response = await sl<DiscoverRepository>().searchMovies(
        query: pick.title,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      if (response.results.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not find "${pick.title}" on TMDB.')),
        );
        return;
      }

      var match = response.results.first;
      if (pick.year != null) {
        for (final candidate in response.results) {
          if ((candidate.releaseDate ?? '').startsWith(pick.year!)) {
            match = candidate;
            break;
          }
        }
      }

      Navigator.of(
        context,
      ).push(MovieDetailsRoute.build(movieId: match.id, initialMovie: match));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to look up "${pick.title}" right now.')),
      );
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 120,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final watchlistCount = context.select<WatchlistCubit, int>(
      (cubit) => cubit.state.movies.length,
    );

    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: Column(
            children: [
              _AiHeader(
                watchlistCount: watchlistCount,
                onClear: () => context.read<AiChatCubit>().clearChat(),
              ),
              _MoodPickerBar(moods: _moods, onMoodTap: (m) => _send(m.prompt)),
              const SizedBox(height: 6),
              Expanded(
                child: BlocConsumer<AiChatCubit, AiChatState>(
                  listenWhen: (prev, curr) =>
                      prev.messages.length != curr.messages.length ||
                      prev.isSending != curr.isSending,
                  listener: (_, _) => _scrollToBottom(),
                  builder: (context, state) {
                    if (state.messages.isEmpty) {
                      return _AiEmptyPrompts(
                        watchlistCount: watchlistCount,
                        prompts: _quickPrompts,
                        onPromptTap: (p) => _send(p),
                      );
                    }

                    final itemCount =
                        state.messages.length + (state.isSending ? 1 : 0);

                    return ListView.separated(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                      itemCount: itemCount,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        if (state.isSending && index == state.messages.length) {
                          return const _TypingBubble();
                        }
                        return _ChatBubble(
                          message: state.messages[index],
                          onMovieTap: _openRecommendedMovie,
                        );
                      },
                    );
                  },
                ),
              ),
              _ChatInputBar(
                controller: _inputController,
                onSend: () => _send(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MoodPickerBar extends StatelessWidget {
  const _MoodPickerBar({required this.moods, required this.onMoodTap});

  final List<_MoodOption> moods;
  final ValueChanged<_MoodOption> onMoodTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: moods.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final mood = moods[index];
          return InkWell(
            onTap: () => onMoodTap(mood),
            borderRadius: BorderRadius.circular(18),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.surfaceCard,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: AppColors.softPeriwinkle.withValues(alpha: 0.35),
                ),
              ),
              child: Text(
                '${mood.emoji} ${mood.label}',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AiHeader extends StatelessWidget {
  const _AiHeader({required this.watchlistCount, required this.onClear});

  final int watchlistCount;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final hasMessages = context.select<AiChatCubit, bool>(
      (c) => c.state.messages.isNotEmpty,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 16, 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.pacificBlue.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.pacificBlue.withValues(alpha: 0.45),
              ),
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: AppColors.pacificBlue,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${AppConstants.appName} AI',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  '$watchlistCount ${watchlistCount == 1 ? 'movie' : 'movies'} in your watchlist context',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          if (hasMessages)
            IconButton(
              onPressed: onClear,
              tooltip: 'New chat',
              icon: const Icon(
                Icons.refresh_rounded,
                color: AppColors.textSecondary,
              ),
            ),
        ],
      ),
    );
  }
}

class _AiEmptyPrompts extends StatelessWidget {
  const _AiEmptyPrompts({
    required this.watchlistCount,
    required this.prompts,
    required this.onPromptTap,
  });

  final int watchlistCount;
  final List<String> prompts;
  final ValueChanged<String> onPromptTap;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.pacificBlue.withValues(alpha: 0.24),
                  AppColors.softPeriwinkle.withValues(alpha: 0.2),
                ],
              ),
              border: Border.all(
                color: AppColors.pacificBlue.withValues(alpha: 0.4),
              ),
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: AppColors.khakiBeige,
              size: 36,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Your Personal Movie Concierge',
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            watchlistCount > 0
                ? 'Pick a mood above or ask for recommendations tailored to your $watchlistCount saved movies.'
                : 'Pick a mood above or ask for curated movie recommendations anytime.',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: prompts
                .map(
                  (prompt) => ActionChip(
                    label: Text(
                      prompt,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                      ),
                    ),
                    backgroundColor: AppColors.surfaceCard,
                    side: const BorderSide(color: AppColors.surfaceBorder),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    onPressed: () => onPromptTap(prompt),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message, required this.onMovieTap});

  final ChatMessageModel message;
  final ValueChanged<_RecommendedMoviePick> onMovieTap;

  static final RegExp _movieTitlePattern = RegExp(
    r'\*\*([^*()\n]{2,60}?)\s*\((\d{4})\)\*\*',
  );

  List<_RecommendedMoviePick> _extractPicks(String text) {
    final picks = <_RecommendedMoviePick>[];
    final seen = <String>{};
    for (final match in _movieTitlePattern.allMatches(text)) {
      final title = match.group(1)?.trim() ?? '';
      final year = match.group(2)?.trim();
      if (title.isNotEmpty && seen.add(title.toLowerCase())) {
        picks.add(_RecommendedMoviePick(title: title, year: year));
      }
    }
    return picks;
  }

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final isError = message.isError;
    final picks = (!isUser && !isError)
        ? _extractPicks(message.text)
        : const <_RecommendedMoviePick>[];

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 8 * (1 - value)),
          child: child,
        ),
      ),
      child: Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.84,
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
            decoration: BoxDecoration(
              color: isUser
                  ? AppColors.pacificBlue
                  : isError
                  ? AppColors.error.withValues(alpha: 0.14)
                  : AppColors.surfaceCard,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18),
                topRight: const Radius.circular(18),
                bottomLeft: Radius.circular(isUser ? 18 : 4),
                bottomRight: Radius.circular(isUser ? 4 : 18),
              ),
              border: isUser
                  ? null
                  : Border.all(
                      color: isError
                          ? AppColors.error.withValues(alpha: 0.5)
                          : AppColors.surfaceBorder,
                    ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isUser && !isError) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.auto_awesome_rounded,
                            size: 13,
                            color: AppColors.pacificBlue,
                          ),
                          SizedBox(width: 5),
                          Text(
                            'CineList AI',
                            style: TextStyle(
                              color: AppColors.pacificBlue,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      InkWell(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: message.text));
                          ScaffoldMessenger.of(context)
                            ..hideCurrentSnackBar()
                            ..showSnackBar(
                              const SnackBar(
                                content: Text('Copied recommendation'),
                              ),
                            );
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: const Padding(
                          padding: EdgeInsets.all(2),
                          child: Icon(
                            Icons.copy_rounded,
                            size: 14,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                ],
                FormattedChatText(
                  text: message.text,
                  baseColor: isUser ? AppColors.black : AppColors.textPrimary,
                  boldColor: isUser ? AppColors.black : AppColors.khakiBeige,
                ),
                if (picks.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: picks
                        .map(
                          (pick) => InkWell(
                            onTap: () => onMovieTap(pick),
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.pacificBlue.withValues(
                                  alpha: 0.14,
                                ),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: AppColors.pacificBlue.withValues(
                                    alpha: 0.45,
                                  ),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.movie_outlined,
                                    size: 14,
                                    color: AppColors.pacificBlue,
                                  ),
                                  const SizedBox(width: 5),
                                  ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 210,
                                    ),
                                    child: Text(
                                      pick.displayLabel,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: AppColors.pacificBlue,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(
                                    Icons.arrow_forward_ios_rounded,
                                    size: 11,
                                    color: AppColors.pacificBlue,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomRight: Radius.circular(18),
            bottomLeft: Radius.circular(4),
          ),
          border: Border.all(color: AppColors.surfaceBorder),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.pacificBlue,
              ),
            ),
            SizedBox(width: 10),
            Text(
              'Thinking...',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatInputBar extends StatelessWidget {
  const _ChatInputBar({required this.controller, required this.onSend});

  final TextEditingController controller;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final isSending = context.select<AiChatCubit, bool>(
      (c) => c.state.isSending,
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: const BoxDecoration(
        color: AppColors.surfaceElevated,
        border: Border(
          top: BorderSide(color: AppColors.surfaceBorder, width: 0.8),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              enabled: !isSending,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              maxLines: 3,
              minLines: 1,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14.5,
              ),
              decoration: InputDecoration(
                hintText: 'Ask CineList AI for movie picks...',
                filled: true,
                fillColor: AppColors.surfaceInput,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: const BorderSide(color: AppColors.surfaceBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: const BorderSide(color: AppColors.surfaceBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: const BorderSide(
                    color: AppColors.pacificBlue,
                    width: 1.4,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          IconButton.filled(
            onPressed: isSending ? null : onSend,
            style: IconButton.styleFrom(
              backgroundColor: AppColors.pacificBlue,
              foregroundColor: AppColors.black,
              disabledBackgroundColor: AppColors.pacificBlue.withValues(
                alpha: 0.4,
              ),
              fixedSize: const Size(46, 46),
            ),
            icon: const Icon(Icons.send_rounded, size: 20),
            tooltip: 'Send',
          ),
        ],
      ),
    );
  }
}
