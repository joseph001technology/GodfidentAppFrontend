import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../providers/restriction_provider.dart';
import '../../services/focus_blocking_service.dart';
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
                    // Uninstall goes through Android's own confirmation dialog.
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
                  Row(children: [
                    Expanded(
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
                            backgroundColor: AppTheme.gold, foregroundColor: AppTheme.inkNavy),
                        child: Text('Save ${selected.length} app${selected.length == 1 ? '' : 's'}'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton(
                      onPressed: selected.isEmpty ? null : () => _confirmUninstall(apps, selected),
                      child: const Text('Uninstall…'),
                    ),
                  ]),
                  const SizedBox(height: 6),
                  const Text(
                    'Selected apps are blocked during Focus sessions. "Uninstall" asks Android to remove them; Android always makes you confirm.',
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

  Future<void> _confirmUninstall(List<InstalledApp> apps, Set<String> selected) async {
    final chosen = apps.where((a) => selected.contains(a.packageName)).toList();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Remove these apps?'),
        content: Text(
          'Android will ask you to confirm removal of each one, one after another:\n\n${chosen.map((a) => '• ${a.label}').join('\n')}',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Continue')),
        ],
      ),
    );
    if (ok != true) return;
    for (final a in chosen) {
      await FocusBlockingService.instance.uninstallApp(a.packageName);
      // Android shows one system dialog at a time; wait before the next.
      await Future<void>.delayed(const Duration(seconds: 2));
    }
    ref.invalidate(installedAppsProvider);
  }
}
