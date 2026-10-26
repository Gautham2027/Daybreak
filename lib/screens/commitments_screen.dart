import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/commitment.dart';
import '../providers/commitment_provider.dart';
import '../services/format.dart';
import '../widgets/empty_state.dart';

const List<String> _quickTitles = [
  'Class',
  'Practice',
  'Meeting',
  'Work',
  'Appointment',
];

/// Today's busy blocks (classes, practice, work...) that the planner avoids.
class CommitmentsScreen extends StatelessWidget {
  const CommitmentsScreen({super.key});

  void _openForm(BuildContext context, {Commitment? commitment}) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => CommitmentFormSheet(commitment: commitment),
    );
  }

  /// Manual commitments are deleted; calendar events are hidden for today.
  void _delete(BuildContext context, Commitment commitment) {
    final provider = context.read<CommitmentProvider>();
    provider.removeCommitment(commitment);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            commitment.isFromCalendar
                ? 'Hidden for today'
                : 'Commitment deleted',
          ),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => provider.restoreCommitment(commitment),
          ),
        ),
      );
  }

  void _onTap(BuildContext context, Commitment commitment) {
    if (!commitment.isFromCalendar) {
      _openForm(context, commitment: commitment);
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text(
            'This comes from your calendar. Edit it there, or swipe to hide '
            'it for today.',
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final commitments = context.watch<CommitmentProvider>().commitments;

    return Scaffold(
      appBar: AppBar(title: const Text("Today's commitments")),
      body: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 96),
        children: [
          if (commitments.isEmpty)
            const EmptyState(
              icon: Icons.event_available_outlined,
              title: 'No commitments today',
              subtitle:
                  'Add classes, practices, or meetings so Daybreak plans '
                  'around them.',
            ),
          for (final commitment in commitments)
            _commitmentRow(context, commitment),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(context),
        tooltip: 'Add commitment',
        child: const Icon(Icons.add),
      ),
    );
  }

  /// One commitment: swipe left to delete (or hide, for calendar events),
  /// tap to edit.
  Widget _commitmentRow(BuildContext context, Commitment commitment) {
    final theme = Theme.of(context);
    return Dismissible(
      key: ValueKey(commitment.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _delete(context, commitment),
      background: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(
          color: theme.colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(
          Icons.delete_outline,
          color: theme.colorScheme.onErrorContainer,
        ),
      ),
      child: Card(
        child: ListTile(
          leading: Icon(
            commitment.isFromCalendar
                ? Icons.calendar_month
                : Icons.event_outlined,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          title: Text(commitment.title),
          subtitle: Text(
            commitment.isFromCalendar
                ? '${formatTimeRange(commitment.start, commitment.end)}'
                      ' · From calendar'
                : formatTimeRange(commitment.start, commitment.end),
          ),
          onTap: () => _onTap(context, commitment),
        ),
      ),
    );
  }
}

/// Bottom sheet for adding or editing one commitment.
class CommitmentFormSheet extends StatefulWidget {
  const CommitmentFormSheet({super.key, this.commitment});

  final Commitment? commitment;

  @override
  State<CommitmentFormSheet> createState() => _CommitmentFormSheetState();
}

class _CommitmentFormSheetState extends State<CommitmentFormSheet> {
  late final TextEditingController _titleController;
  late TimeOfDay _start;
  late TimeOfDay _end;

  bool get _isEditing => widget.commitment != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.commitment;
    _titleController = TextEditingController(text: existing?.title ?? '');
    _titleController.addListener(() => setState(() {}));

    if (existing != null) {
      _start = TimeOfDay.fromDateTime(existing.start);
      _end = TimeOfDay.fromDateTime(existing.end);
    } else {
      // Default: the next full hour, one hour long (no later than 10-11 PM).
      final nextHour = DateTime.now().hour + 1;
      final startHour = nextHour > 22 ? 22 : nextHour;
      _start = TimeOfDay(hour: startHour, minute: 0);
      _end = TimeOfDay(hour: startHour + 1, minute: 0);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  int _minutes(TimeOfDay t) => t.hour * 60 + t.minute;
  bool get _timesValid => _minutes(_end) > _minutes(_start);
  bool get _canSave => _titleController.text.trim().isNotEmpty && _timesValid;

  Future<void> _pickTime({required bool isStart}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _start : _end,
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        // Keep the same length when moving the start time.
        final length = _minutes(_end) - _minutes(_start);
        _start = picked;
        final newEnd = _minutes(picked) + (length > 0 ? length : 60);
        if (newEnd < 24 * 60) {
          _end = TimeOfDay(hour: newEnd ~/ 60, minute: newEnd % 60);
        }
      } else {
        _end = picked;
      }
    });
  }

  void _save() {
    final now = DateTime.now();
    DateTime onToday(TimeOfDay t) =>
        DateTime(now.year, now.month, now.day, t.hour, t.minute);

    final provider = context.read<CommitmentProvider>();
    final title = _titleController.text.trim();
    final existing = widget.commitment;
    if (existing == null) {
      provider.addCommitment(
        Commitment.create(
          title: title,
          start: onToday(_start),
          end: onToday(_end),
        ),
      );
    } else {
      provider.updateCommitment(
        existing.copyWith(
          title: title,
          start: onToday(_start),
          end: onToday(_end),
        ),
      );
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    DateTime asDate(TimeOfDay t) => DateTime(2000, 1, 1, t.hour, t.minute);

    return Padding(
      // Keeps the form above the keyboard.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _isEditing ? 'Edit commitment' : 'New commitment',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _titleController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  hintText: 'e.g. Soccer practice',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final title in _quickTitles)
                    ActionChip(
                      label: Text(title),
                      onPressed: () => _titleController.text = title,
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _TimeField(
                      label: 'Start',
                      value: formatTime(asDate(_start)),
                      onTap: () => _pickTime(isStart: true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _TimeField(
                      label: 'End',
                      value: formatTime(asDate(_end)),
                      onTap: () => _pickTime(isStart: false),
                      hasError: !_timesValid,
                    ),
                  ),
                ],
              ),
              if (!_timesValid)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'End time must be after the start time.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _canSave ? _save : null,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimeField extends StatelessWidget {
  const _TimeField({
    required this.label,
    required this.value,
    required this.onTap,
    this.hasError = false,
  });

  final String label;
  final String value;
  final VoidCallback onTap;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          prefixIcon: const Icon(Icons.schedule),
          enabledBorder: hasError
              ? OutlineInputBorder(borderSide: BorderSide(color: colors.error))
              : null,
        ),
        child: Text(value),
      ),
    );
  }
}
