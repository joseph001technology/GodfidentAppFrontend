import 'package:flutter/material.dart';
import '../theme.dart';

class VerseCard extends StatelessWidget {
  final String verseText;
  final String reference;
  final LinearGradient? gradient;
  final VoidCallback? onTap;
  final Widget? trailing;

  const VerseCard({
    super.key,
    required this.verseText,
    required this.reference,
    this.gradient,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: gradient ?? Gradients.verseOfDay,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: AppTheme.glowGold,
              blurRadius: 24,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Decorative quote marks
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '"',
                  style: TextStyle(
                    fontFamily: 'Lora',
                    fontSize: 48,
                    color: AppTheme.gold.withValues(alpha: 0.3),
                    height: 0.8,
                  ),
                ),
                const Spacer(),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 8),
            Text(
              verseText,
              style: const TextStyle(
                fontFamily: 'Lora',
                fontSize: 17,
                color: Colors.white,
                height: 1.6,
                fontStyle: FontStyle.italic,
              ),
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              '"',
              style: TextStyle(
                fontFamily: 'Lora',
                fontSize: 48,
                color: AppTheme.gold.withValues(alpha: 0.3),
                height: 0.5,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  width: 20,
                  height: 2,
                  decoration: BoxDecoration(
                    color: AppTheme.gold.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  reference,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    color: AppTheme.gold.withValues(alpha: 0.8),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
