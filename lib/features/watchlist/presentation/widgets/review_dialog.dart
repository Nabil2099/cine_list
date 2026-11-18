import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class ReviewResult {
  const ReviewResult({
    this.rating,
    this.note,
    this.publishToCommunity = false,
    this.hasSpoilers = false,
  });

  final int? rating;
  final String? note;
  final bool publishToCommunity;
  final bool hasSpoilers;
}

/// Modal dialog for leaving a 1-5 star personal rating and short note.
class ReviewDialog extends StatefulWidget {
  const ReviewDialog({
    super.key,
    required this.movieTitle,
    this.initialRating,
    this.initialNote,
    this.showPublishOption = false,
  });

  final String movieTitle;
  final int? initialRating;
  final String? initialNote;
  final bool showPublishOption;

  static Future<ReviewResult?> show(
    BuildContext context, {
    required String movieTitle,
    int? initialRating,
    String? initialNote,
    bool showPublishOption = false,
  }) {
    return showDialog<ReviewResult>(
      context: context,
      builder: (_) => ReviewDialog(
        movieTitle: movieTitle,
        initialRating: initialRating,
        initialNote: initialNote,
        showPublishOption: showPublishOption,
      ),
    );
  }

  @override
  State<ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<ReviewDialog> {
  late int? _rating;
  late final TextEditingController _noteController;
  bool _publishToCommunity = false;
  bool _hasSpoilers = false;
  String? _validationError;

  @override
  void initState() {
    super.initState();
    _rating = widget.initialRating;
    _noteController = TextEditingController(text: widget.initialNote ?? '');
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        'Rate "${widget.movieTitle}"',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: AppColors.khakiBeige, fontSize: 18),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your Rating',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
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
                      _rating = _rating == starValue ? null : starValue;
                      _validationError = null;
                    });
                  },
                  icon: Icon(
                    filled ? Icons.star_rounded : Icons.star_border_rounded,
                    color: filled ? AppColors.starAmber : AppColors.textMuted,
                    size: 32,
                  ),
                );
              }),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteController,
              maxLines: 3,
              maxLength: 300,
              onChanged: (_) {
                if (_validationError != null) {
                  setState(() => _validationError = null);
                }
              },
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
              ),
              decoration: const InputDecoration(
                hintText: 'Add a quick note (optional)...',
                counterStyle: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                ),
              ),
            ),
            if (widget.showPublishOption) ...[
              const SizedBox(height: 6),
              SwitchListTile.adaptive(
                value: _publishToCommunity,
                onChanged: (val) => setState(() {
                  _publishToCommunity = val;
                  _validationError = null;
                }),
                contentPadding: EdgeInsets.zero,
                activeThumbColor: AppColors.pacificBlue,
                title: const Text(
                  'Post to Community',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: const Text(
                  'Publishes as a Verified Watch review',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 11.5),
                ),
              ),
              if (_publishToCommunity)
                CheckboxListTile(
                  value: _hasSpoilers,
                  onChanged: (val) =>
                      setState(() => _hasSpoilers = val == true),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  activeColor: AppColors.pacificBlue,
                  title: const Text(
                    'Contains spoilers',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12.5,
                    ),
                  ),
                ),
            ],
            if (_validationError != null) ...[
              const SizedBox(height: 6),
              Text(
                _validationError!,
                style: const TextStyle(color: AppColors.error, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.pacificBlue,
            foregroundColor: AppColors.black,
          ),
          onPressed: () {
            final note = _noteController.text.trim();
            if (_publishToCommunity) {
              if (_rating == null) {
                setState(
                  () => _validationError =
                      'Select a star rating to post to Community.',
                );
                return;
              }
              if (note.length < 5) {
                setState(
                  () => _validationError =
                      'Write at least 5 characters to post to Community.',
                );
                return;
              }
            }
            Navigator.of(context).pop(
              ReviewResult(
                rating: _rating,
                note: note,
                publishToCommunity: _publishToCommunity,
                hasSpoilers: _hasSpoilers,
              ),
            );
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
