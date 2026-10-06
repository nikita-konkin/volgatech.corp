import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../models/schedule.dart';
import 'ics.dart';

/// What the home-screen widget gets: the lessons that haven't ended by
/// [now], within [horizon], and [until] when the loaded weeks end (after it
/// the widget asks to open the app rather than say there are no lessons).
Map<String, Object> widgetData(
  Map<DateTime, List<ScheduleEvent>> days, {
  required DateTime now,
  Duration horizon = const Duration(days: 14),
  int limit = 40,
}) {
  final hhmm = DateFormat('HH:mm');
  final ymd = DateFormat('yyyy-MM-dd');
  final dayLabel = DateFormat('EE, d MMMM', 'ru_RU');
  final soon = now.toUtc();
  final events = lessonEvents(days)..sort((a, b) => a.start.compareTo(b.start));
  final lessons = <Map<String, Object>>[];
  for (final e in events) {
    final start = moscowToUtc(e.start);
    final end = moscowToUtc(e.end);
    if (!end.isAfter(soon) || start.isAfter(soon.add(horizon))) continue;
    if (lessons.length == limit) break;
    final label = dayLabel.format(e.start);
    lessons.add({
      'start': start.millisecondsSinceEpoch,
      'end': end.millisecondsSinceEpoch,
      'day': ymd.format(e.start),
      'dayLabel': label[0].toUpperCase() + label.substring(1),
      'from': hhmm.format(e.start),
      'to': hhmm.format(e.end),
      'title': e.summary,
      'room': e.location.isEmpty ? '' : 'ауд. ${e.location}',
    });
  }
  final last = days.keys
      .fold<DateTime?>(null, (a, b) => a == null || b.isAfter(a) ? b : a);
  return {
    if (last != null)
      'until': moscowToUtc(DateTime(last.year, last.month, last.day + 1))
          .millisecondsSinceEpoch,
    'lessons': lessons,
  };
}

/// Feeds the home-screen widget (LessonWidget.kt) the weeks the schedule
/// has loaded; it picks the lesson on now or next by itself.
class LessonWidget {
  LessonWidget({MethodChannel? channel, DateTime Function()? clock})
      : _channel = channel ?? const MethodChannel('volgatech/lesson_widget'),
        _clock = clock ?? DateTime.now;

  final MethodChannel _channel;
  final DateTime Function() _clock;
  final _days = <DateTime, List<ScheduleEvent>>{};
  Timer? _debounce;

  /// Only the Android app has one.
  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// A week of the schedule, as it arrived.
  void addWeek(Map<DateTime, List<ScheduleEvent>> week) {
    _days.addAll(week);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      unawaited(_push());
    });
  }

  /// Signed out: the widget no longer shows anyone's lessons.
  Future<void> forget() {
    _debounce?.cancel();
    _days.clear();
    return _push();
  }

  /// Sends now rather than after the pause (tests).
  @visibleForTesting
  Future<void> flush() {
    _debounce?.cancel();
    return _push();
  }

  Future<void> _push() async {
    try {
      await _channel.invokeMethod<void>(
          'update', jsonEncode(widgetData(_days, now: _clock())));
    } on Object catch (e) {
      debugPrint('lesson widget: $e');
    }
  }
}
