import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/rating_badge.dart';
import '../../../../shared/models/movie_summary.dart';
import '../../../../shared/widgets/movie_poster.dart';

class UnifiedReviewResult {
  const UnifiedReviewResult({
    required this.rating,
    required this.reviewText,
    required this.publishToCommunity,
    required this.hasSpoilers,
  });

  final int? rating;
  final String reviewText;
  final bool publishToCommunity;
  final bool hasSpoilers;
}

/// Dedicated full-screen composer unifying personal rating/notes and public
/// community reviews, with keyboard-safe layout and high-contrast toggles.
class RateReviewScreen extends StatefulWidget {
  const RateReviewScreen({
    super.key,
    required this.movie,
    this.initialRating,
    this.initialText,
    this.initialPublishToCommunity = false,
    this.initialHasSpoilers = false,
    this.isEditingExistingCommunityReview = false,
  });

  final MovieSummary movie;
  final int? initialRating;
  final String? initialText;
  final bool initialPublishToCommunity;
  final bool initialHasSpoilers;
  final bool isEditingExistingCommunityReview;

  static Future<UnifiedReviewResult?> open(
    BuildContext context, {
    required MovieSummary movie,
    int? initialRating,
    String? initialText,
    bool initialPublishToCommunity = false,
    bool initialHasSpoilers = false,
    bool isEditingExistingCommunityReview = false,
  }) {
    return Navigator.of(context).push<UnifiedReviewResult>(
      MaterialPageRoute<UnifiedReviewResult>(
        fullscreenDialog: true,
        builder: (_) => RateReviewScreen(
          movie: movie,
          initialRating: initialRating,
          initialText: initialText,
          initialPublishToCommunity: initialPublishToCommunity,
          initialHasSpoilers: initialHasSpoilers,
          isEditingExistingCommunityReview: isEditingExistingCommunityReview,
        ),
      ),
    );
  }

  @override
  State<RateReviewScreen> createState() => _RateReviewScreenState();
}

class _RateReviewScreenState extends State<RateReviewScreen> {
  late int? _rating;
  late bool _publishToCommunity;
  late bool _hasSpoilers;
  late final TextEditingController _textController;
  String? _validationError;

  static const _ratingLabels = <int, String>{
    1: '1/5 · Not for me',
    2: '2/5 · Meh',
    3: '3/5 · Solid',
    4: '4/5 · Great',
    5: '5/5 · Masterpiece',
  };

  @override
  void initState() {
    super.initState();
    _rating = widget.initialRating?.clamp(1, 5);
    _publishToCommunity = widget.initialPublishToCommunity;
    _hasSpoilers = widget.initialHasSpoilers;
    _textController = TextEditingController(text: widget.initialText ?? '');
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _textController.text.trim();
    if (_publishToCommunity) {
      if (_rating == null) {
        setState(() {
          _validationError =
              'Select a 1–5 star rating to post your review to Community.';
        });
        return;
      }
      if (text.length < 5) {
        setState(() {
          _validationError =
              'Write at least 5 characters to share a review with Community.';
        });
        return;
      }
    }

    Navigator.of(context).pop(
      UnifiedReviewResult(
        rating: _rating,
        reviewText: text,
        publishToCommunity: _publishToCommunity,
        hasSpoilers: _publishToCommunity && _hasSpoilers,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final yearText = Formatters.releaseYear(widget.movie.releaseDate);
    final ratingLabel = _rating != null
        ? _ratingLabels[_rating!]!
        : 'Tap a star to rate';

    return Scaffold(
      backgroundColor: AppColors.black,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceBase,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close_rounded),
          tooltip: 'Close',
        ),
        title: Text(
          widget.isEditingExistingCommunityReview
              ? 'Edit Review'
              : 'Rate & Review',
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton(
              onPressed: _submit,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.pacificBlue,
                foregroundColor: AppColors.black,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                _publishToCommunity ? 'Post' : 'Save',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Movie Context Header
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceCard,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.surfaceBorder),
                    ),
                    child: Row(
                      children: [
                        MoviePoster(
                          posterPath: widget.movie.posterPath,
                          width: 60,
                          height: 90,
                          borderRadius: 10,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.movie.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  height: 1.2,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Text(
                                    yearText,
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  RatingBadge(
                                    rating: widget.movie.voteAverage,
                                    fontSize: 12.5,
                                    iconSize: 14,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Star Rating Section
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceCard,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.surfaceBorder),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Your Rating',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              ratingLabel,
                              style: TextStyle(
                                color: _rating != null
                                    ? AppColors.starAmber
                                    : AppColors.textMuted,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(5, (index) {
                            final starValue = index + 1;
                            final filled = (_rating ?? 0) >= starValue;
                            return IconButton(
                              onPressed: () {
                                setState(() {
                                  if (_rating == starValue &&
                                      !_publishToCommunity) {
                                    _rating = null;
                                  } else {
                                    _rating = starValue;
                                  }
                                  _validationError = null;
                                });
                              },
                              icon: Icon(
                                filled
                                    ? Icons.star_rounded
                                    : Icons.star_border_rounded,
                                color: filled
                                    ? AppColors.starAmber
                                    : AppColors.textMuted,
                                size: 38,
                              ),
                            );
                          }),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Review / Personal Note Field
                  const Text(
                    'Review / Personal Note',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _textController,
                    minLines: 5,
                    maxLines: 10,
                    maxLength: 500,
                    textCapitalization: TextCapitalization.sentences,
                    onChanged: (_) {
                      if (_validationError != null) {
                        setState(() => _validationError = null);
                      }
                    },
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14.5,
                      height: 1.45,
                    ),
                    decoration: InputDecoration(
                      hintText: _publishToCommunity
                          ? 'Share your thoughts with the CineList community...'
                          : 'Add a quick note for your watchlist (optional)...',
                      alignLabelWithHint: true,
                      counterStyle: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Post to Community Toggle Card
                  _ToggleCard(
                    value: _publishToCommunity,
                    onChanged: (val) {
                      setState(() {
                        _publishToCommunity = val;
                        _validationError = null;
                      });
                    },
                    title: 'Post to Community',
                    subtitle: _publishToCommunity
                        ? 'Publishes publicly as a Verified Watch review'
                        : 'Saved privately to your Watchlist only',
                    icon: _publishToCommunity
                        ? Icons.public_rounded
                        : Icons.lock_outline_rounded,
                    activeColor: AppColors.pacificBlue,
                    activeBadge: 'PUBLIC',
                    inactiveBadge: 'PRIVATE',
                  ),

                  // Spoilers Toggle Card (High contrast, zero clipping)
                  AnimatedSize(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutCubic,
                    child: _publishToCommunity
                        ? Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: _ToggleCard(
                              value: _hasSpoilers,
                              onChanged: (val) {
                                setState(() => _hasSpoilers = val);
                              },
                              title: 'Contains Spoilers',
                              subtitle:
                                  'Review text will stay hidden until readers tap to reveal',
                              icon: _hasSpoilers
                                  ? Icons.warning_amber_rounded
                                  : Icons.visibility_outlined,
                              activeColor: AppColors.warning,
                              activeBadge: 'SPOILERS ON',
                              inactiveBadge: 'OFF',
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),

                  if (_validationError != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.error.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            color: AppColors.error,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _validationError!,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 22),
                  PrimaryButton(
                    label: _publishToCommunity
                        ? (widget.isEditingExistingCommunityReview
                              ? 'Update Review'
                              : 'Post Review')
                        : 'Save Rating & Note',
                    icon: _publishToCommunity
                        ? Icons.send_rounded
                        : Icons.check_rounded,
                    onPressed: _submit,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ToggleCard extends StatelessWidget {
  const _ToggleCard({
    required this.value,
    required this.onChanged,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.activeColor,
    required this.activeBadge,
    required this.inactiveBadge,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color activeColor;
  final String activeBadge;
  final String inactiveBadge;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: value
              ? activeColor.withValues(alpha: 0.15)
              : AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: value ? activeColor : AppColors.surfaceBorder,
            width: value ? 1.4 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: value
                    ? activeColor.withValues(alpha: 0.22)
                    : AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(
                icon,
                color: value ? activeColor : AppColors.textSecondary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: value
                              ? activeColor
                              : AppColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: value
                                ? activeColor
                                : AppColors.surfaceBorder,
                          ),
                        ),
                        child: Text(
                          value ? activeBadge : inactiveBadge,
                          style: TextStyle(
                            color: value
                                ? AppColors.black
                                : AppColors.textMuted,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: AppColors.black,
              activeTrackColor: activeColor,
              inactiveThumbColor: AppColors.textSecondary,
              inactiveTrackColor: AppColors.surfaceElevated,
              trackOutlineColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return activeColor;
                }
                return AppColors.surfaceBorder;
              }),
            ),
          ],
        ),
      ),
    );
  }
}
