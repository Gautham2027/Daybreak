import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/plan_provider.dart';
import 'settings_screen.dart';
import 'stats_screen.dart';
import 'tasks_screen.dart';
import 'today_screen.dart';

/// The main app frame: a bottom NavigationBar that switches between tabs.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Coming back to the app on a new day swaps in today's plan.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<PlanProvider>().checkForNewDay(DateTime.now());
    }
  }

  static const int _tasksTab = 1;

  @override
  Widget build(BuildContext context) {
    final screens = [
      TodayScreen(
        onShowTasks: () => setState(() => _selectedIndex = _tasksTab),
      ),
      const TasksScreen(),
      const StatsScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      // IndexedStack keeps each tab's state when switching between them.
      body: IndexedStack(index: _selectedIndex, children: screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.wb_twilight_outlined),
            selectedIcon: Icon(Icons.wb_twilight),
            label: 'Today',
          ),
          NavigationDestination(
            icon: Icon(Icons.checklist_outlined),
            selectedIcon: Icon(Icons.checklist),
            label: 'Tasks',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights),
            label: 'Stats',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
