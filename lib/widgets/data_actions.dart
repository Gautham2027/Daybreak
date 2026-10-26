import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/commitment_provider.dart';
import '../providers/plan_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/stats_provider.dart';
import '../providers/task_provider.dart';
import '../services/demo_data.dart';
import '../services/storage.dart';

// Whole-app data actions used by Settings and the intro screens.

/// Re-reads every provider from storage after a bulk change.
void reloadAll(BuildContext context) {
  context.read<TaskProvider>().reload();
  context.read<CommitmentProvider>().reload();
  context.read<StatsProvider>().reload();
  context.read<SettingsProvider>().reload();
  // Last, so the reloads above don't leave it marked stale.
  context.read<PlanProvider>().reload();
}

/// Asks "Are you sure?" with [message]. Returns true on confirm.
Future<bool> confirmReplace(
  BuildContext context, {
  required String title,
  required String message,
  required String action,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Icon(Icons.warning_amber_rounded),
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(action),
        ),
      ],
    ),
  );
  return confirmed == true;
}

/// Wipes everything, keeping the intro marked as seen.
Future<void> resetAllData(BuildContext context) async {
  final storage = context.read<StorageService>();
  await storage.clearAll();
  await storage.saveSettings(
    storage.getSettings().copyWith(hasOnboarded: true),
  );
  if (context.mounted) reloadAll(context);
}

/// Replaces everything with the demo week (demo mode on).
Future<void> loadDemo(BuildContext context) async {
  await loadDemoData(context.read<StorageService>(), DateTime.now());
  if (context.mounted) reloadAll(context);
}
