import '../models/schedule.dart';
import 'portal_workload.dart' show workloadName;

typedef _Slot = (int, String, String, String);
typedef _Dates = ({String from, String to});
typedef _Lesson = ({String form, List<_Dates> dates});

final _subgroupSuffix = RegExp(r'\s+\d+\s*п\s*/\s*г$', caseSensitive: false);
final _beginTime = RegExp(r'^(\d{1,2}:\d{2})(?::\d{2})?$');

String _discipline(String value) =>
    workloadName(value).replaceFirst(_subgroupSuffix, '');

/// Finds the study form of an API lesson from the portal's semester timetable.
class PortalTimetable {
  PortalTimetable([List<Object?> rows = const []]) {
    for (final row in rows) {
      if (row
          case {
            'weekday': final int weekday,
            'begin': final String begin,
            'discipline': final String discipline,
            'group': final String group,
            'form': final String form,
            'dates': final List<Object?> dates,
          } when form == 'о' || form == 'оз' || form == 'з') {
        final slot = (weekday, begin, _discipline(discipline), group);
        final lesson = (form: form, dates: dates.map(_readDates).toList());
        _lessons.putIfAbsent(slot, () => []).add(lesson);
        _forms.putIfAbsent(group, () => {}).add(form);
      } else {
        throw const FormatException('Invalid portal timetable row');
      }
    }
  }

  final _lessons = <_Slot, List<_Lesson>>{};
  final _forms = <String, Set<String>>{};

  String? formFor(ScheduleEvent event) {
    final group = event.fullDescription?.trim() ?? '';
    final date = event.date;
    final begin = _beginTime.firstMatch(event.timeBegin ?? '')?[1];
    if (date != null && begin != null) {
      final slot = (
        date.weekday,
        begin.padLeft(5, '0'),
        _discipline(event.description ?? ''),
        group,
      );
      final candidates = _lessons[slot] ?? const <_Lesson>[];
      final forms = {for (final row in candidates) row.form};
      if (forms.length == 1) return forms.single;
      if (forms.length > 1) {
        final day = date.toIso8601String().split('T').first;
        final covering = {
          for (final row in candidates)
            if (row.dates.isEmpty ||
                row.dates.any((range) => _covers(range, day)))
              row.form,
        };
        if (covering.length == 1) return covering.single;
      }
    }
    final forms = _forms[group];
    return forms?.length == 1 ? forms!.single : null;
  }

  static _Dates _readDates(Object? value) {
    if (value case {'from': final String from, 'to': final String to}) {
      return (from: from, to: to);
    }
    throw const FormatException('Invalid portal timetable date');
  }

  static bool _covers(_Dates range, String day) =>
      range.from.length == 5 && range.from == range.to
          ? day.endsWith('-${range.from}')
          : range.from.compareTo(day) <= 0 && range.to.compareTo(day) >= 0;
}
