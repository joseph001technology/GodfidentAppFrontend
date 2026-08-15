import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../core/theme.dart';

/// Card with an optional gradient/background and a soft shadow.
/// (Previously "gradient card with glow effect" — true glow doesn't read
/// on an ivory background, so this is now a flat-but-elevated card:
/// solid/gradient fill, a thin outline, and a soft low-alpha shadow
/// instead of a colored glow.)
class PremiumCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final LinearGradient? gradient;
  final Color? backgroundColor;
  final double borderRadius;
  final List<BoxShadow>? boxShadow;
  final VoidCallback? onTap;
  final Border? border;

  const PremiumCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.gradient,
    this.backgroundColor,
    this.borderRadius = 20,
    this.boxShadow,
    this.onTap,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    // A gradient card (e.g. the verse-of-day hero) is dark/navy by design
    // even in the light theme — so its border and default shadow need to
    // stay dark-appropriate rather than using the page's light outline.
    final isDarkFill = gradient != null;

    final card = Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        gradient: gradient,
        color: backgroundColor ?? AppTheme.navySurface,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: boxShadow ?? [
          BoxShadow(
            color: AppTheme.inkNavy.withValues(alpha: isDarkFill ? 0.18 : 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
        border: border ??
            (isDarkFill
                ? null
                : Border.all(color: AppTheme.navyOutline)),
      ),
      child: child,
    );

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: card);
    }
    return card;
  }
}

/// Frosted card with backdrop blur.
/// Retuned for light mode: on the old near-black background, a translucent
/// white layer read as "glass". Over an ivory page, the same translucent
/// white just looked like a grey smear, so this is now a higher-opacity
/// frosted white (like iOS light-mode control sheets) with a visible
/// hairline border, which keeps the "glass" read without going muddy.
/// Worth re-checking in context wherever it's used — if it's sitting
/// directly on the flat page background rather than over scrolling
/// content, a plain PremiumCard may honestly look better; see reminder list.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = 20,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: AppTheme.navyOutline),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Section header with a decorative accent bar.
class SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final Color? accentColor;
  final bool uppercase;

  const SectionHeader({
    super.key,
    required this.title,
    this.trailing,
    this.accentColor,
    this.uppercase = true,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 16,
            decoration: BoxDecoration(
              color: accentColor ?? AppTheme.gold,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            uppercase ? title.toUpperCase() : title,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: accentColor ?? AppTheme.goldDark,
              letterSpacing: 1.0,
            ),
          ),
          const Spacer(),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Small pill badge, e.g. for stats.
class StatPill extends StatelessWidget {
  final String icon;
  final String value;
  final String label;
  final Color? color;

  const StatPill({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppTheme.goldDark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: c.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 4),
          Text(
            value,
            style: TextStyle(
              color: c,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: c.withValues(alpha: 0.75),
              fontSize: 11,
              fontWeight: FontWeight.w500,
              fontFamily: 'Inter',
            ),
          ),
        ],
      ),
    );
  }
}
