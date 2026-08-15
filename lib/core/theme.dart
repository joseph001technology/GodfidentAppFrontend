import 'package:flutter/material.dart';

class AppTheme {
  // ────────────────────────────────────────────────────────────────────────
  // Brand colors — "Godfident Light" palette
  // NOTE: token NAMES are unchanged from the old dark theme on purpose, so
  // every screen that already references AppTheme.gold / AppTheme.navy /
  // etc. picks up the new palette automatically. A couple of tokens had to
  // change ROLE, not just value — see the inkNavy note below.
  // ────────────────────────────────────────────────────────────────────────
  static const Color gold = Color(0xFFC79A45);
  static const Color goldLight = Color(0xFFD9B36C);
  static const Color goldDark = Color(0xFFA9803B);

  // "navy" used to be the near-black page background AND was reused in a
  // few places as "dark text/icon sitting on a gold chip". In light mode
  // those are two different colors, so:
  //   - navy            -> now the page background (ivory)
  //   - inkNavy (NEW)   -> the dark navy ink color for text/icons on gold
  // Anywhere the old code wrote `AppTheme.navy` to mean "dark text on a
  // gold surface" needs to become `AppTheme.inkNavy` instead — I've fixed
  // every instance of that I could find in the files you sent (flagged
  // inline with a comment), but do a project-wide search for
  // `AppTheme.navy` used as a `color:`/`foregroundColor:` on top of a gold
  // background before you copy this into the other ~25 screens.
  static const Color navy = Color(0xFFFAF6EC); // page background (was #0A0A1A)
  static const Color inkNavy = Color(0xFF1B2A4C); // NEW — dark ink/on-gold text

  // Surface ramp: in dark mode "lighter navy" meant "more elevated". In
  // light mode elevation instead goes from warm ivory -> white card ->
  // soft ivory-gray for inputs/inactive chips -> a hairline border color.
  static const Color navySurface = Color(0xFFFFFFFF); // cards, dialogs, bottom nav (was #14142A)
  static const Color navyVariant = Color(0xFFF2ECDD); // inputs, inactive chips/tabs, stat boxes (was #1E1E3A)
  static const Color navyOutline = Color(0xFFE8E1D0); // borders, dividers (was #2D2D4A)

  static const Color emerald = Color(0xFF4F8C5D);
  static const Color emeraldLight = Color(0xFF6FA87C);
  static const Color accentPurple = Color(0xFF5B4B8A);
  static const Color accentTeal = Color(0xFF3E8E96);
  static const Color accentPink = Color(0xFFC15B6B);

  static const Color textPrimary = Color(0xFF1E2030); // was #EDEDF5 (near-white)
  static const Color textSecondary = Color(0xFF666B7C); // was #9E9EB8
  static const Color textMuted = Color(0xFF8A8D9C); // was #6B6B8A

  // NEW — a handful of hero cards (verse-of-day, focus mode, the home
  // header) intentionally KEEP a dark navy/gradient fill even in the light
  // theme, matching the prototype's verse card. Anything drawn on top of
  // those specific cards needs to stay light, so it can't use the (now
  // dark) textPrimary/textSecondary. Use these two instead, ONLY inside a
  // dark-gradient card:
  static const Color textOnDark = Color(0xFFF4F1E8); // was textPrimary's old value, repurposed
  static const Color textOnDarkMuted = Color(0xFFC9CEDD);

  // Card glow colors — true "glow" doesn't read on a light background the
  // way it did on near-black, so these are now just very soft tint
  // overlays. If you find these unused elsewhere, they're a good candidate
  // for removal (see the note I gave you separately).
  static const Color glowGold = Color(0x26C79A45);
  static const Color glowPurple = Color(0x265B4B8A);
  static const Color glowEmerald = Color(0x264F8C5D);

  // Retained from the earlier premium palette (used by older screens).
  // softBlue is confirmed LIVE (home_screen.dart uses it for the "Read
  // Bible" icon and note topic badges) despite this comment saying
  // "older screens" — worth reconciling which of these four are actually
  // dead. deepNavy / midnightPurple / warmGray are UNVERIFIED — I found no
  // reference to them in the 7 files you sent me. Grep the rest of the
  // project before deleting any of them.
  static const Color deepNavy = Color(0xFFF6F1E4);
  static const Color midnightPurple = Color(0xFF4A3970);
  static const Color softBlue = Color(0xFF3E7CA6); // was #60A5FA — deepened for contrast on ivory
  static const Color warmGray = Color(0xFF9CA3AF);

  static const Color danger = Color(0xFFB4543F);

  // Premium shadow / "glass" container.
  // NOTE: true glassmorphism (blurred translucent white) looked good over
  // near-black; over ivory it just looks like a faint grey smear. I've
  // toned the default background down to a soft ink tint so it still
  // reads as "a layer above the page" without going muddy, but I'd
  // recommend re-evaluating every GlassCard usage individually rather than
  // trusting this default — see the reminder list.
  static BoxDecoration glassDecoration({
    double blur = 10,
    Color background = const Color(0x0D1B2A4C),
    BorderRadius borderRadius = const BorderRadius.all(Radius.circular(20)),
    Color? borderColor,
  }) {
    return BoxDecoration(
      color: background,
      borderRadius: borderRadius,
      border: Border.all(color: borderColor ?? navyOutline),
    );
  }

  // ────────────────────────────────────────────────────────────────────────
  // ThemeData
  // ────────────────────────────────────────────────────────────────────────

  /// The app's single theme going forward. Kept the name `light()` from the
  /// original file (it used to be an unused ColorScheme.fromSeed stub —
  /// convenient, since that's exactly the slot this belongs in).
  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: gold,
        onPrimary: inkNavy,
        primaryContainer: Color(0x26C79A45),
        onPrimaryContainer: goldDark,
        secondary: accentPurple,
        surface: navySurface,
        surfaceContainerHighest: navyVariant,
        onSurface: textPrimary,
        outline: navyOutline,
        error: danger,
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
          side: const BorderSide(color: navyOutline, width: 1),
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
          foregroundColor: inkNavy, // was `navy` — needed the NEW dark-ink token, see top of file
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
        selectedColor: gold.withValues(alpha: 0.18),
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
        foregroundColor: inkNavy, // was `navy`
        elevation: 0,
        shape: CircleBorder(),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: navySurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: navyOutline, width: 1),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: navySurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return gold;
          return const Color(0xFFFFFFFF);
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return gold.withValues(alpha: 0.35);
          return navyOutline;
        }),
      ),
    );
  }

  /// Kept as a shim so it doesn't matter which method your `main.dart`
  /// currently calls — both now produce the light theme. This is a
  /// temporary bridge, not a real fix: please tell me (or grep for)
  /// whichever of `AppTheme.dark()` / `AppTheme.light()` your
  /// MaterialApp actually references, then we delete this method and
  /// rename `light()` back to a neutral name. Flagged on the reminder list.
  static ThemeData dark() => light();

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

// Gradient presets for hero cards.
// UNUSED BY THE FILES YOU SENT ME — home_screen.dart writes its own inline
// LinearGradients instead of calling these (see reminder list). I've still
// updated them to light-safe values in case another screen does use them;
// verify with a project-wide grep for `Gradients.` before assuming these
// are the ones actually rendering anywhere.
class Gradients {
  static const LinearGradient verseOfDay = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [Color(0xFF1B2A4C), Color(0xFF131E38), Color(0xFF1B2A4C)],
  );
  static const LinearGradient prayer = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [Color(0xFFDCE6DD), Color(0xFFC3D4C6)],
  );
  static const LinearGradient bibleReading = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [Color(0xFF1B2A4C), Color(0xFF24365E)],
  );
  static const LinearGradient inspiration1 = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [Color(0xFFE8B65A), Color(0xFFC79A45)],
  );
  static const LinearGradient inspiration2 = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [Color(0xFF6B4FA0), Color(0xFF4A3970)],
  );
  static const LinearGradient inspiration3 = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [Color(0xFF6C8873), Color(0xFF4F6459)],
  );
  static const LinearGradient focus = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [Color(0xFF1B2A4C), Color(0xFF3A2E5C)],
  );
  static const LinearGradient streak = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [Color(0xFFDCE6DD), Color(0xFFC3D4C6)],
  );
  static const LinearGradient consistency = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [Color(0xFFE9C7CC), Color(0xFFC15B6B)],
  );
}
