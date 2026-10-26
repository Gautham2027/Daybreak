import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'providers/commitment_provider.dart';
import 'providers/plan_provider.dart';
import 'providers/progress_controller.dart';
import 'providers/settings_provider.dart';
import 'providers/stats_provider.dart';
import 'providers/task_provider.dart';
import 'services/calendar.dart';
import 'services/storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();

  final storage = StorageService();
  await storage.init();

  runApp(buildApp(storage));
}

/// The whole app with its providers, reading from [storage].
/// (Also used by integration_test/screenshots_test.dart.)
Widget buildApp(StorageService storage) {
  // Created up front because PlanProvider reads from the other four.
  final taskProvider = TaskProvider(storage);
  final commitmentProvider = CommitmentProvider(storage);
  final statsProvider = StatsProvider(storage);
  final settingsProvider = SettingsProvider(storage);
  final calendar = CalendarService();
  final planProvider = PlanProvider(
    storage,
    tasks: taskProvider,
    commitments: commitmentProvider,
    settings: settingsProvider,
    stats: statsProvider,
    calendar: calendar,
  );
  final progress = ProgressController(
    tasks: taskProvider,
    stats: statsProvider,
    plan: planProvider,
  );

  return MultiProvider(
    providers: [
      // Settings uses this directly for "Reset all data".
      Provider<StorageService>.value(value: storage),
      Provider<CalendarService>.value(value: calendar),
      ChangeNotifierProvider.value(value: taskProvider),
      ChangeNotifierProvider.value(value: commitmentProvider),
      ChangeNotifierProvider.value(value: statsProvider),
      ChangeNotifierProvider.value(value: settingsProvider),
      ChangeNotifierProvider.value(value: planProvider),
      // Logs time and completes tasks (screens call this, not the math).
      Provider<ProgressController>.value(value: progress),
    ],
    child: const DaybreakApp(),
  );
}
