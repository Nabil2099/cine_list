import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class WriteReviewResult {
  const WriteReviewResult({
    required this.rating,
    required this.comment,
    this.hasSpoilers = false,
  });

  final int rating;
  final String comment;
  final bool hasSpoilers;
}

/// Dialog for writing or updating a public movie review.
class WriteReviewDialog extends StatefulWidget {
  const WriteReviewDialog({
    super.key,
    required this.movieTitle,
    this.initialRating = 5,
    this.initialComment = '',
    this.initialHasSpoilers = false,
  });

  final String movieTitle;
  final int initialRating;
  final String initialComment;
  final bool initialHasSpoilers;

  static Future<WriteReviewResult?> show(
    BuildContext context, {
    required String movieTitle,
    int initialRating = 5,
    String initialComment = '',
    bool initialHasSpoilers = false,
  }) {
    return showDialog<WriteReviewResult>(
      context: context,
      builder: (_) => WriteReviewDialog(
        movieTitle: movieTitle,
        initialRating: initialRating,
        initialComment: initialComment,
        initialHasSpoilers: initialHasSpoilers,
      ),
    );
  }

  @override
  State<WriteReviewDialog> createState() => _WriteReviewDialogState();
}

class _WriteReviewDialogState extends State<WriteReviewDialog> {
  final _formKey = GlobalKey<FormState>();
  late int _rating;
  late bool _hasSpoilers;
  late final TextEditingController _commentController;

  @override
  void initState() {
    super.initState();
    _rating = widget.initialRating.clamp(1, 5);
    _hasSpoilers = widget.initialHasSpoilers;
    _commentController = TextEditingController(text: widget.initialComment);
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        'Review "${widget.movieTitle}"',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: AppColors.khakiBeige, fontSize: 18),
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                final star = index + 1;
                final active = star <= _rating;
                return IconButton(
                  onPressed: () => setState(() => _rating = star),
                  icon: Icon(
                    active ? Icons.star_rounded : Icons.star_border_rounded,
                    color: active ? AppColors.starAmber : AppColors.textMuted,
                    size: 32,
                  ),
                );
              }),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _commentController,
              maxLines: 4,
              maxLength: 500,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                hintText: 'Share your thoughts with the community...',
                counterStyle: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                ),
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Please write a short review.';
                }
                return null;
              },
            ),
            const SizedBox(height: 6),
            SwitchListTile.adaptive(
              value: _hasSpoilers,
              onChanged: (val) => setState(() => _hasSpoilers = val),
              contentPadding: EdgeInsets.zero,
              activeThumbColor: AppColors.pacificBlue,
              title: const Text(
                'Contains Spoilers',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: const Text(
                'Hide review text until readers tap to reveal',
                style: TextStyle(color: AppColors.textMuted, fontSize: 11.5),
              ),
            ),
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
            if (_formKey.currentState?.validate() ?? false) {
              Navigator.of(context).pop(
                WriteReviewResult(
                  rating: _rating,
                  comment: _commentController.text.trim(),
                  hasSpoilers: _hasSpoilers,
                ),
              );
            }
          },
          child: const Text('Post Review'),
        ),
      ],
    );
  }
}
