import 'package:flutter/material.dart';

class AppTheme {
  // Brand colors
  static const Color gold = Color(0xFFF5A623);
  static const Color goldLight = Color(0xFFFFC107);
  static const Color goldDark = Color(0xFFC9A96E);
  static const Color navy = Color(0xFF0A0A1A);
  static const Color navySurface = Color(0xFF14142A);
  static const Color navyVariant = Color(0xFF1E1E3A);
  static const Color navyOutline = Color(0xFF2D2D4A);
  static const Color emerald = Color(0xFF4CAF50);
  static const Color emeraldLight = Color(0xFF66BB6A);
  static const Color accentPurple = Color(0xFF7C4DFF);
  static const Color accentTeal = Color(0xFF00BCD4);
  static const Color accentPink = Color(0xFFFF4081);
  static const Color textPrimary = Color(0xFFEDEDF5);
  static const Color textSecondary = Color(0xFF9E9EB8);
  static const Color textMuted = Color(0xFF6B6B8A);

  // Card glow colors
  static const Color glowGold = Color(0x33F5A623);
  static const Color glowPurple = Color(0x337C4DFF);
  static const Color glowEmerald = Color(0x334CAF50);

  // Retained from the earlier premium palette (used by older screens)
  static const Color deepNavy = Color(0xFF0F0F1A);
  static const Color midnightPurple = Color(0xFF2D1B4E);
  static const Color softBlue = Color(0xFF60A5FA);
  static const Color warmGray = Color(0xFF9CA3AF);

  // Premium shadow
  static BoxDecoration glassDecoration({
    double blur = 10,
    Color background = const Color(0x1AFFFFFF),
    BorderRadius borderRadius = const BorderRadius.all(Radius.circular(20)),
    Color? borderColor,
  }) {
    return BoxDecoration(
      color: background,
      borderRadius: borderRadius,
      border: borderColor != null ? Border.all(color: borderColor) : null,
    );
  }

  static ThemeData dark() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: gold,
        onPrimary: Color(0xFF1A1A2E),
        primaryContainer: Color(0x33F5A623),
        onPrimaryContainer: gold,
        secondary: Color(0xFF7C4DFF),
        surface: navySurface,
        surfaceContainerHighest: navyVariant,
        onSurface: textPrimary,
        outline: navyOutline,
        error: Color(0xFFCF6679),
        tertiary: emerald,
      ),
      scaffoldBackgroundColor: navy,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
      ),
      cardTheme: CardThemeData(
        color: navySurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      dividerTheme: const DividerThemeData(color: navyOutline, thickness: 0.5),
      textTheme: _textTheme,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: navyVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: navyOutline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: navyOutline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: gold, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: const TextStyle(color: textMuted),
      ),
    );

    return base.copyWith(
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: gold,
          foregroundColor: navy,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, fontFamily: 'Inter'),
          elevation: 0,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: gold,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: navyVariant,
        selectedColor: gold.withValues(alpha: 0.2),
        labelStyle: const TextStyle(fontSize: 12, color: textPrimary, fontFamily: 'Inter'),
        side: const BorderSide(color: navyOutline, width: 0.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: navySurface,
        selectedItemColor: gold,
        unselectedItemColor: textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        showSelectedLabels: true,
        showUnselectedLabels: true,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: gold,
        foregroundColor: navy,
        elevation: 0,
        shape: CircleBorder(),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: navyVariant,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: navySurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return gold;
          return textMuted;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return gold.withValues(alpha: 0.3);
          return navyOutline;
        }),
      ),
    );
  }

  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(seedColor: gold, brightness: Brightness.light),
      textTheme: _textTheme,
    );
  }

  static const TextTheme _textTheme = TextTheme(
    displayLarge: TextStyle(fontFamily: 'Lora', fontSize: 32, fontWeight: FontWeight.bold, color: textPrimary, height: 1.2),
    displayMedium: TextStyle(fontFamily: 'Lora', fontSize: 28, fontWeight: FontWeight.bold, color: textPrimary, height: 1.2),
    displaySmall: TextStyle(fontFamily: 'Lora', fontSize: 24, fontWeight: FontWeight.bold, color: textPrimary, height: 1.3),
    headlineLarge: TextStyle(fontFamily: 'Lora', fontSize: 22, fontWeight: FontWeight.w600, color: textPrimary, height: 1.3),
    headlineMedium: TextStyle(fontFamily: 'Lora', fontSize: 20, fontWeight: FontWeight.w600, color: textPrimary, height: 1.3),
    headlineSmall: TextStyle(fontFamily: 'Lora', fontSize: 18, fontWeight: FontWeight.w600, color: textPrimary, height: 1.4),
    titleLarge: TextStyle(fontFamily: 'Inter', fontSize: 17, fontWeight: FontWeight.w600, color: textPrimary, height: 1.3),
    titleMedium: TextStyle(fontFamily: 'Inter', fontSize: 15, fontWeight: FontWeight.w500, color: textPrimary, height: 1.4),
    titleSmall: TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w600, color: textSecondary, height: 1.4),
    bodyLarge: TextStyle(fontFamily: 'Inter', fontSize: 16, color: textPrimary, height: 1.5),
    bodyMedium: TextStyle(fontFamily: 'Inter', fontSize: 14, color: textPrimary, height: 1.5),
    bodySmall: TextStyle(fontFamily: 'Inter', fontSize: 12, color: textSecondary, height: 1.5),
    labelLarge: TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w600, color: textPrimary, height: 1.3),
    labelMedium: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w500, color: textSecondary, height: 1.3),
    labelSmall: TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.w600, color: textMuted, letterSpacing: 0.8, height: 1.3),
  );
}

// Gradient presets for hero cards
class Gradients {
  static const LinearGradient verseOfDay = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [Color(0xFF1A1040), Color(0xFF2D1B69), Color(0xFF1A1040)],
  );
  static const LinearGradient prayer = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [Color(0xFF1A3A2A), Color(0xFF0D2618)],
  );
  static const LinearGradient bibleReading = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [Color(0xFF1A1A4A), Color(0xFF0D0D2E)],
  );
  static const LinearGradient inspiration1 = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [Color(0xFF7B3A10), Color(0xFF4A2208)],
  );
  static const LinearGradient inspiration2 = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [Color(0xFF2A1A6B), Color(0xFF1A0D3E)],
  );
  static const LinearGradient inspiration3 = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [Color(0xFF0D3D2A), Color(0xFF062415)],
  );
  static const LinearGradient focus = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [Color(0xFF1A1A4A), Color(0xFF2D1B69)],
  );
  static const LinearGradient streak = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [Color(0xFF1A3A2A), Color(0xFF0D2618)],
  );
  static const LinearGradient consistency = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [Color(0xFF3A1A2A), Color(0xFF2A0D1A)],
  );
}