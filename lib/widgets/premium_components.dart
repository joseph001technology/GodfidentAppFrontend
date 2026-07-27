import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/design_utils.dart';

// ══════════════════════════════════════════════════════════════════════════
// PROGRESS RING WIDGET
// ══════════════════════════════════════════════════════════════════════════

class ProgressRing extends StatelessWidget {
  final double percentage;
  final double size;
  final Color progressColor;
  final String label;
  final String? value;
  final double strokeWidth;

  const ProgressRing({
    super.key,
    required this.percentage,
    this.size = 120,
    this.progressColor = AppTheme.gold,
    this.label = '',
    this.value,
    this.strokeWidth = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox.expand(
                child: CircularProgressIndicator(
                  value: percentage / 100,
                  strokeWidth: strokeWidth,
                  backgroundColor: AppTheme.navyOutline,
                  valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                ),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (value != null)
                    Text(
                      value!,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            color: AppTheme.gold,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  Text(
                    '${percentage.toStringAsFixed(0)}%',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.grey,
                        ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (label.isNotEmpty) ...[
          const SizedBox(height: DesignUtils.spacingSm),
          Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
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
                    color: Colors.grey,
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
                      color: Colors.grey,
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
                    color: Colors.grey,
                  ),
            ),
            const SizedBox(height: DesignUtils.spacingMd),
            ClipRRect(
              borderRadius: DesignUtils.smallRadius,
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: Colors.grey.withValues(alpha: 0.2),
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
