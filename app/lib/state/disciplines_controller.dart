import 'package:flutter/foundation.dart';

import '../core/hourly_load.dart';
import '../data/volgatech_api.dart';

/// «Дисциплины»: every discipline in a semester's schedule, to look over and
/// copy.
class DisciplinesController extends ChangeNotifier {
  DisciplinesController(this._api, this._personId, {DateTime? today})
      : semester = semesterStart(today ?? DateTime.now());

  final VolgatechApi _api;
  final int _personId;

  /// The first month of the semester shown.
  DateTime semester;
  bool loading = false;
  String? error;

  final Map<DateTime, List<HourlyCourse>> _bySemester = {};
  int _request = 0;
  bool _disposed = false;

  /// «Осенний семестр 2026/27».
  String get label => semesterLabel(semester);

  /// The semester's disciplines, by name; empty until loaded.
  List<HourlyCourse> get courses => _bySemester[semester] ?? const [];

  bool get loaded => _bySemester.containsKey(semester);

  /// The names, one per line.
  String get namesText => courses.map((c) => c.discipline).join('\n');

  Future<void> load({bool force = false}) async {
    final s = semester;
    if (!force && _bySemester.containsKey(s)) return;
    final req = ++_request;
    loading = true;
    error = null;
    _notify();
    try {
      final months = semesterMonths(s);
      final got = await Future.wait([
        for (final m in months)
          _api.getSchedule(_personId, m, DateTime(m.year, m.month + 1, 0)),
      ]);
      if (req != _request) return;
      _bySemester[s] =
          coursesFrom([for (final days in got) ...hourlyClassesFrom(days)]);
    } catch (e) {
      if (req != _request) return;
      error = e.toString();
    } finally {
      if (req == _request) {
        loading = false;
        _notify();
      }
    }
  }

  /// The semester after (1) or before (-1) the one shown.
  Future<void> shift(int by) async {
    var s = semester;
    for (var i = 0; i < by.abs(); i++) {
      final last = semesterMonths(s).last;
      s = by > 0
          ? semesterStart(DateTime(last.year, last.month + 1))
          : semesterStart(DateTime(s.year, s.month - 1));
    }
    semester = s;
    error = null;
    _notify();
    await load();
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
