import 'package:flutter/material.dart';
import 'dart:ui';

/// Design utilities for premium, consistent UI
class DesignUtils {
  // ──────────────────────────────────────────────
  // GRADIENTS
  // ──────────────────────────────────────────────
  
  /// Soft gradient from navy to purple (contemplative)
  static const LinearGradient navyPurpleGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF0F0F1A),
      Color(0xFF2D1B4E),
    ],
  );

  /// Soft gradient with emerald accent (growth)
  static const LinearGradient growthGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF1A1A2E),
      Color(0xFF0D4D32),
    ],
  );

  /// Warm gradient from navy to gold (warmth, encouragement)
  static const LinearGradient warmGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF1A1A2E),
      Color(0xFF4A3A1A),
    ],
  );

  /// Cool gradient with blue accent (calm, peace)
  static const LinearGradient calmGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF0F0F1A),
      Color(0xFF1E3A5F),
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

/// Glass morphism effect with blur and transparency
class GlassmorphicContainer extends StatelessWidget {
  final Widget child;
  final double blur;
  final double opacity;
  final BorderRadius? borderRadius;
  final BoxBorder? border;
  final Color backgroundColor;

  const GlassmorphicContainer({
    Key? key,
    required this.child,
    this.blur = 10,
    this.opacity = 0.1,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    this.border,
    this.backgroundColor = const Color(0x1AFFFFFF),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.zero,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          decoration: BoxDecoration(
            color: backgroundColor.withOpacity(opacity),
            border: border,
            borderRadius: borderRadius,
          ),
          child: child,
        ),
      ),
    );
  }
}
