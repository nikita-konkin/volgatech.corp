import '../models/schedule.dart';

/// Pure aggregation for the «Обзор недели» screen — no Flutter imports, so the
/// counting/plural/gap logic is unit-tested directly (see test/week_summary_test.dart).

/// Russian plural for «пара» (lesson pair): 1 пара · 2–4 пары · else пар.
String russianPairs(int n) {
  final n100 = n % 100, n10 = n % 10;
  if (n10 == 1 && n100 != 11) return '$n пара';
  if (n10 >= 2 && n10 <= 4 && !(n100 >= 12 && n100 <= 14)) return '$n пары';
  return '$n пар';
}

/// Minutes since midnight from an "HH:MM[:SS]" string, or null if unparseable.
int? minutesOfDay(String? t) {
  if (t == null || t.length < 5) return null;
  final h = int.tryParse(t.substring(0, 2));
  final m = int.tryParse(t.substring(3, 5));
  return (h == null || m == null) ? null : h * 60 + m;
}

/// Human duration: "1 ч 30 мин" · "2 ч" · "45 мин".
String humanDuration(int minutes) {
  final h = minutes ~/ 60, m = minutes % 60;
  if (h == 0) return '$m мин';
  return m == 0 ? '$h ч' : '$h ч $m мин';
}

/// "08:05" from minutes-since-midnight.
String hhmm(int min) =>
    '${(min ~/ 60).toString().padLeft(2, '0')}:${(min % 60).toString().padLeft(2, '0')}';

/// One day's aggregated stats for the overview row.
class DayStats {
  final int count;
  final int? firstBegin; // minutes since midnight
  final int? lastEnd; // minutes since midnight
  final int gapMinutes; // total «окна» between consecutive lessons

  const DayStats({
    required this.count,
    this.firstBegin,
    this.lastEnd,
    this.gapMinutes = 0,
  });

  bool get isEmpty => count == 0;

  /// "08:00–15:00", or '' when the times are unknown.
  String get span => (firstBegin != null && lastEnd != null)
      ? '${hhmm(firstBegin!)}–${hhmm(lastEnd!)}'
      : '';

  /// [sorted] must already be time-ordered, as `ScheduleController.eventsOn`
  /// returns it.
  factory DayStats.from(List<ScheduleEvent> sorted) {
    if (sorted.isEmpty) return const DayStats(count: 0);
    var gap = 0;
    for (var i = 1; i < sorted.length; i++) {
      final prev = minutesOfDay(sorted[i - 1].timeEnd);
      final cur = minutesOfDay(sorted[i].timeBegin);
      if (prev != null && cur != null && cur > prev) gap += cur - prev;
    }
    return DayStats(
      count: sorted.length,
      firstBegin: minutesOfDay(sorted.first.timeBegin),
      lastEnd: minutesOfDay(sorted.last.timeEnd),
      gapMinutes: gap,
    );
  }
}
