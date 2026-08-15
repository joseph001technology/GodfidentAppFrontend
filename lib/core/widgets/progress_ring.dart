import 'package:flutter/material.dart';
import '../theme.dart';
import '../design_utils.dart';

// ══════════════════════════════════════════════════════════════════════════
// PROGRESS RING WIDGET
// ──────────────────────────────────────────────────────────────────────────
// FIXED: the version of this file I originally worked from defined
// ProgressRing with (percentage, progressColor, value, label) — but the
// real call sites in home_screen.dart and progress_screen.dart both use
// (progress, color, child). That original snapshot was already out of
// sync with the rest of the app before I touched it; this now matches
// actual usage: progress is 0.0–1.0, color is the ring color, child is
// whatever widget sits in the center (usually a percentage Text/Column).
// ══════════════════════════════════════════════════════════════════════════

class ProgressRing extends StatelessWidget {
  final double progress;
  final double size;
  final Color color;
  final double strokeWidth;
  final Widget? child;

  const ProgressRing({
    super.key,
    required this.progress,
    this.size = 120,
    this.color = AppTheme.gold,
    this.strokeWidth = 8,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.expand(
            child: CircularProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              strokeWidth: strokeWidth,
              backgroundColor: AppTheme.navyOutline,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          if (child != null) child!,
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// SECTION HEADER (stub)
// ──────────────────────────────────────────────────────────────────────────
// ADDED: every screen that imports this file does
// `import '.../progress_ring.dart' hide SectionHeader;`, which only makes
// sense if this file is expected to export a SectionHeader — but the
// original snapshot I had never defined one, which is why `flutter
// analyze` flagged "doesn't export a member with the hidden name
// SectionHeader". Since every import site hides it (they all use the real
// one in shared/widgets/premium_card.dart instead), this is never actually
// instantiated — it just needs to exist so the `hide` clause is valid.
// ══════════════════════════════════════════════════════════════════════════

class SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const SectionHeader({super.key, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.goldDark),
          ),
          const Spacer(),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// STAT CARD WIDGET
// ══════════════════════════════════════════════════════════════════════════

class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color? backgroundColor;
  final Color? iconColor;
  final VoidCallback? onTap;

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    this.backgroundColor,
    this.iconColor = AppTheme.gold,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(DesignUtils.spacingLg),
        decoration: BoxDecoration(
          color: backgroundColor ?? AppTheme.navyVariant,
          border: Border.all(
            color: AppTheme.navyOutline,
            width: 0.5,
          ),
          borderRadius: DesignUtils.largeRadius,
          boxShadow: DesignUtils.subtleShadow,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: AppTheme.navySurface,
                borderRadius: DesignUtils.mediumRadius,
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(height: DesignUtils.spacingMd),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: DesignUtils.spacingSm),
            Text(
              title,
              style: Theme.of(context).textTheme.titleSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: DesignUtils.spacingXs),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textMuted, // was Colors.grey
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// PREMIUM CARD WIDGET
// ──────────────────────────────────────────────────────────────────────────
// REMINDER: this is the SECOND definition of `PremiumCard` in the project
// (the other is lib/shared/widgets/premium_card.dart). home_screen.dart
// already has to alias the other one as `sh.PremiumCard` to avoid a name
// collision with this one. Pick one, delete the other, once you've grepped
// the rest of the app for which is used where. Left both alive for now so
// nothing breaks.
// ══════════════════════════════════════════════════════════════════════════

class PremiumCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final Gradient? gradient;
  final BorderRadius? borderRadius;
  final VoidCallback? onTap;
  final double elevation;

  const PremiumCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(DesignUtils.spacingLg),
    this.gradient,
    this.borderRadius = DesignUtils.largeRadius,
    this.onTap,
    this.elevation = 0,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: gradient,
        color: gradient == null ? AppTheme.navyVariant : null,
        border: Border.all(
          color: AppTheme.navyOutline,
          width: 0.5,
        ),
        borderRadius: borderRadius,
        boxShadow: elevation > 0 ? DesignUtils.premiumShadow : null,
      ),
      child: child,
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: card,
      );
    }

    return card;
  }
}

// ══════════════════════════════════════════════════════════════════════════
// STREAK BADGE WIDGET
// ══════════════════════════════════════════════════════════════════════════

class StreakBadge extends StatelessWidget {
  final int streak;
  final String label;
  final IconData icon;
  final Color iconColor;

  const StreakBadge({
    super.key,
    required this.streak,
    required this.label,
    required this.icon,
    this.iconColor = AppTheme.gold,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DesignUtils.spacingMd,
        vertical: DesignUtils.spacingSm,
      ),
      decoration: BoxDecoration(
        color: AppTheme.navyVariant,
        border: Border.all(color: AppTheme.navyOutline, width: 0.5),
        borderRadius: DesignUtils.mediumRadius,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: DesignUtils.spacingSm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$streak',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textMuted, // was Colors.grey
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// CONTINUE READING CARD
// ══════════════════════════════════════════════════════════════════════════

class ContinueReadingCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final double progress;
  final VoidCallback onTap;

  const ContinueReadingCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.progress,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: PremiumCard(
        // NOTE: DesignUtils.warmGradient is defined in design_utils.dart,
        // which I don't have — I can't confirm it's light-mode-safe. If it
        // was a dark amber-on-black gradient it should still read fine on
        // its own (gradient fills are self-contained), but double check
        // the gold-colored TEXT drawn on top of it below still has enough
        // contrast once you see it rendered.
        gradient: DesignUtils.warmGradient,
        padding: const EdgeInsets.all(DesignUtils.spacingLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Continue Reading',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppTheme.gold,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const Icon(Icons.arrow_forward, color: AppTheme.gold),
              ],
            ),
            const SizedBox(height: DesignUtils.spacingMd),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: DesignUtils.spacingSm),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textMuted, // was Colors.grey
                  ),
            ),
            const SizedBox(height: DesignUtils.spacingMd),
            ClipRRect(
              borderRadius: DesignUtils.smallRadius,
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: AppTheme.navyOutline, // was Colors.grey @ 0.2
                valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.gold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// SHIMMER LOADER
// ──────────────────────────────────────────────────────────────────────────
// No color logic here (it fades its child's own opacity), so nothing to
// change for the light theme.
// ══════════════════════════════════════════════════════════════════════════

class ShimmerLoading extends StatefulWidget {
  final Widget child;
  final bool isLoading;

  const ShimmerLoading({
    super.key,
    required this.child,
    this.isLoading = true,
  });

  @override
  State<ShimmerLoading> createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<ShimmerLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: DesignUtils.longDuration,
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isLoading) {
      return widget.child;
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: 0.5 + 0.5 * (_controller.value - 0.5).abs() * 2,
          child: widget.child,
        );
      },
    );
  }
}
