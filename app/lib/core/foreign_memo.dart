import '../models/schedule.dart';
import 'lesson_grouping.dart';

/// Rows of the monthly «служебная записка» about classes taught in a foreign
/// language. Pure logic — no Flutter — so it is unit-tested directly
/// (see test/foreign_memo_test.dart).

/// Foreign-student groups have a three-digit number (ИСТ-110, ИСТ-210, …);
/// regular groups have two (ИСТ-23, ИТС-21, ИСТм-21). The API has no other
/// signal, so the group name decides.
bool isForeignGroup(String group) => _foreignGroup.hasMatch(group.trim());
final _foreignGroup = RegExp(r'^[А-ЯЁA-Z][А-ЯЁа-яёA-Za-z]*-\d{3}$');

/// Academic hours credited for one class (пара).
const kHoursPerClass = 2;

/// Lesson type as the memo writes it: «Лекции» -> «лекция».
String memoLessonType(String? typeWorkName) {
  switch (typeWorkName) {
    case 'Лекции':
      return 'лекция';
    case 'Практические':
      return 'практическая';
    case 'Лабораторные':
      return 'лабораторная';
    default:
      return (typeWorkName ?? '').toLowerCase();
  }
}

/// One class in the memo's table.
class MemoRow {
  const MemoRow({
    required this.date,
    required this.time,
    required this.groups,
    required this.discipline,
    required this.type,
    this.hours = kHoursPerClass,
    this.manual = false,
  });

  final DateTime date; // calendar day
  final String time; // "08:00" — orders the day, part of the identity
  final List<String> groups; // foreign groups taught together
  final String discipline;
  final String type; // лекция / практическая / лабораторная
  final int hours;

  /// Added by hand (a replacement class that is not in the schedule).
  final bool manual;

  /// Stable identity, used to remember which classes were excluded.
  String get key => '${_ymd(date)} $time ${groups.join(',')} $discipline $type';

  MemoRow copyWith({String? discipline}) => MemoRow(
        date: date,
        time: time,
        groups: groups,
        discipline: discipline ?? this.discipline,
        type: type,
        hours: hours,
        manual: manual,
      );

  Map<String, dynamic> toJson() => {
        'date': _ymd(date),
        'time': time,
        'groups': groups,
        'discipline': discipline,
        'type': type,
        'hours': hours,
      };

  factory MemoRow.fromJson(Map<String, dynamic> j) {
    final d = DateTime.parse(j['date'] as String);
    return MemoRow(
      date: DateTime(d.year, d.month, d.day),
      time: j['time'] as String? ?? '',
      groups: [for (final g in (j['groups'] as List? ?? const [])) '$g'],
      discipline: j['discipline'] as String? ?? '',
      type: j['type'] as String? ?? '',
      hours: j['hours'] as int? ?? kHoursPerClass,
      manual: true,
    );
  }
}

String _ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// The memo rows for [days]: every timetable class with at least one foreign
/// group. Groups taught together in one room at one time are one class — one
/// row listing those groups, credited once.
List<MemoRow> memoRowsFrom(List<ScheduleDay> days) {
  final rows = <MemoRow>[];
  for (final day in [...days]..sort((a, b) => a.date.compareTo(b.date))) {
    final classes = [
      for (final e in day.events)
        if (_isClass(e)) e,
    ]..sort((a, b) => (a.timeBegin ?? '').compareTo(b.timeBegin ?? ''));
    for (final slot in groupParallelLessons(classes)) {
      final groups = <String>[];
      for (final e in slot.events) {
        final g = (e.fullDescription ?? '').trim();
        if (isForeignGroup(g) && !groups.contains(g)) groups.add(g);
      }
      if (groups.isEmpty) continue;
      final lead = slot.lead;
      rows.add(MemoRow(
        date: DateTime(day.date.year, day.date.month, day.date.day),
        time: _hhmm(lead.timeBegin),
        groups: groups,
        discipline: (lead.description ?? '').trim().replaceAll(_spaces, ' '),
        type: memoLessonType(lead.typeWorkName),
      ));
    }
  }
  return rows;
}

/// Calendar entries of other kinds (events, private notes) are not classes.
bool _isClass(ScheduleEvent e) {
  final c = e.category?.toLowerCase();
  return c == null || c == 'timetable';
}

final _spaces = RegExp(r'\s+');

String _hhmm(String? t) =>
    (t != null && t.length >= 5) ? t.substring(0, 5) : (t ?? '');

/// «старший преподаватель» -> «ст. преподаватель», as the memo writes it.
String shortPost(String post) {
  final p = post.trim();
  return p.toLowerCase().startsWith('старший ')
      ? 'ст. ${p.substring('старший '.length)}'
      : p;
}

/// «Кафедра …» -> «Кафедре …» for «по Кафедре …» in the memo's body.
String departmentDative(String department) {
  final d = department.trim();
  if (d.startsWith('Кафедра ')) return 'Кафедре ${d.substring(8)}';
  if (d.startsWith('кафедра ')) return 'кафедре ${d.substring(8)}';
  return d;
}
