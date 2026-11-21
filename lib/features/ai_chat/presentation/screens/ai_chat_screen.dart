import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/decoded_image_cache.dart';
import '../../../../core/widgets/profile_drawer_button.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../auth/presentation/cubit/auth_state.dart';
import '../../../community/data/models/movie_review_model.dart';
import '../../../community/presentation/bloc/community_bloc.dart';
import '../../../watchlist/presentation/cubit/watchlist_cubit.dart';
import '../../data/models/ai_chat_context.dart';
import '../../data/models/chat_message_model.dart';
import '../cubit/ai_chat_cubit.dart';
import '../cubit/ai_chat_state.dart';
import '../widgets/ai_pick_cards_row.dart';
import '../widgets/formatted_chat_text.dart';

class _MoodOption {
  const _MoodOption(this.label, this.emoji, this.prompt);

  final String label;
  final String emoji;
  final String prompt;
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
  String? _pendingImageBase64;
  String? _pendingImageMimeType;
  bool _pickingImage = false;

  static const _quickPrompts = [
    'Recommend 5 movies based on my watchlist',
    'Build a 5-movie marathon based on my taste',
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

  Future<void> _pickImage(ImageSource source) async {
    if (_pickingImage) return;
    setState(() => _pickingImage = true);
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 78,
      );
      if (picked != null && mounted) {
        final bytes = await picked.readAsBytes();
        if (bytes.lengthInBytes > 1500000) {
          if (mounted) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                const SnackBar(
                  content: Text('Please choose a smaller image (under 1.5 MB).'),
                ),
              );
          }
          return;
        }
        final ext = picked.name.toLowerCase();
        final mime = ext.endsWith('.png')
            ? 'image/png'
            : ext.endsWith('.webp')
            ? 'image/webp'
            : 'image/jpeg';
        setState(() {
          _pendingImageBase64 = base64Encode(bytes);
          _pendingImageMimeType = mime;
        });
      }
    } on MissingPluginException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Image picker requires a full app rebuild (stop & run flutter run).',
            ),
          ),
        );
      }
    } on PlatformException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message ?? 'Could not access camera or gallery.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _pickingImage = false);
    }
  }

  Future<void> _showImageSourcePicker() async {
    if (kIsWeb) {
      await _pickImage(ImageSource.gallery);
      return;
    }
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(
                Icons.camera_alt_rounded,
                color: AppColors.pacificBlue,
              ),
              title: const Text(
                'Take Photo of Poster / Shelf',
                style: TextStyle(color: AppColors.textPrimary),
              ),
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(
                Icons.photo_library_rounded,
                color: AppColors.khakiBeige,
              ),
              title: const Text(
                'Choose from Gallery',
                style: TextStyle(color: AppColors.textPrimary),
              ),
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source != null && mounted) {
      await _pickImage(source);
    }
  }

  void _send([String? overrideText]) {
    final text = (overrideText ?? _inputController.text).trim();
    final imageBase64 = overrideText == null ? _pendingImageBase64 : null;
    final imageMime = overrideText == null ? _pendingImageMimeType : null;
    if (text.isEmpty && (imageBase64 == null || imageBase64.isEmpty)) return;

    if (overrideText == null) {
      _inputController.clear();
      if (_pendingImageBase64 != null) {
        setState(() {
          _pendingImageBase64 = null;
          _pendingImageMimeType = null;
        });
      }
    }

    final watchlistState = context.read<WatchlistCubit>().state;
    final communityState = context.read<CommunityBloc>().state;
    final followingUids =
        communityState.profile?.followingUids.toSet() ?? const <String>{};
    final followedReviews = followingUids.isEmpty
        ? const <MovieReviewModel>[]
        : communityState.reviews
              .where((r) => followingUids.contains(r.uid))
              .toList();

    final aiContext = AiChatContext(
      watchlist: watchlistState.movies,
      collections: watchlistState.collections,
      activeChallenge: communityState.activeChallenge,
      followedReviews: followedReviews,
    );

    context.read<AiChatCubit>().sendMessage(
      text,
      context: aiContext,
      imageBase64: imageBase64,
      imageMimeType: imageMime,
    );
    _scrollToBottom();
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
    final isSignedIn = context.select<AuthCubit, bool>(
      (c) => c.state.status == AuthStatus.authenticated,
    );
    final watchlistCount = context.select<WatchlistCubit, int>(
      (cubit) => cubit.state.movies.length,
    );
    final viewportWidth = MediaQuery.sizeOf(context).width;
    final isWideWeb = kIsWeb && viewportWidth >= AppConstants.tabletBreakpoint;

    return ColoredBox(
      color: AppColors.black,
      child: SafeArea(
        child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: Column(
            children: [
              _AiHeader(
                isSignedIn: isSignedIn,
                showDrawerButton: !isWideWeb,
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
                        isSignedIn: isSignedIn,
                        watchlistCount: watchlistCount,
                        prompts: _quickPrompts,
                        onPromptTap: (p) => _send(p),
                      );
                    }

                    return ListView.separated(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                      itemCount: state.messages.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final msg = state.messages[index];
                        final isStreamingMsg =
                            state.isSending &&
                            index == state.messages.length - 1 &&
                            !msg.isUser;
                        if (isStreamingMsg && msg.text.isEmpty) {
                          return const _TypingBubble();
                        }
                        return _ChatBubble(
                          message: msg,
                          isStreaming: isStreamingMsg,
                        );
                      },
                    );
                  },
                ),
              ),
              if (_pendingImageBase64 != null)
                _PendingImageBar(
                  imageBase64: _pendingImageBase64!,
                  onRemove: () => setState(() {
                    _pendingImageBase64 = null;
                    _pendingImageMimeType = null;
                  }),
                ),
              _ChatInputBar(
                controller: _inputController,
                onSend: () => _send(),
                onPickImage: _showImageSourcePicker,
                hasPendingImage: _pendingImageBase64 != null,
              ),
            ],
          ),
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
  const _AiHeader({
    required this.isSignedIn,
    required this.showDrawerButton,
    required this.watchlistCount,
    required this.onClear,
  });

  final bool isSignedIn;
  final bool showDrawerButton;
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
          if (showDrawerButton) ...[
            const ProfileDrawerButton(),
            const SizedBox(width: 12),
          ],
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
                  isSignedIn
                      ? '$watchlistCount ${watchlistCount == 1 ? 'movie' : 'movies'} in your watchlist context'
                      : 'Ask for movie night picks & recommendations',
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
    required this.isSignedIn,
    required this.watchlistCount,
    required this.prompts,
    required this.onPromptTap,
  });

  final bool isSignedIn;
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
            isSignedIn && watchlistCount > 0
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
  const _ChatBubble({required this.message, this.isStreaming = false});

  final ChatMessageModel message;
  final bool isStreaming;

  static final RegExp _movieTitlePattern = RegExp(
    r'\*\*([^*()\n]{2,60}?)\s*\((\d{4})\)\*\*',
  );

  List<AiRecommendedPick> _extractPicks(String text) {
    final picks = <AiRecommendedPick>[];
    final seen = <String>{};
    for (final match in _movieTitlePattern.allMatches(text)) {
      final title = match.group(1)?.trim() ?? '';
      final year = match.group(2)?.trim();
      if (title.isNotEmpty && seen.add(title.toLowerCase())) {
        picks.add(AiRecommendedPick(title: title, year: year));
      }
    }
    return picks;
  }

  void _showEnlargedImage(
    BuildContext context,
    ImageProvider<Object> imageProvider,
  ) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.9),
      builder: (dialogContext) => Dialog.fullscreen(
        backgroundColor: Colors.transparent,
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: () => Navigator.of(dialogContext).pop(),
                child: InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 4.0,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image(
                          image: imageProvider,
                          fit: BoxFit.contain,
                          gaplessPlayback: true,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 16,
              right: 16,
              child: SafeArea(
                child: IconButton.filled(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.surfaceElevated.withValues(
                      alpha: 0.9,
                    ),
                    foregroundColor: AppColors.textPrimary,
                  ),
                  icon: const Icon(Icons.close_rounded),
                  tooltip: 'Close preview',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final isError = message.isError;
    final picks = (!isUser && !isError && !isStreaming)
        ? _extractPicks(message.text)
        : const <AiRecommendedPick>[];
    final imgProvider = message.hasImage
        ? DecodedImageCache.getOrDecode(message.imageBase64)
        : null;

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
          child: Column(
            crossAxisAlignment: isUser
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              if (imgProvider != null) ...[
                GestureDetector(
                  onTap: () => _showEnlargedImage(context, imgProvider),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.pacificBlue.withValues(alpha: 0.55),
                        width: 1.5,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12.5),
                      child: Stack(
                        children: [
                          Image(
                            image: imgProvider,
                            width: 72,
                            height: 72,
                            fit: BoxFit.cover,
                            gaplessPlayback: true,
                            errorBuilder: (_, _, _) => const SizedBox.shrink(),
                          ),
                          Positioned(
                            right: 4,
                            bottom: 4,
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.65),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(
                                Icons.zoom_out_map_rounded,
                                size: 11,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
              ],
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 15,
                  vertical: 12,
                ),
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
                              Clipboard.setData(
                                ClipboardData(text: message.text),
                              );
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
                      baseColor: isUser
                          ? AppColors.black
                          : AppColors.textPrimary,
                      boldColor: isUser
                          ? AppColors.black
                          : AppColors.khakiBeige,
                    ),
                    if (picks.isNotEmpty) AiPickCardsRow(picks: picks),
                  ],
                ),
              ),
            ],
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

class _PendingImageBar extends StatelessWidget {
  const _PendingImageBar({
    required this.imageBase64,
    required this.onRemove,
  });

  final String imageBase64;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      color: AppColors.surfaceElevated,
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: switch (DecodedImageCache.getOrDecode(imageBase64)) {
                  final imgProvider? => Image(
                    image: imgProvider,
                    width: 54,
                    height: 54,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                    errorBuilder: (_, _, _) => const SizedBox(
                      width: 54,
                      height: 54,
                      child: Icon(Icons.broken_image_outlined),
                    ),
                  ),
                  null => const SizedBox(
                    width: 54,
                    height: 54,
                    child: Icon(Icons.broken_image_outlined),
                  ),
                },
              ),
              Positioned(
                top: -6,
                right: -6,
                child: InkWell(
                  onTap: onRemove,
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: AppColors.error,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      size: 13,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Photo attached — add a question or tap Send to identify movies.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatInputBar extends StatelessWidget {
  const _ChatInputBar({
    required this.controller,
    required this.onSend,
    required this.onPickImage,
    this.hasPendingImage = false,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback onPickImage;
  final bool hasPendingImage;

  @override
  Widget build(BuildContext context) {
    final isSending = context.select<AiChatCubit, bool>(
      (c) => c.state.isSending,
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 14, 12),
      decoration: const BoxDecoration(
        color: AppColors.surfaceElevated,
        border: Border(
          top: BorderSide(color: AppColors.surfaceBorder, width: 0.8),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: isSending ? null : onPickImage,
            tooltip: 'Scan movie poster or shelf',
            icon: Icon(
              Icons.add_a_photo_outlined,
              color: hasPendingImage
                  ? AppColors.khakiBeige
                  : AppColors.textSecondary,
              size: 22,
            ),
          ),
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
                hintText: hasPendingImage
                    ? 'Ask about this photo (optional)...'
                    : 'Ask CineList AI or snap a poster...',
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
