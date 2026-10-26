import 'package:flutter/foundation.dart';

import '../models/commitment.dart';
import '../models/settings.dart';
import '../services/calendar.dart';
import '../services/calendar_convert.dart';
import '../services/storage.dart';

class CommitmentProvider extends ChangeNotifier {
  CommitmentProvider(this._storage) {
    _all = _storage.getCommitmentsForDay(DateTime.now());
  }

  final StorageService _storage;

  /// Today's commitments, including calendar events the user hid.
  List<Commitment> _all = [];

  /// Re-reads today's commitments from storage.
  void reload() {
    _all = _storage.getCommitmentsForDay(DateTime.now());
    notifyListeners();
  }

  /// Today's visible commitments, sorted by start time.
  List<Commitment> get commitments =>
      List.unmodifiable(_all.where((c) => !c.hidden));

  Future<void> addCommitment(Commitment commitment) async {
    _all.add(commitment);
    _sort();
    notifyListeners();
    await _storage.saveCommitment(commitment);
  }

  Future<void> updateCommitment(Commitment commitment) async {
    final index = _all.indexWhere((c) => c.id == commitment.id);
    if (index == -1) return;
    _all[index] = commitment;
    _sort();
    notifyListeners();
    await _storage.saveCommitment(commitment);
  }

  /// Manual commitments are deleted. Calendar ones are only hidden for
  /// today, so the next import doesn't bring them back.
  Future<void> removeCommitment(Commitment commitment) async {
    if (commitment.isFromCalendar) {
      await updateCommitment(commitment.copyWith(hidden: true));
      return;
    }
    _all.removeWhere((c) => c.id == commitment.id);
    notifyListeners();
    await _storage.deleteCommitment(commitment.id);
  }

  /// Puts back a commitment removed with [removeCommitment] (for Undo).
  Future<void> restoreCommitment(Commitment commitment) {
    if (commitment.isFromCalendar) {
      return updateCommitment(commitment.copyWith(hidden: false));
    }
    return addCommitment(commitment);
  }

  /// Replaces today's calendar commitments with fresh ones from the phone
  /// calendar (add new, update changed, remove gone). Manual commitments
  /// aren't touched. Returns how many events were imported. Throws if the
  /// calendar can't be read.
  Future<int> importFromCalendar(
    CalendarService calendar,
    Settings settings,
    DateTime day,
  ) async {
    final imported = await calendar.eventsForDay(
      day,
      settings.selectedCalendarIds,
      includeAllDay: settings.includeAllDayEvents,
    );
    final merge = mergeCalendarCommitments(existing: _all, imported: imported);

    final removedIds = merge.toRemove.map((c) => c.id).toSet();
    final updated = {for (final c in merge.toUpdate) c.id: c};
    _all = [
      for (final c in _all)
        if (!removedIds.contains(c.id)) updated[c.id] ?? c,
      ...merge.toAdd,
    ];
    _sort();
    notifyListeners();

    for (final c in [...merge.toAdd, ...merge.toUpdate]) {
      await _storage.saveCommitment(c);
    }
    for (final id in removedIds) {
      await _storage.deleteCommitment(id);
    }
    return imported.length;
  }

  void _sort() => _all.sort((a, b) => a.start.compareTo(b.start));
}
