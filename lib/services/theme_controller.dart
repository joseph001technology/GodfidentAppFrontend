import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/theme.dart';

/// Light / Dark / System. The choice is kept on the phone and applied before
/// the first frame, so the app never flashes the wrong theme.
class ThemeController {
  ThemeController._();
  static const _k = 'theme_mode_v1';
  static ThemeMode initial = ThemeMode.light;

  static Future<void> load() async {
    try {
      final v = (await SharedPreferences.getInstance()).getString(_k);
      initial = switch (v) {
        'dark' => ThemeMode.dark,
        'system' => ThemeMode.system,
        _ => ThemeMode.light,
      };
    } catch (_) {}
    apply(initial);
  }

  static bool resolve(ThemeMode m) =>
      m == ThemeMode.dark ||
      (m == ThemeMode.system && WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark);

  /// Tells the colour tokens (AppTheme.navy, textPrimary ...) which palette to use.
  static void apply(ThemeMode m) => AppTheme.isDark = resolve(m);

  static Future<void> save(ThemeMode m) async {
    try {
      await (await SharedPreferences.getInstance()).setString(_k, m.name);
    } catch (_) {}
  }
}

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeController.initial);

  Future<void> set(ThemeMode m) async {
    ThemeController.apply(m);
    state = m;
    await ThemeController.save(m);
  }
}

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) => ThemeModeNotifier());

/// Rebuilds every widget under the app, so screens that read AppTheme colours
/// directly repaint at once when the theme changes (the pattern Flutter documents for locale changes).
class ThemeRebuilder extends StatefulWidget {
  final bool isDark;
  final Widget child;
  const ThemeRebuilder({super.key, required this.isDark, required this.child});
  @override
  State<ThemeRebuilder> createState() => _ThemeRebuilderState();
}

class _ThemeRebuilderState extends State<ThemeRebuilder> {
  @override
  void didUpdateWidget(ThemeRebuilder old) {
    super.didUpdateWidget(old);
    if (old.isDark != widget.isDark) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        void rebuild(Element el) {
          el.markNeedsBuild();
          el.visitChildren(rebuild);
        }

        (context as Element).visitChildren(rebuild);
      });
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
