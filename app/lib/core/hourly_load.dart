import '../models/schedule.dart';
import 'foreign_memo.dart' show kHoursPerClass;
import 'lesson_grouping.dart';

/// «Почасовая нагрузка»: the classes of the disciplines a teacher picks, for
/// «Приложение к форме 28 — Отчет по видам выполненных работ». Pure logic —
/// no Flutter — so it is unit-tested directly (test/hourly_load_test.dart).

/// Lesson type as the report writes it: «Лекции» -> «Лекция».
String hourlyLessonType(String? typeWorkName) {
  final t = (typeWorkName ?? '').trim();
  return switch (t) {
    'Лекции' => 'Лекция',
    'Практические' => 'Практика',
    'Лабораторные' => 'Лабораторная',
    '' => '',
    _ => t[0].toUpperCase() + t.substring(1),
  };
}

/// First day of the semester [day] falls in: spring runs February–August,
/// autumn September–January.
DateTime semesterStart(DateTime day) => switch (day.month) {
      >= 2 && <= 8 => DateTime(day.year, 2),
      1 => DateTime(day.year - 1, 9),
      _ => DateTime(day.year, 9),
    };

/// The semester's months, first to last.
List<DateTime> semesterMonths(DateTime day) {
  final s = semesterStart(day);
  final n = s.month == 2 ? 7 : 5;
  return [for (var i = 0; i < n; i++) DateTime(s.year, s.month + i)];
}

/// «Весенний семестр 2026», «Осенний семестр 2026/27».
String semesterLabel(DateTime day) {
  final s = semesterStart(day);
  return s.month == 2
      ? 'Весенний семестр ${s.year}'
      : 'Осенний семестр ${s.year}/${(s.year + 1) % 100}';
}

/// A group without its subgroup: «ИСТ-23 (подгруппа 1)» -> «ИСТ-23».
String baseGroup(String label) => label.replaceFirst(_subgroup, '').trim();
final _subgroup = RegExp(r'\s*\(.*\)\s*$');

/// One class (пара) from the schedule.
class HourlyClass {
  const HourlyClass({
    required this.date,
    required this.time,
    required this.groups,
    required this.discipline,
    required this.type,
    this.hours = kHoursPerClass,
  });

  final DateTime date; // calendar day
  final String time; // "08:00"
  final List<String> groups; // taught together, subgroups included
  final String discipline;
  final String type; // Лекция / Практика / Лабораторная
  final int hours;

  /// Stable identity: what exclusions and topic edits are remembered by.
  String get key => '${_ymd(date)} $time ${groups.join(',')} $discipline $type';

  /// Which plan its topic comes from: the discipline and the lesson type.
  String get planKey => '$discipline|$type';

  /// Which run through that plan it is part of: each group (or groups taught
  /// together) goes through the topics on its own.
  String get track => '$planKey|${groups.join(',')}';
}

/// Every timetable class in [days], in date and time order. Groups taught
/// together in one room at one time are one class, credited once.
List<HourlyClass> hourlyClassesFrom(List<ScheduleDay> days) {
  final out = <HourlyClass>[];
  for (final day in [...days]..sort((a, b) => a.date.compareTo(b.date))) {
    final classes = [
      for (final e in day.events)
        if (_isClass(e)) e,
    ]..sort((a, b) => (a.timeBegin ?? '').compareTo(b.timeBegin ?? ''));
    for (final slot in groupParallelLessons(classes)) {
      final lead = slot.lead;
      final discipline =
          (lead.description ?? '').trim().replaceAll(_spaces, ' ');
      if (discipline.isEmpty || slot.groups.isEmpty) continue;
      out.add(HourlyClass(
        date: DateTime(day.date.year, day.date.month, day.date.day),
        time: _hhmm(lead.timeBegin),
        groups: slot.groups,
        discipline: discipline,
        type: hourlyLessonType(lead.typeWorkName),
      ));
    }
  }
  return out;
}

/// A discipline in the semester's schedule, as offered for the report.
class HourlyCourse {
  HourlyCourse(this.discipline);

  final String discipline;

  /// Group -> lesson type -> how many classes in the semester.
  final Map<String, Map<String, int>> groups = {};

  /// Lesson type -> how many classes, one taught to groups together once.
  final Map<String, int> classes = {};

  /// Lesson types taught, in the order first seen.
  List<String> get types => classes.keys.toList();

  /// «практики 16 · лекции 8», for the course or one of its groups.
  String typeSummary([String? group]) => [
        for (final MapEntry(:key, :value)
            in (group == null ? classes : groups[group] ?? const {}).entries)
          '${_typePlural(key)} $value',
      ].join(' · ');
}

/// The semester's disciplines in [classes], by name.
List<HourlyCourse> coursesFrom(Iterable<HourlyClass> classes) {
  final byName = <String, HourlyCourse>{};
  for (final c in classes) {
    final course =
        byName.putIfAbsent(c.discipline, () => HourlyCourse(c.discipline));
    course.classes[c.type] = (course.classes[c.type] ?? 0) + 1;
    for (final g in {for (final l in c.groups) baseGroup(l)}) {
      final types = course.groups.putIfAbsent(g, () => {});
      types[c.type] = (types[c.type] ?? 0) + 1;
    }
  }
  return byName.values.toList()
    ..sort((a, b) => a.discipline.compareTo(b.discipline));
}

/// What the picked set remembers: one discipline for one group.
String pickKey(String discipline, String group) => '$discipline\u0001$group';

/// [c]'s groups that go in the report, as printed; none if it doesn't.
List<String> pickedGroups(HourlyClass c, Set<String> picked) => [
      for (final l in c.groups)
        if (picked.contains(pickKey(c.discipline, baseGroup(l)))) l,
    ];

/// One topic of a discipline's plan, held for [count] classes in a row.
class PlanTopic {
  const PlanTopic(this.title, [this.count = 1]);

  final String title;
  final int count;

  PlanTopic copyWith({String? title, int? count}) =>
      PlanTopic(title ?? this.title, count ?? this.count);

  Map<String, dynamic> toJson() => {'t': title, 'n': count};

  factory PlanTopic.fromJson(Map<String, dynamic> j) =>
      PlanTopic(j['t'] as String? ?? '', (j['n'] as int?) ?? 1);

  @override
  bool operator ==(Object other) =>
      other is PlanTopic && other.title == title && other.count == count;

  @override
  int get hashCode => Object.hash(title, count);

  @override
  String toString() => '$title ×$count';
}

/// The topic of the [index]th class (from 0) through [plan]; null past its
/// end.
({String title, int item})? topicAt(List<PlanTopic> plan, int index) {
  var left = index;
  for (var i = 0; i < plan.length; i++) {
    if (left < plan[i].count) return (title: plan[i].title, item: i);
    left -= plan[i].count;
  }
  return null;
}

/// How many classes [plan] covers.
int planLength(List<PlanTopic> plan) => plan.fold(0, (s, t) => s + t.count);

/// Topics pasted from a work programme: one per line, numbering and bullets
/// dropped; «×4», «x4», «*4» or «(4)» at the end for four classes in a row.
List<PlanTopic> parsePlan(String text) => [
      for (final raw in text.split(RegExp(r'\r?\n')))
        if (_planLine(raw) case final t?) t,
    ];

PlanTopic? _planLine(String raw) {
  var line = raw.trim().replaceFirst(_bullet, '').trim();
  var count = 1;
  final m = _count.firstMatch(line);
  if (m != null) {
    count = int.parse(m[1] ?? m[2]!).clamp(1, 99);
    line = line.substring(0, m.start).trim();
  }
  line = line.replaceAll(_spaces, ' ');
  return line.isEmpty ? null : PlanTopic(line, count);
}

final _bullet = RegExp(r'^(?:\d{1,3}[.)]\s*|[-–—•·*]\s+)');
final _count = RegExp(r'\s*(?:[×xхX*]\s*(\d{1,2})|\((\d{1,2})\))\s*$');

/// A row of the report: a class that goes in, with its topic.
class HourlyRow {
  const HourlyRow({
    required this.date,
    required this.hours,
    required this.groups,
    required this.type,
    required this.discipline,
    this.topic = '',
  });

  final DateTime date;
  final int hours;
  final List<String> groups;
  final String type;
  final String discipline;
  final String topic;
}

/// The report's part of a file name: «02-03.26» for February and March,
/// «02.26» for one month, «02,04.26» for months apart.
String periodTag(List<DateTime> months) {
  final ms = [...months]..sort();
  if (ms.isEmpty) return '';
  String mm(DateTime d) => d.month.toString().padLeft(2, '0');
  String yy(DateTime d) => (d.year % 100).toString().padLeft(2, '0');
  final contiguous = monthsInARow(ms);
  final oneYear = ms.every((d) => d.year == ms.first.year);
  if (ms.length == 1) return '${mm(ms.first)}.${yy(ms.first)}';
  if (oneYear) {
    return contiguous
        ? '${mm(ms.first)}-${mm(ms.last)}.${yy(ms.first)}'
        : '${ms.map(mm).join(',')}.${yy(ms.first)}';
  }
  final tags = ms.map((d) => '${mm(d)}.${yy(d)}');
  return contiguous ? '${tags.first}-${tags.last}' : tags.join(',');
}

/// Whether [months] (in order) follow one another with none skipped.
bool monthsInARow(List<DateTime> months) {
  for (var i = 1; i < months.length; i++) {
    final a = months[i - 1], b = months[i];
    if (DateTime(a.year, a.month + 1) != DateTime(b.year, b.month)) {
      return false;
    }
  }
  return true;
}

String _typePlural(String type) => switch (type) {
      'Лекция' => 'лекции',
      'Практика' => 'практики',
      'Лабораторная' => 'лабораторные',
      _ => type.toLowerCase(),
    };

/// Calendar entries of other kinds (events, private notes) are not classes.
bool _isClass(ScheduleEvent e) {
  final c = e.category?.toLowerCase();
  return c == null || c == 'timetable';
}

final _spaces = RegExp(r'\s+');

String _hhmm(String? t) =>
    (t != null && t.length >= 5) ? t.substring(0, 5) : (t ?? '');

String _ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
