import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../providers/notes_provider.dart';
import '../../widgets/common/app_widgets.dart';

class NotesScreen extends ConsumerWidget {
  const NotesScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notesAsync = ref.watch(notesProvider);
    return Scaffold(
      body: RefreshIndicator(onRefresh: () async => ref.read(notesProvider.notifier).refresh(),
        child: SingleChildScrollView(physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 52, 16, 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Notes', style: TextStyle(fontFamily: 'Lora', fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
            const SizedBox(height: 16),
            notesAsync.when(loading: () => const ShimmerList(count: 4),
              error: (_, __) => const ErrorView(message: 'Could not load notes'),
              data: (notes) => notes.isEmpty ? const Center(child: Padding(padding: EdgeInsets.all(32),
                child: Column(children: [
                  Icon(Icons.note_outlined, size: 56, color: AppTheme.navyOutline),
                  SizedBox(height: 16),
                  Text('No notes yet', style: TextStyle(color: AppTheme.textMuted, fontSize: 14)),
                ]))) : ListView.builder(
                  shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                  itemCount: notes.length,
                  itemBuilder: (_, i) => Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: AppTheme.navySurface, borderRadius: BorderRadius.circular(14)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(notes[i].title, style: const TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                      const SizedBox(height: 4),
                      Text(notes[i].content, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppTheme.textMuted)),
                    ]),
                  ),)),
          ])),
      ),
    );
  }
}
