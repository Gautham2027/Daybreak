import 'json_helpers.dart';

/// Planner preferences. Times of day are stored as minutes after midnight.
class Settings {
  /// Bumped when saved settings need upgrading. Version 2 = Pomodoro 50/10.
  static const int currentVersion = 2;

  const Settings({
    this.workStartMinutes = 15 * 60,
    this.workEndMinutes = 22 * 60,
    this.breakEveryMin = 50,
    this.breakLengthMin = 10,
    this.bufferMin = 10,
    this.minChunkMin = 25,
    this.demoMode = false,
    this.selectedCalendarIds = const [],
    this.includeAllDayEvents = false,
    this.autoImportBeforePlanning = true,
    this.hasOnboarded = false,
  });

  /// Default 3:00 PM.
  final int workStartMinutes;

  /// Default 10:00 PM.
  final int workEndMinutes;

  /// Pomodoro: at most this much continuous work (default 50)...
  final int breakEveryMin;

  /// ...then a break this long (default 10).
  final int breakLengthMin;

  /// Extra time left free after each commitment.
  final int bufferMin;

  /// Smallest piece a split task can be broken into.
  final int minChunkMin;

  /// When on, planning acts as if it's workStart today, so the app can be
  /// demoed or tested at any hour.
  final bool demoMode;

  /// Phone calendars to import events from (empty = not set up yet).
  final List<String> selectedCalendarIds;

  /// Import all-day events too (they block the whole day).
  final bool includeAllDayEvents;

  /// Import calendar events right before Plan my day / Re-plan.
  final bool autoImportBeforePlanning;

  /// False until the first-launch intro has been finished or skipped.
  final bool hasOnboarded;

  Settings copyWith({
    int? workStartMinutes,
    int? workEndMinutes,
    int? breakEveryMin,
    int? breakLengthMin,
    int? bufferMin,
    int? minChunkMin,
    bool? demoMode,
    List<String>? selectedCalendarIds,
    bool? includeAllDayEvents,
    bool? autoImportBeforePlanning,
    bool? hasOnboarded,
  }) {
    return Settings(
      workStartMinutes: workStartMinutes ?? this.workStartMinutes,
      workEndMinutes: workEndMinutes ?? this.workEndMinutes,
      breakEveryMin: breakEveryMin ?? this.breakEveryMin,
      breakLengthMin: breakLengthMin ?? this.breakLengthMin,
      bufferMin: bufferMin ?? this.bufferMin,
      minChunkMin: minChunkMin ?? this.minChunkMin,
      demoMode: demoMode ?? this.demoMode,
      selectedCalendarIds: selectedCalendarIds ?? this.selectedCalendarIds,
      includeAllDayEvents: includeAllDayEvents ?? this.includeAllDayEvents,
      autoImportBeforePlanning:
          autoImportBeforePlanning ?? this.autoImportBeforePlanning,
      hasOnboarded: hasOnboarded ?? this.hasOnboarded,
    );
  }

  Map<String, dynamic> toJson() => {
    'version': currentVersion,
    'workStartMinutes': workStartMinutes,
    'workEndMinutes': workEndMinutes,
    'breakEveryMin': breakEveryMin,
    'breakLengthMin': breakLengthMin,
    'bufferMin': bufferMin,
    'minChunkMin': minChunkMin,
    'demoMode': demoMode,
    'selectedCalendarIds': selectedCalendarIds,
    'includeAllDayEvents': includeAllDayEvents,
    'autoImportBeforePlanning': autoImportBeforePlanning,
    'hasOnboarded': hasOnboarded,
  };

  factory Settings.fromJson(Map<String, dynamic> json) {
    const defaults = Settings();
    // Settings saved before version 2 used a 5 min break by default; move
    // those to the new 10 min Pomodoro break.
    final version = readInt(json['version'], 1);
    var breakLength = readInt(json['breakLengthMin'], defaults.breakLengthMin);
    if (version < 2 && breakLength == 5) breakLength = 10;

    return Settings(
      workStartMinutes: readInt(
        json['workStartMinutes'],
        defaults.workStartMinutes,
      ),
      workEndMinutes: readInt(json['workEndMinutes'], defaults.workEndMinutes),
      breakEveryMin: readInt(json['breakEveryMin'], defaults.breakEveryMin),
      breakLengthMin: breakLength,
      bufferMin: readInt(json['bufferMin'], defaults.bufferMin),
      minChunkMin: readInt(json['minChunkMin'], defaults.minChunkMin),
      demoMode: readBool(json['demoMode'], false),
      selectedCalendarIds: json['selectedCalendarIds'] is List
          ? List.unmodifiable(
              (json['selectedCalendarIds'] as List).whereType<String>(),
            )
          : const [],
      includeAllDayEvents: readBool(json['includeAllDayEvents'], false),
      autoImportBeforePlanning: readBool(
        json['autoImportBeforePlanning'],
        true,
      ),
      hasOnboarded: readBool(json['hasOnboarded'], false),
    );
  }
}
