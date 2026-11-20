import 'hourly_load.dart';
import 'portal_workload.dart';

/// An eligible month and its original portal filter label and value.
typedef WorkloadBatchOption = ({DateTime month, String label, String value});

/// The offered months of the selected semester with at least one past day.
List<WorkloadBatchOption> workloadBatchMonths(
  DateTime selected,
  DateTime today,
  Iterable<({String label, String value})> options,
) {
  final cutoff = DateTime(today.year, today.month, today.day);
  final offered = <DateTime, WorkloadBatchOption>{};
  for (final option in options) {
    final month = portalWorkloadMonth(option.label);
    if (month == null || !month.isBefore(cutoff)) continue;
    offered.putIfAbsent(
      month,
      () => (month: month, label: option.label, value: option.value),
    );
  }
  return [
    for (final month in semesterMonths(selected))
      if (offered[month] case final option?) option,
  ];
}

/// Timetable lines with the same discipline, lesson type and groups share a choice.
typedef WorkloadLineIdentity = (String, String, String);

/// Identifies the same timetable line across months, regardless of group order.
WorkloadLineIdentity workloadLineIdentity(WorkloadTotal total) => (
      workloadName(total.discipline),
      total.column,
      ([...total.groups]..sort()).join('\u0001'),
    );

/// The portal field attributes that identify a cell across monthly forms.
typedef WorkloadCellIdentity = ({
  String appointment,
  String semester,
  String discipline,
  String specialty,
  String column,
});

/// Matches a portal field without relying on its month-specific row ID.
WorkloadCellIdentity workloadCellIdentity(PortalWorkloadCell cell) => (
      appointment: cell.appointment,
      semester: cell.semester,
      discipline: cell.discipline,
      specialty: cell.specialty,
      column: cell.column,
    );

/// One month's timetable lines and the portal fields they can fill.
class WorkloadBatchMonth {
  WorkloadBatchMonth(
    this.option,
    List<WorkloadTotal> totals,
    List<PortalWorkloadCell> cells, {
    Set<String> occupied = const {},
  })  : _cells = cells
            .where((cell) =>
                cell.semester == workloadSemesterForMonth(option.month))
            .toList(),
        _occupied = occupied {
    final split = departmentWorkload(totals, _cells);
    lines = split.shown;
    hidden = split.hidden;
    final byIdentity = <WorkloadCellIdentity, List<PortalWorkloadCell>>{};
    for (final cell in _cells) {
      byIdentity.putIfAbsent(workloadCellIdentity(cell), () => []).add(cell);
    }
    _available = {
      for (final entry in byIdentity.entries)
        if (entry.value.length == 1 &&
            entry.value.single.available &&
            !occupied.contains(entry.value.single.key))
          entry.key: entry.value.single,
    };
  }

  final WorkloadBatchOption option;
  final List<PortalWorkloadCell> _cells;
  final Set<String> _occupied;
  late final Map<WorkloadCellIdentity, PortalWorkloadCell> _available;
  late final List<WorkloadTotal> lines;
  late final List<WorkloadTotal> hidden;

  WorkloadTargetOptions _options(WorkloadTotal line) =>
      workloadTargets(line, _cells, option.month, occupied: _occupied);

  /// The unique, free cell matching a shared choice in this month.
  PortalWorkloadCell? availableCell(WorkloadCellIdentity choice) =>
      _available[choice];

  /// Applies shared choices to this month's fields and combines hours by field.
  WorkloadMonthChanges changes(
      Map<WorkloadLineIdentity, WorkloadCellIdentity?> choices) {
    final fields = <PortalWorkloadCell, int>{};
    for (final line in lines) {
      final cell = _available[choices[workloadLineIdentity(line)]];
      if (cell == null) continue;
      fields.update(cell, (amount) => amount + line.hours * 100,
          ifAbsent: () => line.hours * 100);
    }
    return WorkloadMonthChanges._(option, fields);
  }
}

/// The portal row choices shared by every occurrence of one timetable line.
class WorkloadBatchLine {
  final _choices = <WorkloadCellIdentity>{};
  final _matching = <WorkloadCellIdentity>{};
  final _matchingForm = <WorkloadCellIdentity>{};
  bool _hasSuggestion = false;

  Set<WorkloadCellIdentity> get choices => _choices;
  bool get sameDiscipline => _matching.isNotEmpty;
  WorkloadCellIdentity? get suggested {
    if (_matching.length == 1 && _hasSuggestion) return _matching.single;
    return _matchingForm.length == 1 ? _matchingForm.single : null;
  }
}

/// The shared row choices and per-month changes for a multi-month review.
class WorkloadBatch {
  WorkloadBatch(this.months) {
    for (final month in months) {
      for (final total in month.lines) {
        final line = lines.putIfAbsent(
            workloadLineIdentity(total), WorkloadBatchLine.new);
        final options = month._options(total);
        final form = total.studyForm;
        for (final cell in options.choices) {
          final row = workloadCellIdentity(cell);
          if (options.sameDiscipline) line._matching.add(row);
          if (month.availableCell(row) == null) continue;
          line._choices.add(row);
          if (options.sameDiscipline &&
              form != null &&
              cell.studyForm == form) {
            line._matchingForm.add(row);
          }
          if (options.suggested == cell.key) line._hasSuggestion = true;
        }
      }
    }
  }

  final List<WorkloadBatchMonth> months;
  final lines = <WorkloadLineIdentity, WorkloadBatchLine>{};

  /// The changes for each selected month, including months with no changes.
  List<WorkloadMonthChanges> changes(
          Map<WorkloadLineIdentity, WorkloadCellIdentity?> choices) =>
      [for (final month in months) month.changes(choices)];
}

/// One month's confirmation and submission, using that month's field keys.
class WorkloadMonthChanges {
  WorkloadMonthChanges._(this.option, Map<PortalWorkloadCell, int> fields)
      : amounts = {
          for (final entry in fields.entries) entry.key.key: entry.value
        },
        descriptions = [
          for (final entry in fields.entries)
            workloadChange(entry.key, entry.value),
        ];

  final WorkloadBatchOption option;
  final Map<String, int> amounts;
  final List<String> descriptions;

  int get total => amounts.values.fold(0, (sum, amount) => sum + amount);

  /// How many submitted fields match the values returned by the portal.
  int verifiedCount(Iterable<PortalWorkloadCell> cells) {
    final saved = {for (final cell in cells) cell.key: cell.amount};
    return amounts.entries
        .where((entry) => saved[entry.key] == entry.value)
        .length;
  }
}

/// The total to display in the review and confirmation, in hundredths of an hour.
int workloadBatchTotal(Iterable<WorkloadMonthChanges> months) =>
    months.fold(0, (sum, month) => sum + month.total);

/// Shows the confirmed months and the month currently being saved.
String workloadBatchProgress(List<String> labels, int verified) => [
      for (final label in labels.take(verified)) '$label ✓',
      '${labels[verified]} — сохраняем…',
    ].join(' · ');

/// Reports confirmed, unverified, unsent and unchanged months after a batch.
String workloadBatchResult(List<String> labels, int verified,
        {List<String> unchanged = const []}) =>
    [
      if (verified > 0) 'Сохранено: ${labels.take(verified).join(', ')}.',
      if (verified < labels.length)
        'Сохранение не подтверждено: ${labels[verified]}.',
      if (verified + 1 < labels.length)
        'Не отправлены: ${labels.skip(verified + 1).join(', ')}.',
      if (unchanged.isNotEmpty) 'Без изменений: ${unchanged.join(', ')}.',
    ].join('\n');
