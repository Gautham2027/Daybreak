import 'package:uuid/uuid.dart';

import 'json_helpers.dart';

const _uuid = Uuid();

/// Where a commitment came from.
enum CommitmentSource {
  manual('manual'),
  calendar('calendar');

  const CommitmentSource(this.value);

  /// The string saved in storage.
  final String value;

  /// Unknown or missing values fall back to [manual].
  static CommitmentSource fromValue(Object? value) => CommitmentSource.values
      .firstWhere((s) => s.value == value, orElse: () => manual);
}

/// A block of time the user is busy (class, practice, work...).
class Commitment {
  const Commitment({
    required this.id,
    required this.title,
    required this.start,
    required this.end,
    this.source = CommitmentSource.manual,
    this.externalId,
    this.hidden = false,
  });

  static Commitment create({
    required String title,
    required DateTime start,
    required DateTime end,
    CommitmentSource source = CommitmentSource.manual,
    String? externalId,
  }) {
    return Commitment(
      id: _uuid.v4(),
      title: title,
      start: start,
      end: end,
      source: source,
      externalId: externalId,
    );
  }

  final String id;
  final String title;
  final DateTime start;
  final DateTime end;
  final CommitmentSource source;

  /// The phone calendar's event id, for commitments imported from it.
  final String? externalId;

  /// A calendar event the user deleted for today. It's kept (hidden) so the
  /// next import doesn't bring it back.
  final bool hidden;

  bool get isFromCalendar => source == CommitmentSource.calendar;

  Commitment copyWith({
    String? title,
    DateTime? start,
    DateTime? end,
    CommitmentSource? source,
    String? externalId,
    bool? hidden,
  }) {
    return Commitment(
      id: id,
      title: title ?? this.title,
      start: start ?? this.start,
      end: end ?? this.end,
      source: source ?? this.source,
      externalId: externalId ?? this.externalId,
      hidden: hidden ?? this.hidden,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'start': start.toIso8601String(),
    'end': end.toIso8601String(),
    'source': source.value,
    'externalId': externalId,
    'hidden': hidden,
  };

  factory Commitment.fromJson(Map<String, dynamic> json) {
    final start = readDate(json['start']) ?? DateTime.now();
    return Commitment(
      id: readString(json['id'], ''),
      title: readString(json['title'], ''),
      start: start,
      end: readDate(json['end']) ?? start,
      source: CommitmentSource.fromValue(json['source']),
      externalId: json['externalId'] as String?,
      hidden: readBool(json['hidden'], false),
    );
  }

  @override
  bool operator ==(Object other) => other is Commitment && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
