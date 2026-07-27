import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../providers/reminders_provider.dart';
import '../../widgets/common/app_widgets.dart';

class RemindersScreen extends ConsumerWidget {
  const RemindersScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final remindersAsync = ref.watch(remindersProvider);
    return Scaffold(
      body: RefreshIndicator(onRefresh: () async => ref.invalidate(remindersProvider),
        child: SingleChildScrollView(physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 52, 16, 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Reminders', style: TextStyle(fontFamily: 'Lora', fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
            const SizedBox(height: 16),
            remindersAsync.when(loading: () => const ShimmerList(count: 4),
              error: (_, __) => const ErrorView(message: 'Could not load reminders'),
              data: (reminders) => reminders.isEmpty ? const Center(child: Padding(padding: EdgeInsets.all(32),
                child: Text('No reminders yet', style: TextStyle(color: AppTheme.textMuted))))
                : ListView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                    itemCount: reminders.length,
                    itemBuilder: (_, i) =>Container(margin: const EdgeInsets.only(bottom: 6), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(color: AppTheme.navySurface, borderRadius: BorderRadius.circular(14)),
                      child: Row(children: [
                        Text(reminders[i].title, style: const TextStyle(fontFamily: 'Inter', fontSize: 14, color: AppTheme.textPrimary)),
                        const Spacer(),
                        Text(reminders[i].date, style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppTheme.textMuted)),
                      ]),
                    ),
                  ),
            ),
          ]),
        ),
      ),
    );
  }
}
