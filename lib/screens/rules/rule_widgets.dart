import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../models/rule.dart';

/// Turns a '#RRGGBB' string into a [Color] (falls back to [fallback]).
Color ruleColorFromHex(String? hex, {Color fallback = const Color(0xFF6C5CE7)}) {
  var h = (hex ?? '').trim().replaceAll('#', '');
  if (h.length == 6) h = 'FF$h';
  if (h.length != 8) return fallback;
  final v = int.tryParse(h, radix: 16);
  return v == null ? fallback : Color(v);
}

/// A scripture shown as a quote card (gold bar on the left, verse text, reference below).
/// With [compact] it is a single line: used in the Rules list.
class ScriptureQuote extends StatelessWidget {
  final RuleScripture scripture;
  final bool compact;
  const ScriptureQuote({super.key, required this.scripture, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final ref = scripture.reference.trim();
    final text = scripture.text.trim();

    if (compact) {
      final label = ref.isNotEmpty ? (text.isNotEmpty ? '$ref  ·  $text' : ref) : text;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: AppTheme.gold.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(children: [
          Icon(Icons.menu_book_rounded, size: 13, color: AppTheme.goldAccent),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontFamily: 'Lora',
                  fontStyle: FontStyle.italic,
                  fontSize: 12,
                  color: AppTheme.textSecondary),
            ),
          ),
        ]),
      );
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.navyVariant,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.navyOutline),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(width: 4, color: AppTheme.gold),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (text.isNotEmpty)
                  Text(
                    '“$text”',
                    style: TextStyle(
                        fontFamily: 'Lora',
                        fontStyle: FontStyle.italic,
                        fontSize: 16,
                        height: 1.65,
                        color: AppTheme.textPrimary),
                  ),
                if (ref.isNotEmpty) ...[
                  SizedBox(height: text.isNotEmpty ? 8 : 0),
                  Text(
                    ref,
                    style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.goldAccent),
                  ),
                ],
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}
