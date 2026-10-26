// Helpers for fromJson. If a value is missing or the wrong type (like from
// an older save), they return a default instead of crashing.

int readInt(Object? value, int fallback) =>
    value is num ? value.toInt() : fallback;

double readDouble(Object? value, double fallback) =>
    value is num ? value.toDouble() : fallback;

bool readBool(Object? value, bool fallback) => value is bool ? value : fallback;

String readString(Object? value, String fallback) =>
    value is String ? value : fallback;

/// Parses an ISO 8601 string. Returns null if missing or invalid.
DateTime? readDate(Object? value) =>
    value is String ? DateTime.tryParse(value) : null;

/// Strips the time part, leaving local midnight of the same day.
DateTime dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);
