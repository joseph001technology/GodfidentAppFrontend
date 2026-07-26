import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ──────────────────────────────────────────────
  // PRIMARY COLORS (Premium Spiritual Growth Palette)
  // ──────────────────────────────────────────────
  static const Color emerald = Color(0xFF10B981);    // Spiritual growth, renewal
  static const Color deepNavy = Color(0xFF0F0F1A);   // Deep, peaceful background
  static const Color midnightPurple = Color(0xFF2D1B4E); // Mystical, contemplative
  
  // ACCENT COLORS
  static const Color gold = Color(0xFFC9A96E);       // Divine, precious
  static const Color softBlue = Color(0xFF60A5FA);   // Calm, trust
  static const Color warmGray = Color(0xFF9CA3AF);   // Balance, grounding
  
  // SEMANTIC COLORS
  static const Color navy = Color(0xFF0F0F1A);
  static const Color navySurface = Color(0xFF1A1A2E);
  static const Color navyVariant = Color(0xFF252540);
  static const Color navyOutline = Color(0xFF3D3D5C);

  static ThemeData dark() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: gold,
        onPrimary: Color(0xFF1A1A2E),
        primaryContainer: Color(0xFF2D2D44),
        onPrimaryContainer: gold,
        secondary: softBlue,
        secondaryContainer: Color(0xFF1E3A5F),
        tertiary: emerald,
        tertiaryContainer: Color(0xFF0D4D32),
        surface: navySurface,
        surfaceContainerHighest: navyVariant,
        onSurface: Color(0xFFE8E8F0),
        outline: navyOutline,
        error: Color(0xFFCF6679),
        background: navy,
        onBackground: Color(0xFFE8E8F0),
      ),
    );
    return base.copyWith(
      scaffoldBackgroundColor: navy,
      appBarTheme: const AppBarTheme(
        backgroundColor: navySurface,
        foregroundColor: Color(0xFFE8E8F0),
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: navySurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: navyOutline, width: 0.5),
        ),
      ),
      dividerTheme: const DividerThemeData(color: navyOutline, thickness: 0.5),
      textTheme: _textTheme(Brightness.dark),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: navyVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: navyOutline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: navyOutline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: gold, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: gold,
          foregroundColor: const Color(0xFF1A1A2E),
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: gold),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: navyVariant,
        selectedColor: gold.withOpacity(0.2),
        labelStyle: GoogleFonts.inter(fontSize: 12),
        side: const BorderSide(color: navyOutline, width: 0.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: navySurface,
        selectedItemColor: gold,
        unselectedItemColor: Color(0xFF6B6B8A),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: gold,
        foregroundColor: Color(0xFF1A1A2E),
      ),
    );
  }

  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFFC9A96E),
        brightness: Brightness.light,
      ),
    );
    return base.copyWith(
      textTheme: _textTheme(Brightness.light),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  static TextTheme _textTheme(Brightness brightness) {
    final color = brightness == Brightness.dark
        ? const Color(0xFFE8E8F0)
        : const Color(0xFF1A1A2E);
    return TextTheme(
      displayLarge: GoogleFonts.lora(fontSize: 28, fontWeight: FontWeight.bold, color: color),
      displayMedium: GoogleFonts.lora(fontSize: 24, fontWeight: FontWeight.bold, color: color),
      headlineLarge: GoogleFonts.lora(fontSize: 22, fontWeight: FontWeight.w600, color: color),
      headlineMedium: GoogleFonts.lora(fontSize: 20, fontWeight: FontWeight.w600, color: color),
      headlineSmall: GoogleFonts.lora(fontSize: 18, fontWeight: FontWeight.w600, color: color),
      titleLarge: GoogleFonts.lora(fontSize: 17, fontWeight: FontWeight.w600, color: color),
      titleMedium: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w500, color: color),
      titleSmall: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: color),
      bodyLarge: GoogleFonts.inter(fontSize: 16, color: color),
      bodyMedium: GoogleFonts.inter(fontSize: 14, color: color),
      bodySmall: GoogleFonts.inter(fontSize: 12, color: color.withOpacity(0.7)),
      labelLarge: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: color),
      labelMedium: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: color),
      labelSmall: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: color),
    );
  }
}
