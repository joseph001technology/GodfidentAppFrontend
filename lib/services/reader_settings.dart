import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// How the Bible text looks. Saved on the phone, applies to every chapter.
class ReaderSettings {
  final double fontSize; // 14 - 30
  final double lineHeight; // 1.3 - 2.2
  final bool serif; // Lora (true) or Inter (false)
  final String theme; // paper | sepia | night
  final bool showVerseNumbers;

  const ReaderSettings({
    this.fontSize = 17,
    this.lineHeight = 1.7,
    this.serif = true,
    this.theme = 'paper',
    this.showVerseNumbers = true,
  });

  ReaderSettings copyWith({double? fontSize, double? lineHeight, bool? serif, String? theme, bool? showVerseNumbers}) =>
      ReaderSettings(
        fontSize: fontSize ?? this.fontSize,
        lineHeight: lineHeight ?? this.lineHeight,
        serif: serif ?? this.serif,
        theme: theme ?? this.theme,
        showVerseNumbers: showVerseNumbers ?? this.showVerseNumbers,
      );

  Color get background => switch (theme) {
        'sepia' => const Color(0xFFF4ECD8),
        'night' => const Color(0xFF14181F),
        _ => const Color(0xFFFBF8F1),
      };
  Color get text => switch (theme) {
        'sepia' => const Color(0xFF3B2F1E),
        'night' => const Color(0xFFE6E2D8),
        _ => const Color(0xFF1F2430),
      };
  Color get accent => theme == 'night' ? const Color(0xFFE0B85A) : const Color(0xFF8A6A1F);
  bool get dark => theme == 'night';
  String get fontFamily => serif ? 'Lora' : 'Inter';
}

/// The last chapter the person read, for "Continue reading".
class ReadingPosition {
  final String book;
  final int chapter;
  final String translation;
  const ReadingPosition(this.book, this.chapter, this.translation);
}

class ReaderSettingsNotifier extends StateNotifier<ReaderSettings> {
  ReaderSettingsNotifier() : super(const ReaderSettings()) {
    _load();
  }

  static const _k = 'reader_settings_v1';

  Future<void> _load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final v = p.getStringList(_k);
      if (v != null && v.length >= 5) {
        state = ReaderSettings(
          fontSize: double.tryParse(v[0]) ?? 17,
          lineHeight: double.tryParse(v[1]) ?? 1.7,
          serif: v[2] == '1',
          theme: v[3],
          showVerseNumbers: v[4] == '1',
        );
      }
    } catch (_) {}
  }

  Future<void> update(ReaderSettings s) async {
    state = s;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setStringList(_k, [
        '${s.fontSize}',
        '${s.lineHeight}',
        s.serif ? '1' : '0',
        s.theme,
        s.showVerseNumbers ? '1' : '0',
      ]);
    } catch (_) {}
  }
}

final readerSettingsProvider =
    StateNotifierProvider<ReaderSettingsNotifier, ReaderSettings>((ref) => ReaderSettingsNotifier());

class ReadingPositionStore {
  static const _k = 'last_read_v1';

  static Future<void> save(String book, int chapter, String translation) async {
    try {
      (await SharedPreferences.getInstance()).setStringList(_k, [book, '$chapter', translation]);
    } catch (_) {}
  }

  static Future<ReadingPosition?> load() async {
    try {
      final v = (await SharedPreferences.getInstance()).getStringList(_k);
      if (v == null || v.length < 3) return null;
      return ReadingPosition(v[0], int.tryParse(v[1]) ?? 1, v[2]);
    } catch (_) {
      return null;
    }
  }
}

/// Recent search words (Global search + Bible search).
class RecentSearches {
  static const _k = 'recent_searches_v1';

  static Future<List<String>> load() async {
    try {
      return (await SharedPreferences.getInstance()).getStringList(_k) ?? [];
    } catch (_) {
      return [];
    }
  }

  static Future<List<String>> add(String q) async {
    final t = q.trim();
    if (t.length < 2) return load();
    final list = await load();
    list.removeWhere((e) => e.toLowerCase() == t.toLowerCase());
    list.insert(0, t);
    final next = list.take(8).toList();
    try {
      await (await SharedPreferences.getInstance()).setStringList(_k, next);
    } catch (_) {}
    return next;
  }

  static Future<void> clear() async {
    try {
      await (await SharedPreferences.getInstance()).remove(_k);
    } catch (_) {}
  }
}
