import 'package:flutter/foundation.dart';
import '../core/cache.dart';
import '../data/volgatech_api.dart';
import '../models/schedule.dart';

/// Loads schedule a week at a time, caches each week to disk, and lets the UI
/// page day-by-day. On a network failure it falls back to the cached week.
class ScheduleController extends ChangeNotifier {
  ScheduleController(this._api, this._personId, this._cache);
  final VolgatechApi _api;
  final int _personId;
  final JsonCache _cache;

  DateTime selectedDay = _dateOnly(DateTime.now());
  bool loading = false;
  String? error;

  /// True when the currently shown week came from cache after a failed fetch.
  bool fromCache = false;
  DateTime? cacheSavedAt;

  final Map<String, List<ScheduleEvent>> _byDay = {}; // yyyy-MM-dd -> events
  DateTime? _loadedStart;
  DateTime? _loadedEnd;

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
  static String _key(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _weekCacheKey(DateTime monday) => 'schedule_${_personId}_${_key(monday)}';

  List<ScheduleEvent> get eventsForSelected => eventsOn(selectedDay);

  /// Sorted lessons for any day in the loaded window (empty if none / not loaded).
  List<ScheduleEvent> eventsOn(DateTime day) {
    final list = List<ScheduleEvent>.from(_byDay[_key(day)] ?? const []);
    list.sort((a, b) => (a.timeBegin ?? '').compareTo(b.timeBegin ?? ''));
    return list;
  }

  /// Monday of the selected day's week (the week loaded into `_byDay`).
  DateTime get weekStart =>
      _dateOnly(selectedDay).subtract(Duration(days: selectedDay.weekday - 1));

  /// The seven dates Mon..Sun of the current week.
  List<DateTime> get weekDays =>
      List.generate(7, (i) => weekStart.add(Duration(days: i)));

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

  /// Week number (1/2) for the selected day. Falls back to any day in the
  /// currently loaded week so the accent colour is stable even on days with no
  /// lessons — but never crosses into an adjacent week (they alternate 1/2).
  int? get weekNumberForSelected => _scanWeek(_firstWeekNumber);

  /// Week type name («Красная неделя» …) resolved the same way.
  String? get weekTypeForSelected => _scanWeek(_firstWeekType);

  T? _scanWeek<T>(T? Function(List<ScheduleEvent>?) pick) {
    final own = pick(_byDay[_key(selectedDay)]);
    if (own != null) return own;
    if (_loadedStart == null) return null;
    for (var i = 0; i < 7; i++) {
      final d = _loadedStart!.add(Duration(days: i));
      final v = pick(_byDay[_key(d)]);
      if (v != null) return v;
    }
    return null;
  }

  bool get isCached =>
      _loadedStart != null &&
      _loadedEnd != null &&
      !selectedDay.isBefore(_loadedStart!) &&
      !selectedDay.isAfter(_loadedEnd!);

  Future<void> ensureLoaded({bool force = false}) async {
    if (isCached && !force) return;
    await _loadWeekOf(selectedDay);
  }

  Future<void> goToDay(DateTime day) async {
    selectedDay = _dateOnly(day);
    notifyListeners();
    await ensureLoaded();
  }

  Future<void> nextDay() => goToDay(selectedDay.add(const Duration(days: 1)));
  Future<void> prevDay() =>
      goToDay(selectedDay.subtract(const Duration(days: 1)));

  Future<void> refresh() => _loadWeekOf(selectedDay);

  Future<void> _loadWeekOf(DateTime day) async {
    final monday = _dateOnly(day).subtract(Duration(days: (day.weekday - 1)));
    final sunday = monday.add(const Duration(days: 6));
    loading = true;
    error = null;
    notifyListeners();
    try {
      final days = await _api.getSchedule(_personId, monday, sunday);
      for (final d in days) {
        _byDay[_key(d.date)] = d.events;
      }
      _loadedStart = monday;
      _loadedEnd = sunday;
      fromCache = false;
      cacheSavedAt = null;
      // Persist for offline use.
      await _cache.put(
          _weekCacheKey(monday), days.map((d) => d.toJson()).toList());
    } catch (e) {
      // Network failed — try the cached week before surfacing an error.
      final cached = await _cache.get(_weekCacheKey(monday));
      if (cached != null && cached.data is List) {
        for (final e in (cached.data as List)) {
          final d = ScheduleDay.fromJson(Map<String, dynamic>.from(e));
          _byDay[_key(d.date)] = d.events;
        }
        _loadedStart = monday;
        _loadedEnd = sunday;
        fromCache = true;
        cacheSavedAt = cached.savedAt;
        error = null;
      } else {
        error = e.toString();
      }
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}
