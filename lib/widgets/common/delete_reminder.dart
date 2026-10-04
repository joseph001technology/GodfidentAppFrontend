import 'package:flutter/material.dart';
import '../../core/theme.dart';

/// Asks "Delete this reminder?" and returns true only if the user confirmed.
Future<bool> confirmDeleteReminder(BuildContext context, String title) async {
  return await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          backgroundColor: AppTheme.navySurface,
          title: const Text('Delete reminder', style: TextStyle(color: AppTheme.textPrimary)),
          content: Text('Delete "$title"? This cannot be undone.',
              style: const TextStyle(color: AppTheme.textSecondary)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Delete', style: TextStyle(color: AppTheme.danger)),
            ),
          ],
        ),
      ) ??
      false;
}
