import 'hourly_load.dart';

/// A monthly timetable total for groups taught together, counted once per slot.
class WorkloadTotal {
  WorkloadTotal(this.discipline, this.column, this.groups);

  final String discipline;
  final String column;
  final List<String> groups;
  final List<DateTime> dates = [];
  int hours = 0;
}

List<WorkloadTotal> monthlyWorkload(
    Iterable<HourlyClass> classes, DateTime month, DateTime today) {
  final cutoff = DateTime(today.year, today.month, today.day);
  final totals = <(String, String, String), WorkloadTotal>{};
  for (final lesson in classes) {
    if (lesson.date.year != month.year ||
        lesson.date.month != month.month ||
        !lesson.date.isBefore(cutoff)) {
      continue;
    }
    final column = switch (lesson.type) {
      'Лекция' => 'HoursAuditLec',
      'Лабораторная' => 'HoursAuditLab',
      'Практика' => 'HoursAuditPract',
      _ => null,
    };
    if (column == null) continue;
    final groups = [...lesson.groups]..sort();
    final key =
        (workloadName(lesson.discipline), column, groups.join('\u0001'));
    final total = totals.putIfAbsent(
        key, () => WorkloadTotal(lesson.discipline, column, groups));
    total.hours += lesson.hours;
    total.dates.add(lesson.date);
  }
  return totals.values.toList();
}

String workloadName(String value) =>
    value.trim().toLowerCase().replaceAll('ё', 'е').replaceAll(_spaces, ' ');

final _spaces = RegExp(r'\s+');

DateTime? portalWorkloadMonth(String label) {
  const months = [
    'январь',
    'февраль',
    'март',
    'апрель',
    'май',
    'июнь',
    'июль',
    'август',
    'сентябрь',
    'октябрь',
    'ноябрь',
    'декабрь',
  ];
  final parts = workloadName(label).split(' ');
  if (parts.length != 2) return null;
  final month = months.indexOf(parts.first) + 1;
  final year = int.tryParse(parts.last);
  return month == 0 || year == null || year < 2000 || year > 2100
      ? null
      : DateTime(year, month);
}

class PortalWorkloadCell {
  PortalWorkloadCell.fromJson(Map<String, dynamic> json)
      : key = json['key'] as String,
        rowKey = json['rowKey'] as String,
        column = json['column'] as String,
        discipline = json['discipline'] as String,
        specialty = json['specialty'] as String,
        appointment = json['appointment'] as String,
        semester = json['semester'] as String,
        amount = json['amount'] as int;

  final String key;
  final String rowKey;
  final String column;
  final String discipline;
  final String specialty;
  final String appointment;
  final String semester;
  final int amount;

  bool get available => amount == 0;
}

const workloadColumnLabels = {
  'HoursAuditLec': 'Лекции',
  'HoursAuditLab': 'Лабораторные',
  'HoursAuditPract': 'Практические',
  'HoursExam': 'Экзамен',
  'HoursTest': 'Зачёт (БРК)',
  'HoursConsultExam': 'Консультации перед экзаменом',
  'HoursStudyPract': 'Учебная практика',
};

const workloadSemesterLabels = ['1 семестр', '2 семестр'];

String workloadSemesterForMonth(DateTime month) =>
    workloadSemesterLabels[semesterStart(month).month == 9 ? 0 : 1];

String formatWorkloadHours(int amount) {
  final whole = amount ~/ 100;
  final fraction = (amount % 100).toString().padLeft(2, '0');
  return fraction == '00' ? '$whole' : '$whole,$fraction';
}

int? parseWorkloadHours(String text) {
  if (text.isEmpty) return 0;
  final match = RegExp(r'^(\d+)(?:[,.](\d{1,2}))?$').firstMatch(text);
  if (match == null) return null;
  final whole = int.tryParse(match[1]!);
  if (whole == null || whole > 90071992547409) return null;
  final amount = whole * 100 + int.parse((match[2] ?? '').padRight(2, '0'));
  return amount <= 9007199254740991 ? amount : null;
}

typedef WorkloadTargetOptions = ({
  List<PortalWorkloadCell> choices,
  String? suggested,
  bool sameDiscipline,
});

/// The grid groups rows by appointment, semester, discipline and specialty.
/// A timetable group label alone does not identify a specialty or appointment.
WorkloadTargetOptions workloadTargets(
    WorkloadTotal total, List<PortalWorkloadCell> cells, DateTime month,
    {Set<String> occupied = const {}}) {
  final semester = workloadSemesterForMonth(month);
  final eligible = cells
      .where((cell) => cell.column == total.column && cell.semester == semester)
      .toList();
  final matching = eligible
      .where((cell) =>
          workloadName(cell.discipline) == workloadName(total.discipline))
      .toList();
  return (
    choices: matching.isEmpty ? eligible : matching,
    sameDiscipline: matching.isNotEmpty,
    suggested: matching.length == 1 &&
            matching.single.available &&
            !occupied.contains(matching.single.key)
        ? matching.single.key
        : null,
  );
}

/// Timetable totals split by whether the department's form lists their
/// discipline; the hidden ones are taught for other departments.
({List<WorkloadTotal> shown, List<WorkloadTotal> hidden}) departmentWorkload(
    List<WorkloadTotal> totals, Iterable<PortalWorkloadCell> cells) {
  final names = {for (final cell in cells) workloadName(cell.discipline)};
  bool listed(WorkloadTotal total) =>
      names.contains(workloadName(total.discipline));
  return (
    shown: totals.where(listed).toList(),
    hidden: totals.where((total) => !listed(total)).toList(),
  );
}

/// One field as the save confirmation lists it.
String workloadChange(PortalWorkloadCell cell, int amount) =>
    '${cell.discipline} · ${workloadColumnLabels[cell.column]}: '
    '${formatWorkloadHours(cell.amount)} → ${formatWorkloadHours(amount)} ч.';

/// The month a form opens on: the previous one during the first week, when
/// it is usually still being filled, otherwise the current one.
DateTime workloadMonth(DateTime today) =>
    DateTime(today.year, today.month - (today.day <= 7 ? 1 : 0));
