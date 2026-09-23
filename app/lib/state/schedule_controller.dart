import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/cache.dart';
import '../data/volgatech_api.dart';
import '../models/schedule.dart';

/// Loads schedule a week at a time and lets the UI page day-by-day.
///
/// Each week is shown from the on-disk copy first (instant, works offline) and
/// then refreshed from the network. Weeks are tracked independently — loaded,
/// in flight, failed — so paging back to a week already seen costs nothing,
/// and a slow response for one week can never overwrite the state of another.
class ScheduleController extends ChangeNotifier {
  ScheduleController(this._api, this._personId, this._cache);
  final VolgatechApi _api;
  final int _personId;
  final JsonCache _cache;

  DateTime selectedDay = _dateOnly(DateTime.now());

  final Map<String, List<ScheduleEvent>> _byDay = {}; // yyyy-MM-dd -> sorted events

  // Per-week state, keyed by the Monday's yyyy-MM-dd.
  final Set<String> _fresh = {}; // fetched from the network this session
  final Map<String, DateTime> _onDisk = {}; // shown from disk -> when it was saved
  final Map<String, DateTime> _stale = {}; // network failed, disk copy shown
  final Map<String, String> _errors = {}; // network failed, nothing to show
  final Map<String, Future<void>> _inFlight = {};

  bool _disposed = false;

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
  static DateTime _mondayOf(DateTime d) =>
      DateTime(d.year, d.month, d.day - (d.weekday - 1));
  static String _key(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _weekCacheKey(DateTime monday) => 'schedule_${_personId}_${_key(monday)}';

  /// Monday of the selected day's week.
  DateTime get weekStart => _mondayOf(selectedDay);
  String get _week => _key(weekStart);

  /// The seven dates Mon..Sun of the current week.
  List<DateTime> get weekDays {
    final m = weekStart;
    return List.generate(7, (i) => DateTime(m.year, m.month, m.day + i));
  }

  /// True while the selected week is being fetched.
  bool get loading => _inFlight.containsKey(_week);

  /// Why the selected week could not be loaded (only when nothing is cached).
  String? get error => _errors[_week];

  /// True when the selected week came from disk after a failed fetch.
  bool get fromCache => _stale.containsKey(_week);
  DateTime? get cacheSavedAt => _stale[_week];

  List<ScheduleEvent> get eventsForSelected => eventsOn(selectedDay);

  /// Time-ordered lessons for [day] (empty if none / not loaded).
  List<ScheduleEvent> eventsOn(DateTime day) => _byDay[_key(day)] ?? const [];

  static int? _firstWeekNumber(List<ScheduleEvent>? events) {
    if (events == null) return null;
    for (final e in events) {
      if (e.weekNumber != null) return e.weekNumber;
    }
    return null;
  }

  static String? _firstWeekType(List<ScheduleEvent>? events) {
    if (events == null) return null;
    for (final e in events) {
      if ((e.weekTypeName ?? '').isNotEmpty) return e.weekTypeName;
    }
    return null;
  }

  /// Week number (1/2) for the selected day. Falls back to any day of the
  /// selected week so the accent colour is stable even on days with no
  /// lessons — but never crosses into an adjacent week (they alternate 1/2).
  int? get weekNumberForSelected => _scanWeek(_firstWeekNumber);

  /// Week type name («Красная неделя» …) resolved the same way.
  String? get weekTypeForSelected => _scanWeek(_firstWeekType);

  T? _scanWeek<T>(T? Function(List<ScheduleEvent>?) pick) {
    final own = pick(_byDay[_key(selectedDay)]);
    if (own != null) return own;
    for (final d in weekDays) {
      final v = pick(_byDay[_key(d)]);
      if (v != null) return v;
    }
    return null;
  }

  /// The selected week has data (fresh, or from disk after a failed fetch).
  bool get isCached => _isLoaded(_week);
  bool _isLoaded(String week) => _fresh.contains(week) || _stale.containsKey(week);

  Future<void> ensureLoaded({bool force = false}) async {
    if (isCached && !force) return;
    await _loadWeek(weekStart);
  }

  Future<void> goToDay(DateTime day) async {
    selectedDay = _dateOnly(day);
    _notify();
    await ensureLoaded();
  }

  Future<void> nextDay() => goToDay(
      DateTime(selectedDay.year, selectedDay.month, selectedDay.day + 1));
  Future<void> prevDay() => goToDay(
      DateTime(selectedDay.year, selectedDay.month, selectedDay.day - 1));

  /// Jump a whole week (used by the «Обзор недели» swipe). Lands on the new
  /// week's Monday so the overview shows Пн–Вс of that week.
  Future<void> nextWeek() {
    final m = weekStart;
    return goToDay(DateTime(m.year, m.month, m.day + 7));
  }

  Future<void> prevWeek() {
    final m = weekStart;
    return goToDay(DateTime(m.year, m.month, m.day - 7));
  }

  Future<void> refresh() => _loadWeek(weekStart);

  /// One fetch per week at a time; a second caller shares the running one.
  /// [prefetchNext] is false for the background fetch itself, so it stops at
  /// one week ahead instead of walking the whole calendar.
  Future<void> _loadWeek(DateTime monday, {bool prefetchNext = true}) {
    final week = _key(monday);
    final running = _inFlight[week];
    if (running != null) return running;
    final f = _fetchWeek(monday, prefetchNext).whenComplete(() {
      // Drops the finished entry; the value is this very future.
      // ignore: discarded_futures
      _inFlight.remove(week);
      _notify();
    });
    _inFlight[week] = f;
    _notify();
    return f;
  }

  Future<void> _fetchWeek(DateTime monday, bool prefetchNext) async {
    final week = _key(monday);
    final cacheKey = _weekCacheKey(monday);
    _errors.remove(week);

    // Show the saved copy straight away while the network catches up.
    if (!_isLoaded(week) && !_onDisk.containsKey(week)) {
      final cached = await _cache.get(cacheKey);
      if (cached != null && cached.data is List) {
        _storeWeek(monday, _daysFromJson(cached.data as List));
        _onDisk[week] = cached.savedAt;
        _notify();
      }
    }

    final List<ScheduleDay> days;
    try {
      days = await _api.getSchedule(_personId, monday, _plusDays(monday, 6));
    } catch (e) {
      final savedAt = _onDisk[week];
      if (savedAt != null) {
        _stale[week] = savedAt;
      } else if (!_fresh.contains(week)) {
        _errors[week] = e.toString();
      }
      return;
    }

    _storeWeek(monday, days);
    _fresh.add(week);
    _stale.remove(week);
    _onDisk[week] = DateTime.now();
    await _cache.put(cacheKey, days.map((d) => d.toJson()).toList());

    // The next week is usually looked at soon; fetch it in the background.
    final next = _plusDays(monday, 7);
    if (prefetchNext && !_isLoaded(_key(next))) {
      unawaited(_loadWeek(next, prefetchNext: false));
    }
  }

  static DateTime _plusDays(DateTime d, int n) =>
      DateTime(d.year, d.month, d.day + n);

  static List<ScheduleDay> _daysFromJson(List<dynamic> list) => [
        for (final e in list)
          ScheduleDay.fromJson(Map<String, dynamic>.from(e as Map)),
      ];

  /// Replaces the whole week, so a lesson that disappeared from a newer
  /// response does not linger from the older copy.
  void _storeWeek(DateTime monday, List<ScheduleDay> days) {
    for (var i = 0; i < 7; i++) {
      _byDay.remove(_key(_plusDays(monday, i)));
    }
    for (final d in days) {
      final sorted = [...d.events]
        ..sort((a, b) => (a.timeBegin ?? '').compareTo(b.timeBegin ?? ''));
      _byDay[_key(d.date)] = List.unmodifiable(sorted);
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
