/// Parse an API timestamp (e.g. "2026-09-21T09:00:00+03:00") as WALL-CLOCK time,
/// ignoring the trailing timezone offset.
///
/// Schedules/exams are inherently in the institution's own timezone (MSK). If we
/// let [DateTime.parse] convert the instant to the device's local zone, a phone
/// not at +03:00 would show lessons on the wrong day (e.g. Monday's classes under
/// Sunday) and at the wrong time. Taking the literal Y-M-D-H-M-S keeps them stable
/// on every device.
DateTime apiWallClock(String s) {
  final m =
      RegExp(r'^(\d{4})-(\d{2})-(\d{2})(?:[T ](\d{2}):(\d{2})(?::(\d{2}))?)?')
          .firstMatch(s);
  if (m != null) {
    int g(int i) => int.tryParse(m.group(i) ?? '') ?? 0;
    return DateTime(g(1), g(2), g(3), g(4), g(5), g(6));
  }
  // Fallback: best-effort parse, then drop the zone by rebuilding from parts.
  final d = DateTime.parse(s);
  return DateTime(d.year, d.month, d.day, d.hour, d.minute, d.second);
}

/// Same, but only the calendar date (midnight).
DateTime apiCalendarDate(String s) {
  final d = apiWallClock(s);
  return DateTime(d.year, d.month, d.day);
}
