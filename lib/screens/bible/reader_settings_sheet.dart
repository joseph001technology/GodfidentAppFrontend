import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../services/reader_settings.dart';

/// Bottom sheet to change how the Bible text looks: size, spacing, font, theme.
void showReaderSettingsSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: AppTheme.navySurface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    builder: (_) => const _ReaderSettingsSheet(),
  );
}

class _ReaderSettingsSheet extends ConsumerWidget {
  const _ReaderSettingsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(readerSettingsProvider);
    final n = ref.read(readerSettingsProvider.notifier);

    Widget label(String t) => Padding(
          padding: const EdgeInsets.only(top: 14, bottom: 4),
          child: Text(t.toUpperCase(),
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1, color: AppTheme.textMuted)),
        );

    Widget themeChip(String id, String name, Color bg, Color fg) => Expanded(
          child: GestureDetector(
            onTap: () => n.update(s.copyWith(theme: id)),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: s.theme == id ? AppTheme.gold : AppTheme.navyOutline, width: s.theme == id ? 2 : 1),
              ),
              alignment: Alignment.center,
              child: Text(name, style: TextStyle(color: fg, fontWeight: FontWeight.w700)),
            ),
          ),
        );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Reading', style: TextStyle(fontFamily: 'Lora', fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          // live preview
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: s.background, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.navyOutline)),
            child: Text(
              'The Lord is my shepherd; I shall not want.',
              style: TextStyle(fontFamily: s.fontFamily, fontSize: s.fontSize, height: s.lineHeight, color: s.text),
            ),
          ),
          label('Text size'),
          Row(children: [
            const Text('A', style: TextStyle(fontSize: 13)),
            Expanded(
              child: Slider(
                value: s.fontSize,
                min: 14,
                max: 30,
                divisions: 16,
                activeColor: AppTheme.gold,
                onChanged: (v) => n.update(s.copyWith(fontSize: v)),
              ),
            ),
            const Text('A', style: TextStyle(fontSize: 24)),
          ]),
          label('Line spacing'),
          Slider(
            value: s.lineHeight,
            min: 1.3,
            max: 2.2,
            divisions: 9,
            activeColor: AppTheme.gold,
            onChanged: (v) => n.update(s.copyWith(lineHeight: double.parse(v.toStringAsFixed(1)))),
          ),
          label('Font'),
          Row(children: [
            ChoiceChip(
              label: const Text('Serif', style: TextStyle(fontFamily: 'Lora')),
              selected: s.serif,
              selectedColor: AppTheme.gold,
              onSelected: (_) => n.update(s.copyWith(serif: true)),
            ),
            const SizedBox(width: 8),
            ChoiceChip(
              label: const Text('Clean', style: TextStyle(fontFamily: 'Inter')),
              selected: !s.serif,
              selectedColor: AppTheme.gold,
              onSelected: (_) => n.update(s.copyWith(serif: false)),
            ),
          ]),
          label('Page'),
          Row(children: [
            themeChip('paper', 'Paper', const Color(0xFFFBF8F1), const Color(0xFF1F2430)),
            themeChip('sepia', 'Sepia', const Color(0xFFF4ECD8), const Color(0xFF3B2F1E)),
            themeChip('night', 'Night', const Color(0xFF14181F), const Color(0xFFE6E2D8)),
          ]),
          const SizedBox(height: 6),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            activeThumbColor: AppTheme.gold,
            title: const Text('Show verse numbers'),
            value: s.showVerseNumbers,
            onChanged: (v) => n.update(s.copyWith(showVerseNumbers: v)),
          ),
        ]),
      ),
    );
  }
}
