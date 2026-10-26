import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/settings.dart';
import '../providers/settings_provider.dart';
import '../services/calendar.dart';
import '../services/format.dart';
import '../theme/tokens.dart';
import '../widgets/calendar_import.dart';
import '../widgets/data_actions.dart';

/// Planner preferences, demo mode, and data reset.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _pickWorkTime(
    BuildContext context,
    Settings settings, {
    required bool isStart,
  }) async {
    final provider = context.read<SettingsProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final current = isStart
        ? settings.workStartMinutes
        : settings.workEndMinutes;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current ~/ 60, minute: current % 60),
    );
    if (picked == null) return;

    final minutes = picked.hour * 60 + picked.minute;
    final start = isStart ? minutes : settings.workStartMinutes;
    final end = isStart ? settings.workEndMinutes : minutes;
    if (end <= start) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('End time must be after start time.')),
        );
      return;
    }
    provider.updateSettings(
      settings.copyWith(workStartMinutes: start, workEndMinutes: end),
    );
  }

  Future<void> _resetAllData(BuildContext context) async {
    final ok = await confirmReplace(
      context,
      title: 'Reset all data?',
      message:
          'This deletes every task, commitment, plan, time log, and your XP '
          'and streak. It can\'t be undone.',
      action: 'Reset',
    );
    if (!ok || !context.mounted) return;
    await resetAllData(context);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('All data reset')));
  }

  Future<void> _loadDemoData(BuildContext context) async {
    final ok = await confirmReplace(
      context,
      title: 'Load demo data?',
      message:
          'This replaces all your data with a sample week of tasks, '
          'commitments, and logged time. Demo mode will be turned on.',
      action: 'Load demo',
    );
    if (!ok || !context.mounted) return;
    await loadDemo(context);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Demo data loaded. Head to Today!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SettingsProvider>();
    final settings = provider.settings;
    void update(Settings s) => provider.updateSettings(s);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: Spacing.xxl),
        children: _grouped([
          ..._workWindowSection(context, settings),
          ..._focusAndPlanningSections(settings, update),
          ..._calendarSection(context, settings, update),
          ..._demoAndDataSections(context, settings, update),
          ..._aboutSection(context),
        ]),
      ),
    );
  }

  /// Puts the rows after each section header into one rounded card, so
  /// every section reads as a group.
  List<Widget> _grouped(List<Widget> items) {
    final result = <Widget>[];
    var group = <Widget>[];
    void flush() {
      if (group.isEmpty) return;
      result.add(Card(child: Column(children: group)));
      group = [];
    }

    for (final item in items) {
      if (item is _SectionHeader) {
        flush();
        result.add(item);
      } else if (item is Divider) {
        flush();
      } else {
        group.add(item);
      }
    }
    flush();
    return result;
  }

  List<Widget> _workWindowSection(BuildContext context, Settings settings) {
    final theme = Theme.of(context);
    return [
      const _SectionHeader('Work window'),
      ListTile(
        leading: const Icon(Icons.wb_twilight),
        title: const Text('Start'),
        trailing: Text(
          formatMinutesOfDay(settings.workStartMinutes),
          style: theme.textTheme.titleMedium,
        ),
        onTap: () => _pickWorkTime(context, settings, isStart: true),
      ),
      ListTile(
        leading: const Icon(Icons.nightlight_outlined),
        title: const Text('End'),
        trailing: Text(
          formatMinutesOfDay(settings.workEndMinutes),
          style: theme.textTheme.titleMedium,
        ),
        onTap: () => _pickWorkTime(context, settings, isStart: false),
      ),
    ];
  }

  List<Widget> _focusAndPlanningSections(
    Settings settings,
    void Function(Settings) update,
  ) {
    return [
      _SectionHeader(
        'Focus',
        trailing: '${settings.breakEveryMin} / ${settings.breakLengthMin} min',
      ),
      _SliderTile(
        icon: Icons.timer_outlined,
        title: 'Work session',
        value: settings.breakEveryMin,
        min: 25,
        max: 90,
        onChanged: (v) => update(settings.copyWith(breakEveryMin: v)),
      ),
      _SliderTile(
        icon: Icons.coffee_outlined,
        title: 'Break',
        value: settings.breakLengthMin,
        min: 5,
        max: 20,
        onChanged: (v) => update(settings.copyWith(breakLengthMin: v)),
      ),

      const _SectionHeader('Planning'),
      _SliderTile(
        icon: Icons.more_time,
        title: 'Buffer after commitments',
        value: settings.bufferMin,
        min: 0,
        max: 30,
        onChanged: (v) => update(settings.copyWith(bufferMin: v)),
      ),
      _SliderTile(
        icon: Icons.view_agenda_outlined,
        title: 'Minimum chunk length',
        subtitle: 'Smallest piece a task is split into across gaps',
        value: settings.minChunkMin,
        min: 10,
        max: 60,
        onChanged: (v) => update(settings.copyWith(minChunkMin: v)),
      ),
    ];
  }

  List<Widget> _calendarSection(
    BuildContext context,
    Settings settings,
    void Function(Settings) update,
  ) {
    final calendarSupported = context.read<CalendarService>().isSupported;
    return [
      const _SectionHeader('Calendar'),
      if (!calendarSupported)
        const ListTile(
          leading: Icon(Icons.info_outline),
          title: Text('Calendar import is available in the mobile app.'),
        )
      else ...[
        ListTile(
          leading: const Icon(Icons.calendar_month_outlined),
          title: const Text('Choose calendars'),
          subtitle: Text(switch (settings.selectedCalendarIds.length) {
            0 => 'None selected',
            1 => '1 calendar',
            final n => '$n calendars',
          }),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => chooseCalendars(context),
        ),
        SwitchListTile(
          secondary: const Icon(Icons.wb_sunny_outlined),
          title: const Text('Include all-day events'),
          subtitle: const Text('They block your whole work window.'),
          value: settings.includeAllDayEvents,
          onChanged: (v) => update(settings.copyWith(includeAllDayEvents: v)),
        ),
        SwitchListTile(
          secondary: const Icon(Icons.sync),
          title: const Text('Auto-import before planning'),
          subtitle: const Text(
            'Refresh calendar events when you tap Plan my day or Re-plan.',
          ),
          value: settings.autoImportBeforePlanning,
          onChanged: (v) =>
              update(settings.copyWith(autoImportBeforePlanning: v)),
        ),
      ],
    ];
  }

  List<Widget> _demoAndDataSections(
    BuildContext context,
    Settings settings,
    void Function(Settings) update,
  ) {
    final theme = Theme.of(context);
    return [
      const _SectionHeader('Demo'),
      SwitchListTile(
        secondary: const Icon(Icons.science_outlined),
        title: const Text('Demo mode'),
        subtitle: Text(
          'Plan as if it\'s ${formatMinutesOfDay(settings.workStartMinutes)}'
          ' today, so you can try Daybreak at any hour.',
        ),
        value: settings.demoMode,
        onChanged: (v) => update(settings.copyWith(demoMode: v)),
      ),

      ListTile(
        leading: const Icon(Icons.auto_awesome_outlined),
        title: const Text('Load demo data'),
        subtitle: const Text('A sample week to explore or record a demo'),
        onTap: () => _loadDemoData(context),
      ),
      ListTile(
        leading: const Icon(Icons.slideshow_outlined),
        title: const Text('Show intro again'),
        onTap: () => update(settings.copyWith(hasOnboarded: false)),
      ),

      const _SectionHeader('Data'),
      ListTile(
        leading: Icon(
          Icons.delete_forever_outlined,
          color: theme.colorScheme.error,
        ),
        title: Text(
          'Reset all data',
          style: TextStyle(color: theme.colorScheme.error),
        ),
        onTap: () => _resetAllData(context),
      ),
    ];
  }

  List<Widget> _aboutSection(BuildContext context) {
    return [
      const Divider(height: 32),
      ListTile(
        leading: const Icon(Icons.info_outline),
        title: const Text('About Daybreak'),
        subtitle: const Text('Plan the day before it plans you.'),
        onTap: () => showAboutDialog(
          context: context,
          applicationName: 'Daybreak',
          applicationLegalese:
              'Built with Flutter for the 2026 Congressional App '
              'Challenge.',
          children: const [
            SizedBox(height: 12),
            Text('Plan the day before it plans you.'),
          ],
        ),
      ),
    ];
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title, {this.trailing});

  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.labelMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w800,
      letterSpacing: 0.8,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Spacing.l + Spacing.xs,
        Spacing.xl,
        Spacing.l + Spacing.xs,
        Spacing.xs,
      ),
      child: Row(
        children: [
          Expanded(child: Text(title.toUpperCase(), style: style)),
          if (trailing != null) Text(trailing!, style: style),
        ],
      ),
    );
  }
}

/// A labelled slider in 5-minute steps, showing its value on the right.
class _SliderTile extends StatelessWidget {
  const _SliderTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Spacing.l,
        Spacing.m,
        Spacing.l,
        Spacing.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: Spacing.l),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text('$value min', style: theme.textTheme.titleSmall),
            ],
          ),
          if (subtitle != null)
            Padding(
              // Lines up with the title, past the icon.
              padding: const EdgeInsets.only(left: 40),
              child: Text(
                subtitle!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          Slider(
            value: value.clamp(min, max).toDouble(),
            min: min.toDouble(),
            max: max.toDouble(),
            divisions: (max - min) ~/ 5,
            label: '$value min',
            onChanged: (v) => onChanged(v.round()),
          ),
        ],
      ),
    );
  }
}
