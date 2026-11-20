import 'package:flutter/foundation.dart';

import '../core/portal_timetable.dart';
import '../core/prefs.dart';

/// Persists the last successful portal timetable for each app profile and
/// lets the schedule update when a background refresh finishes.
class PortalTimetableStore extends ChangeNotifier {
  PortalTimetableStore(this._prefs);

  final Prefs _prefs;
  final _refreshes = <int, Object>{};

  String _key(int personId) => 'portal_timetable_$personId';

  PortalTimetable read(int? personId) {
    if (personId == null) return PortalTimetable();
    if (_prefs.readJson(_key(personId))
        case {'rows': final List<Object?> rows}) {
      try {
        return PortalTimetable(rows);
      } on FormatException {
        return PortalTimetable();
      }
    }
    return PortalTimetable();
  }

  Future<void> refresh(
      int personId, Future<List<Object?>> Function() fetch) async {
    final request = _refreshes[personId] = Object();
    try {
      final rows = await fetch();
      if (_refreshes[personId] != request) return;
      PortalTimetable(rows);
      await _prefs.writeJson(_key(personId), {
        'fetchedAt': DateTime.now().toUtc().toIso8601String(),
        'rows': rows,
      });
      notifyListeners();
    } catch (_) {
      return;
    } finally {
      if (_refreshes[personId] == request) _refreshes.remove(personId);
    }
  }
}
