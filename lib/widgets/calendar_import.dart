import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
import '../services/calendar.dart';

// UI for picking which phone calendars to use (from Settings).
// Every path ends with the app still working, even if access is denied.

/// Asks for calendar access. Shows a friendly explanation if it's denied or
/// unavailable. Returns true if granted.
Future<bool> ensureCalendarAccess(BuildContext context) async {
  final calendar = context.read<CalendarService>();
  final permission = await calendar.requestPermission();
  if (permission == CalendarPermission.granted) return true;
  if (!context.mounted) return false;

  if (permission == CalendarPermission.unavailable) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Calendar isn\'t available here. You can still add commitments '
          'by hand.',
        ),
      ),
    );
    return false;
  }

  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Icon(Icons.event_busy),
      title: const Text('Calendar access is off'),
      content: const Text(
        'To import events, open your phone\'s Settings, find Daybreak, and '
        'allow Calendars. You can keep adding commitments by hand in the '
        'meantime.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Not now'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop();
            calendar.openSettings();
          },
          child: const Text('Open Settings'),
        ),
      ],
    ),
  );
  return false;
}

/// Gets access, then lets the user pick calendars. Saves the choice to
/// Settings and returns it (null if cancelled or no access).
Future<List<String>?> chooseCalendars(BuildContext context) async {
  if (!await ensureCalendarAccess(context) || !context.mounted) return null;
  final settings = context.read<SettingsProvider>();
  final chosen = await showModalBottomSheet<List<String>>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => CalendarPickerSheet(
      initiallySelected: settings.settings.selectedCalendarIds,
    ),
  );
  if (chosen == null) return null;
  await settings.updateSettings(
    settings.settings.copyWith(selectedCalendarIds: chosen),
  );
  return chosen;
}

/// Parses "#RRGGBB" or "#AARRGGBB" from the phone calendar.
Color? _parseHexColor(String? hex) {
  if (hex == null) return null;
  var value = hex.replaceFirst('#', '');
  if (value.length == 6) value = 'FF$value';
  final parsed = int.tryParse(value, radix: 16);
  return parsed == null ? null : Color(parsed);
}

/// Checkbox list of the phone's calendars. Pops with the chosen ids.
class CalendarPickerSheet extends StatefulWidget {
  const CalendarPickerSheet({super.key, this.initiallySelected = const []});

  final List<String> initiallySelected;

  @override
  State<CalendarPickerSheet> createState() => _CalendarPickerSheetState();
}

class _CalendarPickerSheetState extends State<CalendarPickerSheet> {
  late final Future<List<DeviceCalendarInfo>> _calendars;
  late final Set<String> _selected = {...widget.initiallySelected};

  @override
  void initState() {
    super.initState();
    _calendars = context.read<CalendarService>().listCalendars();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
        child: FutureBuilder<List<DeviceCalendarInfo>>(
          future: _calendars,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            return _pickerBody(context, snapshot.data!);
          },
        ),
      ),
    );
  }

  /// Title, explanation, a checkbox per calendar, and the save button.
  Widget _pickerBody(BuildContext context, List<DeviceCalendarInfo> calendars) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text('Choose calendars', style: theme.textTheme.titleLarge),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Text(
            'Daybreak plans around events from these calendars.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        if (calendars.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('No calendars found on this device.'),
          ),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final c in calendars)
                CheckboxListTile(
                  value: _selected.contains(c.id),
                  onChanged: (on) => setState(() {
                    on == true ? _selected.add(c.id) : _selected.remove(c.id);
                  }),
                  secondary: CircleAvatar(
                    radius: 7,
                    // The calendar's own color, from the phone.
                    backgroundColor:
                        _parseHexColor(c.colorHex) ?? theme.colorScheme.primary,
                  ),
                  title: Text(c.name),
                  subtitle: c.accountName == null ? null : Text(c.accountName!),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: FilledButton(
            onPressed: () => Navigator.of(context).pop(_selected.toList()),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
            child: Text(
              _selected.isEmpty
                  ? 'Save'
                  : 'Use ${_selected.length} '
                        '${_selected.length == 1 ? 'calendar' : 'calendars'}',
            ),
          ),
        ),
      ],
    );
  }
}
