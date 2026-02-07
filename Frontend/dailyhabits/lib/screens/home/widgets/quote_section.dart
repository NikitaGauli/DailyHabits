import 'package:flutter/material.dart';
import 'package:dailyhabits/theme/app_theme.dart';
/// ===============================================================
///
/// A reusable widget that displays a motivational quote with
/// the author's name. Designed to be visually appealing with
/// a left accent bar and semi-transparent background.
///
/// Parameters:
/// - [quote]: The motivational quote text (default: a common motivational quote)
/// - [author]: The author of the quote (default: 'Robert Collier')
///
/// Usage:
/// ```dart
/// QuoteSectionWidget(
///   quote: "Believe you can and you're halfway there.",
///   author: "Theodore Roosevelt",
/// )
/// ```
/// ===============================================================
class QuoteSectionWidget extends StatelessWidget {
  /// The motivational quote text
  final String quote;

  /// The author of the quote
  final String author;

  const QuoteSectionWidget({
    super.key,
    this.quote =
        '"Success is the sum of small efforts, repeated day in and day out."',
    this.author = 'Robert Collier',
  });

  @override
  Widget build(BuildContext context) {
    final tc = context.colors;
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tc.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: tc.border.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Left accent bar
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
              color: tc.accent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),

          // Quote and author
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  quote,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: tc.textSecondary,
                    fontStyle: FontStyle.italic,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '— $author',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: tc.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
