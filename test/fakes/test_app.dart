import 'package:daybreak/providers/commitment_provider.dart';
import 'package:daybreak/providers/plan_provider.dart';
import 'package:daybreak/providers/progress_controller.dart';
import 'package:daybreak/providers/settings_provider.dart';
import 'package:daybreak/providers/stats_provider.dart';
import 'package:daybreak/providers/task_provider.dart';
import 'package:daybreak/services/calendar.dart';
import 'package:daybreak/services/storage.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'in_memory_storage.dart';

/// Every provider the app uses, backed by one in-memory storage.
class TestProviders {
  TestProviders([InMemoryStorage? storage, CalendarService? calendar])
    : storage = storage ?? InMemoryStorage(),
      calendar = calendar ?? CalendarService() {
    tasks = TaskProvider(this.storage);
    commitments = CommitmentProvider(this.storage);
    stats = StatsProvider(this.storage);
    settings = SettingsProvider(this.storage);
    plan = PlanProvider(
      this.storage,
      tasks: tasks,
      commitments: commitments,
      settings: settings,
      stats: stats,
      calendar: this.calendar,
    );
    progress = ProgressController(tasks: tasks, stats: stats, plan: plan);
  }

  final InMemoryStorage storage;
  final CalendarService calendar;
  late final TaskProvider tasks;
  late final CommitmentProvider commitments;
  late final StatsProvider stats;
  late final SettingsProvider settings;
  late final PlanProvider plan;
  late final ProgressController progress;

  /// Wraps [child] with all the providers, like main.dart does.
  Widget wrap(Widget child) {
    return MultiProvider(
      providers: [
        Provider<StorageService>.value(value: storage),
        Provider<CalendarService>.value(value: calendar),
        ChangeNotifierProvider.value(value: tasks),
        ChangeNotifierProvider.value(value: commitments),
        ChangeNotifierProvider.value(value: stats),
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider.value(value: plan),
        Provider<ProgressController>.value(value: progress),
      ],
      child: child,
    );
  }
}
