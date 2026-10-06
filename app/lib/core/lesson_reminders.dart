import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../models/schedule.dart';
import 'ics.dart';
import 'prefs.dart';

/// A notification to show before a lesson.
class LessonReminder {
  const LessonReminder(
      {required this.id,
      required this.at,
      required this.title,
      required this.body});
  final int id;

  /// When, in UTC.
  final DateTime at;
  final String title;
  final String body;

  @override
  String toString() => '$at $title — $body';
}

/// Ids from here on are lesson reminders.
const lessonReminderIds = 10000;

/// The reminders for the lessons of [days] that start after [now] + [lead]
/// and within [horizon]: [lead] before each, a slot shared by several
/// groups once; at most [limit] (Android keeps a few hundred per app).
List<LessonReminder> plannedReminders(
  Map<DateTime, List<ScheduleEvent>> days, {
  required Duration lead,
  required DateTime now,
  Duration horizon = const Duration(days: 14),
  int limit = 60,
}) {
  final hhmm = DateFormat('HH:mm');
  final soon = now.toUtc();
  final events = lessonEvents(days)..sort((a, b) => a.start.compareTo(b.start));
  final list = <LessonReminder>[];
  for (final e in events) {
    final at = moscowToUtc(e.start).subtract(lead);
    if (!at.isAfter(soon) || at.isAfter(soon.add(horizon))) continue;
    if (list.length == limit) break;
    list.add(LessonReminder(
      id: lessonReminderIds + list.length,
      at: at,
      title: 'Через ${lead.inMinutes} мин: ${e.summary}',
      body: [
        '${hhmm.format(e.start)}–${hhmm.format(e.end)}',
        if (e.location.isNotEmpty) 'ауд. ${e.location}',
      ].join(' · '),
    ));
  }
  return list;
}

/// Where the reminders go: Android's notifications (LocalReminderPlatform in
/// notifications.dart), or a fake in tests.
abstract class ReminderPlatform {
  /// Asks to show notifications; false when refused.
  Future<bool> requestPermission();

  /// The lesson reminders become exactly [reminders].
  Future<void> replace(List<LessonReminder> reminders);
}

/// Reminders before lessons, [minutes] ahead (0: none). Plans them from the
/// weeks the schedule has loaded, and again whenever one comes or the
/// setting changes; Android keeps them through a restart.
class LessonReminders extends ChangeNotifier {
  LessonReminders(this._prefs, this._platform, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  final Prefs _prefs;
  final ReminderPlatform _platform;
  final DateTime Function() _clock;

  /// Lessons by date, as far as the schedule has shown them.
  final _days = <DateTime, List<ScheduleEvent>>{};
  Timer? _debounce;

  /// Only the Android app: a browser can't remind at a set time.
  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  int get minutes => _prefs.lessonReminderMinutes;

  /// Turns reminders on [m] minutes before (asking to show notifications
  /// first) or off (0). False when that permission was refused.
  Future<bool> setMinutes(int m) async {
    if (m > 0 && !await _platform.requestPermission()) return false;
    await _prefs.setLessonReminderMinutes(m);
    notifyListeners();
    await _plan();
    return true;
  }

  /// A week of the schedule, as it arrived.
  void addWeek(Map<DateTime, List<ScheduleEvent>> week) {
    _days.addAll(week);
    // Two weeks often come together (this one and the next).
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      unawaited(_plan());
    });
  }

  /// Plans now rather than after the pause (tests).
  @visibleForTesting
  Future<void> flush() async {
    _debounce?.cancel();
    await _plan();
  }

  Future<void> _plan() async {
    final m = minutes;
    try {
      await _platform.replace(m == 0
          ? const []
          : plannedReminders(_days, lead: Duration(minutes: m), now: _clock()));
    } on Object catch (e) {
      debugPrint('lesson reminders: $e');
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}
