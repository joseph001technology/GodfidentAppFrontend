import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../providers/restriction_provider.dart';
import '../../widgets/common/app_widgets.dart';

/// Lists the REAL apps installed on this phone. Nothing here is hardcoded.
class AppRestrictionsScreen extends ConsumerStatefulWidget {
  const AppRestrictionsScreen({super.key});
  @override
  ConsumerState<AppRestrictionsScreen> createState() => _AppRestrictionsScreenState();
}

class _AppRestrictionsScreenState extends ConsumerState<AppRestrictionsScreen> {
  Set<String>? _selected;
  String _query = '';
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final installed = ref.watch(installedAppsProvider);
    final saved = ref.watch(restrictedAppsProvider);
    _selected ??= saved.valueOrNull?.map((a) => a.packageName).toSet();

    return Scaffold(
      backgroundColor: AppTheme.navy,
      appBar: AppBar(
        title: const Text('App Restrictions'),
        backgroundColor: AppTheme.navy,
        foregroundColor: AppTheme.inkNavy,
        elevation: 0,
      ),
      body: installed.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.gold)),
        error: (e, _) => ErrorView(
          message: 'Could not read the apps installed on this phone.',
          onRetry: () => ref.invalidate(installedAppsProvider),
        ),
        data: (apps) {
          if (apps.isEmpty) {
            return const EmptyView(
              icon: Icons.apps_outlined,
              title: 'No apps found',
              subtitle: 'Godfident could not find any launchable apps on this device.',
            );
          }
          final selected = _selected ?? <String>{};
          final shown = apps
              .where((a) => a.label.toLowerCase().contains(_query.toLowerCase()))
              .toList();
          return Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search your apps',
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: shown.length,
                itemBuilder: (_, i) {
                  final a = shown[i];
                  final on = selected.contains(a.packageName);
                  return CheckboxListTile(
                    activeColor: AppTheme.gold,
                    checkColor: AppTheme.inkNavy,
                    value: on,
                    onChanged: (v) => setState(() {
                      final s = {...selected};
                      v == true ? s.add(a.packageName) : s.remove(a.packageName);
                      _selected = s;
                    }),
                    secondary: a.icon == null
                        ? const Icon(Icons.android)
                        : Image.memory(a.icon!, width: 36, height: 36, gaplessPlayback: true),
                    title: Text(a.label, style: const TextStyle(color: AppTheme.textPrimary)),
                    subtitle: Text(a.packageName,
                        style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                    controlAffinity: ListTileControlAffinity.trailing,
                  );
                },
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saving
                          ? null
                          : () async {
                              setState(() => _saving = true);
                              final chosen = apps.where((a) => selected.contains(a.packageName)).toList();
                              await ref.read(restrictedAppsProvider.notifier).setSelection(chosen);
                              if (!context.mounted) return;
                              Navigator.of(context).pop();
                            },
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.gold,
                          foregroundColor: AppTheme.inkNavy,
                          padding: const EdgeInsets.symmetric(vertical: 14)),
                      child: Text('Save ${selected.length} app${selected.length == 1 ? '' : 's'}'),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Selected apps are blocked only while a Focus session is running. Outside Focus Mode they work normally.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                  ),
                ]),
              ),
            ),
          ]);
        },
      ),
    );
  }
}
