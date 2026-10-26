import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/json_helpers.dart';
import '../models/task.dart';
import '../providers/task_provider.dart';
import '../services/format.dart';
import '../theme/colors.dart';
import '../theme/tokens.dart';

const List<String> taskCategories = [
  'Homework',
  'Project',
  'Study',
  'Chores',
  'Other',
];

const int _minEstimate = 5;
const int _maxEstimate = 240;
const List<int> _quickEstimates = [15, 30, 60, 90];

/// Add a new task, or edit [task] if one is passed in.
class TaskFormScreen extends StatefulWidget {
  const TaskFormScreen({super.key, this.task});

  final Task? task;

  @override
  State<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends State<TaskFormScreen> {
  late final TextEditingController _titleController;
  late DateTime _dueDate;
  late int _importance;
  late int _estimateMin;
  String? _category;

  bool get _isEditing => widget.task != null;
  DateTime get _today => dateOnly(DateTime.now());

  @override
  void initState() {
    super.initState();
    final task = widget.task;
    _titleController = TextEditingController(text: task?.title ?? '');
    _titleController.addListener(() => setState(() {}));
    _dueDate = task?.dueDate ?? _today.add(const Duration(days: 1));
    _importance = task?.importance ?? Task.medium;
    _estimateMin = task?.estimateMin ?? 30;
    _category = task?.category;
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  bool get _canSave => _titleController.text.trim().isNotEmpty;

  /// True if anything differs from what the form started with.
  bool get _hasChanges {
    final task = widget.task;
    if (task == null) {
      return _titleController.text.trim().isNotEmpty ||
          _dueDate != _today.add(const Duration(days: 1)) ||
          _importance != Task.medium ||
          _estimateMin != 30 ||
          _category != null;
    }
    return _titleController.text.trim() != task.title ||
        _dueDate != task.dueDate ||
        _importance != task.importance ||
        _estimateMin != task.estimateMin ||
        _category != task.category;
  }

  Future<void> _pickDate() async {
    // Past dates are only allowed when editing (like a task that's already overdue).
    final firstDate = _isEditing
        ? (_dueDate.isBefore(_today) ? _dueDate : _today).subtract(
            const Duration(days: 365),
          )
        : _today;
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: firstDate,
      lastDate: _today.add(const Duration(days: 365 * 2)),
    );
    if (picked != null) setState(() => _dueDate = dateOnly(picked));
  }

  Future<void> _save() async {
    final provider = context.read<TaskProvider>();
    final title = _titleController.text.trim();
    final existing = widget.task;

    if (existing == null) {
      provider.addTask(
        Task.create(
          title: title,
          dueDate: _dueDate,
          importance: _importance,
          estimateMin: _estimateMin,
          category: _category,
        ),
      );
    } else {
      provider.updateTask(
        existing.copyWith(
          title: title,
          dueDate: _dueDate,
          importance: _importance,
          estimateMin: _estimateMin,
          category: _category,
          clearCategory: _category == null,
        ),
      );
    }
    Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final confirmed = await _confirm(
      title: 'Delete task?',
      message: 'This can\'t be undone.',
      action: 'Delete',
    );
    if (!confirmed || !mounted) return;
    context.read<TaskProvider>().deleteTask(widget.task!.id);
    Navigator.of(context).pop();
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String action,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(action),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _onBackWithChanges() async {
    final discard = await _confirm(
      title: 'Discard changes?',
      message: 'Your changes to this task won\'t be saved.',
      action: 'Discard',
    );
    if (discard && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: !_hasChanges,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onBackWithChanges();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isEditing ? 'Edit task' : 'New task'),
          actions: [
            if (_isEditing)
              IconButton(
                onPressed: _delete,
                tooltip: 'Delete task',
                icon: const Icon(Icons.delete_outline),
              ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(
            Spacing.xl,
            Spacing.s,
            Spacing.xl,
            Spacing.xl,
          ),
          children: [
            TextField(
              controller: _titleController,
              autofocus: !_isEditing,
              maxLength: 80,
              textCapitalization: TextCapitalization.sentences,
              // A big, quiet title field: no box, just the words.
              style: theme.textTheme.headlineSmall,
              decoration: InputDecoration(
                hintText: 'What do you need to do?',
                hintStyle: theme.textTheme.headlineSmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            Divider(color: theme.colorScheme.outlineVariant),
            const SizedBox(height: Spacing.l),
            ..._dueDateField(theme),
            const SizedBox(height: Spacing.xl),
            ..._importanceField(),
            const SizedBox(height: Spacing.xl),
            ..._estimateField(theme),
            const SizedBox(height: Spacing.xl),
            ..._categoryField(),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: FilledButton(
              onPressed: _canSave ? _save : null,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              child: const Text('Save'),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _dueDateField(ThemeData theme) {
    return [
      _SectionLabel('Due date'),
      InkWell(
        onTap: _pickDate,
        borderRadius: BorderRadius.circular(Radii.control),
        child: InputDecorator(
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.event_outlined),
          ),
          child: Text(
            formDateLabel(_dueDate, _today),
            style: theme.textTheme.bodyLarge,
          ),
        ),
      ),
    ];
  }

  List<Widget> _importanceField() {
    return [
      _SectionLabel('Importance'),
      SegmentedButton<int>(
        // The selected segment takes the importance's own color.
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: DaybreakColors.of(context)
              .importance(_importance)
              .withValues(alpha: 0.18),
          selectedForegroundColor: Theme.of(context).colorScheme.onSurface,
        ),
        segments: const [
          ButtonSegment(value: Task.low, label: Text('Low')),
          ButtonSegment(value: Task.medium, label: Text('Medium')),
          ButtonSegment(value: Task.high, label: Text('High')),
        ],
        selected: {_importance},
        onSelectionChanged: (selection) =>
            setState(() => _importance = selection.first),
      ),
    ];
  }

  /// Big "45 min" readout, a 5-240 slider in 5-minute steps, and quick picks.
  List<Widget> _estimateField(ThemeData theme) {
    return [
      _SectionLabel('Time estimate'),
      Center(
        child: Text(
          formatEstimate(_estimateMin),
          style: theme.textTheme.headlineMedium?.copyWith(
            color: theme.colorScheme.primary,
          ),
        ),
      ),
      Slider(
        value: _estimateMin.clamp(_minEstimate, _maxEstimate).toDouble(),
        min: _minEstimate.toDouble(),
        max: _maxEstimate.toDouble(),
        divisions: (_maxEstimate - _minEstimate) ~/ 5,
        label: formatEstimate(_estimateMin),
        onChanged: (value) => setState(() => _estimateMin = value.round()),
      ),
      Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        children: [
          for (final minutes in _quickEstimates)
            ChoiceChip(
              label: Text('$minutes min'),
              selected: _estimateMin == minutes,
              onSelected: (_) => setState(() => _estimateMin = minutes),
            ),
        ],
      ),
    ];
  }

  List<Widget> _categoryField() {
    // Keep a category that isn't in the list (from older data) selectable.
    final categories = [
      ...taskCategories,
      if (_category != null && !taskCategories.contains(_category)) _category!,
    ];
    return [
      _SectionLabel('Category'),
      DropdownButtonFormField<String?>(
        initialValue: _category,
        decoration: const InputDecoration(),
        items: [
          const DropdownMenuItem(value: null, child: Text('None')),
          for (final category in categories)
            DropdownMenuItem(value: category, child: Text(category)),
        ],
        onChanged: (value) => setState(() => _category = value),
      ),
    ];
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
