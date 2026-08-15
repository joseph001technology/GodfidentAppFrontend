import 'package:flutter/material.dart';
import 'dart:ui';

/// Design utilities for premium, consistent UI
class DesignUtils {
  // ──────────────────────────────────────────────
  // GRADIENTS
  // ──────────────────────────────────────────────
  
  // REMINDER: navyPurpleGradient, growthGradient, and calmGradient are
  // UNUSED anywhere in the project (grepped — only warmGradient has a live
  // caller, in progress_ring.dart and premium_components.dart). Left them
  // defined (in case something outside this snapshot uses them) but
  // updated to light-safe values on the assumption they'd be used the same
  // way warmGradient is, as a card fill. Delete these three once confirmed
  // unused for real.

  /// Soft gradient, contemplative. Was navy-to-purple-black; now a pale
  /// plum tint so it still reads as "contemplative" without going dark.
  static const LinearGradient navyPurpleGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFE7E1F2),
      Color(0xFFD3C7E8),
    ],
  );

  /// Soft gradient with emerald accent (growth). Was near-black-to-dark
  /// green; now a pale sage tint.
  static const LinearGradient growthGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFE3EEE5),
      Color(0xFFCBE0D0),
    ],
  );

  /// Warm gradient (warmth, encouragement). Was near-black-to-dark-amber;
  /// now a pale gold tint. CONFIRMED LIVE — used by ContinueReadingCard.
  static const LinearGradient warmGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFF3E7D0),
      Color(0xFFE9D3A8),
    ],
  );

  /// Cool gradient with blue accent (calm, peace). Was near-black-to-dark
  /// blue; now a pale sky tint.
  static const LinearGradient calmGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFE1EBF3),
      Color(0xFFC7DCEC),
    ],
  );

  // ──────────────────────────────────────────────
  // SHADOWS
  // ──────────────────────────────────────────────
  
  static const List<BoxShadow> premiumShadow = [
    BoxShadow(
      color: Color(0x1F000000),
      blurRadius: 12,
      offset: Offset(0, 4),
    ),
  ];

  static const List<BoxShadow> subtleShadow = [
    BoxShadow(
      color: Color(0x0F000000),
      blurRadius: 6,
      offset: Offset(0, 2),
    ),
  ];

  // ──────────────────────────────────────────────
  // BORDER RADIUS
  // ──────────────────────────────────────────────
  
  static const BorderRadius smallRadius = BorderRadius.all(Radius.circular(8));
  static const BorderRadius mediumRadius = BorderRadius.all(Radius.circular(12));
  static const BorderRadius largeRadius = BorderRadius.all(Radius.circular(16));
  static const BorderRadius extraLargeRadius = BorderRadius.all(Radius.circular(20));

  // ──────────────────────────────────────────────
  // SPACING
  // ──────────────────────────────────────────────
  
  static const double spacingXs = 4;
  static const double spacingSm = 8;
  static const double spacingMd = 12;
  static const double spacingLg = 16;
  static const double spacingXl = 20;
  static const double spacingXxl = 24;
  static const double spacingHuge = 32;

  // ──────────────────────────────────────────────
  // ANIMATIONS
  // ──────────────────────────────────────────────
  
  static const Duration shortDuration = Duration(milliseconds: 150);
  static const Duration mediumDuration = Duration(milliseconds: 300);
  static const Duration longDuration = Duration(milliseconds: 500);

  static const Curve standardCurve = Curves.easeInOut;
  static const Curve bouncyCurve = Curves.elasticOut;
  static const Curve smoothCurve = Curves.decelerate;
}

// REMINDER: GlassmorphicContainer has no callers anywhere in the project
// (grepped) — likely dead code, same story as GlassCard in
// shared/widgets/premium_card.dart. Retuned its default fill below in case
// something outside this snapshot uses it, but flag for deletion once
// confirmed unused.
/// Glass morphism effect with blur and transparency
class GlassmorphicContainer extends StatelessWidget {
  final Widget child;
  final double blur;
  final double opacity;
  final BorderRadius? borderRadius;
  final BoxBorder? border;
  final Color backgroundColor;

  const GlassmorphicContainer({
    super.key,
    required this.child,
    this.blur = 10,
    this.opacity = 0.1,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    this.border,
    this.backgroundColor = const Color(0x0D1B2A4C), // was translucent white — muddy on ivory; soft ink tint instead
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.zero,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          decoration: BoxDecoration(
            color: backgroundColor.withValues(alpha: opacity),
            border: border,
            borderRadius: borderRadius,
          ),
          child: child,
        ),
      ),
    );
  }
}
