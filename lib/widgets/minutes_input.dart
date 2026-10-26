import 'package:flutter/material.dart';

import '../services/format.dart';

/// "Minutes spent" picker: − / + in steps of 5, plus quick chips.
class MinutesInput extends StatelessWidget {
  const MinutesInput({
    super.key,
    required this.value,
    required this.onChanged,
    this.quickPicks = const [15, 30, 45, 60],
  });

  final int value;
  final ValueChanged<int> onChanged;
  final List<int> quickPicks;

  static const int min = 1;
  static const int max = 600;

  void _step(int delta) {
    // Snap to the 5-minute grid when stepping (so 13 + 5 -> 15).
    final snapped = delta > 0
        ? ((value ~/ 5) + 1) * 5
        : (((value + 4) ~/ 5) - 1) * 5;
    onChanged(snapped.clamp(min, max));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton.filledTonal(
              onPressed: value > min ? () => _step(-5) : null,
              icon: const Icon(Icons.remove),
              tooltip: 'Less time',
            ),
            SizedBox(
              width: 140,
              child: Text(
                formatEstimate(value),
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            IconButton.filledTonal(
              onPressed: value < max ? () => _step(5) : null,
              icon: const Icon(Icons.add),
              tooltip: 'More time',
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          children: [
            for (final minutes in quickPicks)
              ChoiceChip(
                label: Text('$minutes min'),
                selected: value == minutes,
                onSelected: (_) => onChanged(minutes),
              ),
          ],
        ),
      ],
    );
  }
}
