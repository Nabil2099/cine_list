import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class WriteReviewResult {
  const WriteReviewResult({required this.rating, required this.comment});

  final int rating;
  final String comment;
}

/// Dialog for writing or updating a public movie review.
class WriteReviewDialog extends StatefulWidget {
  const WriteReviewDialog({
    super.key,
    required this.movieTitle,
    this.initialRating = 5,
    this.initialComment = '',
  });

  final String movieTitle;
  final int initialRating;
  final String initialComment;

  static Future<WriteReviewResult?> show(
    BuildContext context, {
    required String movieTitle,
    int initialRating = 5,
    String initialComment = '',
  }) {
    return showDialog<WriteReviewResult>(
      context: context,
      builder: (_) => WriteReviewDialog(
        movieTitle: movieTitle,
        initialRating: initialRating,
        initialComment: initialComment,
      ),
    );
  }

  @override
  State<WriteReviewDialog> createState() => _WriteReviewDialogState();
}

class _WriteReviewDialogState extends State<WriteReviewDialog> {
  final _formKey = GlobalKey<FormState>();
  late int _rating;
  late final TextEditingController _commentController;

  @override
  void initState() {
    super.initState();
    _rating = widget.initialRating.clamp(1, 5);
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
