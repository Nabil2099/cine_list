import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Renders lightweight Markdown (`**bold**`, `*italic*`, `` `code` ``,
/// headings, and bullet lists) as selectable rich text matching CineList's theme.
class FormattedChatText extends StatelessWidget {
  const FormattedChatText({
    super.key,
    required this.text,
    required this.baseColor,
    required this.boldColor,
  });

  final String text;
  final Color baseColor;
  final Color boldColor;

  @override
  Widget build(BuildContext context) {
    final baseStyle = TextStyle(
      color: baseColor,
      fontSize: 14.5,
      height: 1.5,
      fontWeight: FontWeight.w400,
    );

    final lines = text.split('\n');
    final spans = <InlineSpan>[];

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final trimmed = line.trimLeft();

      if (trimmed.startsWith('### ') ||
          trimmed.startsWith('## ') ||
          trimmed.startsWith('# ')) {
        final headingText = trimmed.replaceFirst(RegExp(r'^#{1,3}\s+'), '');
        spans.addAll(
          _parseInline(
            headingText,
            baseStyle.copyWith(
              color: boldColor,
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
              height: 1.55,
            ),
            boldColor,
          ),
        );
      } else if (trimmed.startsWith('- ') || trimmed.startsWith('* ')) {
        final bulletBody = trimmed.substring(2);
        spans.add(
          TextSpan(
            text: '•  ',
            style: baseStyle.copyWith(
              color: AppColors.pacificBlue,
              fontWeight: FontWeight.w700,
            ),
          ),
        );
        spans.addAll(_parseInline(bulletBody, baseStyle, boldColor));
      } else {
        spans.addAll(_parseInline(line, baseStyle, boldColor));
      }

      if (i < lines.length - 1) {
        spans.add(const TextSpan(text: '\n'));
      }
    }

    return SelectableText.rich(TextSpan(style: baseStyle, children: spans));
  }

  static final RegExp _inlinePattern = RegExp(
    r'(\*\*[^*]+\*\*|\*[^*\n]+\*|`[^`\n]+`)',
  );

  List<InlineSpan> _parseInline(
    String input,
    TextStyle baseStyle,
    Color boldColor,
  ) {
    final result = <InlineSpan>[];
    var currentIndex = 0;

    for (final match in _inlinePattern.allMatches(input)) {
      if (match.start > currentIndex) {
        result.add(
          TextSpan(
            text: input.substring(currentIndex, match.start),
            style: baseStyle,
          ),
        );
      }

      final token = match.group(0)!;
      if (token.startsWith('**') && token.endsWith('**') && token.length > 4) {
        result.add(
          TextSpan(
            text: token.substring(2, token.length - 2),
            style: baseStyle.copyWith(
              color: boldColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        );
      } else if (token.startsWith('*') &&
          token.endsWith('*') &&
          token.length > 2) {
        result.add(
          TextSpan(
            text: token.substring(1, token.length - 1),
            style: baseStyle.copyWith(fontStyle: FontStyle.italic),
          ),
        );
      } else if (token.startsWith('`') &&
          token.endsWith('`') &&
          token.length > 2) {
        result.add(
          TextSpan(
            text: token.substring(1, token.length - 1),
            style: baseStyle.copyWith(
              fontFamily: 'monospace',
              color: AppColors.softPeriwinkle,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      } else {
        result.add(TextSpan(text: token, style: baseStyle));
      }

      currentIndex = match.end;
    }

    if (currentIndex < input.length) {
      result.add(
        TextSpan(text: input.substring(currentIndex), style: baseStyle),
      );
    }

    return result;
  }
}
