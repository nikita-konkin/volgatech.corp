import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:volgatech_pro/core/portal_workload.dart';
import 'package:volgatech_pro/core/portal_workload_batch.dart';

PortalWorkloadCell _cell(
  String key, {
  String discipline = 'Алгоритмы',
  String specialty = 'ИСТ',
  String appointment = 'Основное место работы',
  String semester = '1 семестр',
  String column = 'HoursAuditLab',
  int amount = 0,
}) =>
    PortalWorkloadCell.fromJson({
      'key': key,
      'rowKey': 'row-$key',
      'column': column,
      'discipline': discipline,
      'specialty': specialty,
      'appointment': appointment,
      'semester': semester,
      'amount': amount,
    });

WorkloadTotal _line(
  int hours, {
  String discipline = 'Алгоритмы',
  List<String> groups = const ['ИСТ-21'],
}) =>
    WorkloadTotal(discipline, 'HoursAuditLab', groups)..hours = hours;

WorkloadBatchMonth _month(
  int month,
  List<WorkloadTotal> totals,
  List<PortalWorkloadCell> cells, {
  Set<String> occupied = const {},
}) =>
    WorkloadBatchMonth(
      (month: DateTime(2026, month), label: '$month', value: '$month'),
      totals,
      cells,
      occupied: occupied,
    );

void main() {
  test(
      'the checklist includes only offered past months of the selected semester',
      () {
    final year = 2001 + Random().nextInt(90);
    final months = workloadBatchMonths(
      DateTime(year + 1, 1),
      DateTime(year + 1, 1, 1, 22),
      [
        (label: 'Ноябрь $year', value: 'nov'),
        (label: 'Сентябрь $year', value: 'sep'),
        (label: 'Январь ${year + 1}', value: 'jan'),
        (label: 'Август $year', value: 'aug'),
        (label: 'Декабрь ${year - 1}', value: 'dec'),
        (label: 'Месяц', value: ''),
      ],
    );
    expect(
      months.map((month) => month.value),
      ['sep', 'nov'],
      reason: 'the checklist did not match the offered past semester months',
    );
  });

  test('a month becomes eligible once its first day has passed', () {
    final day = Random().nextInt(25) + 2;
    expect(
      workloadBatchMonths(
        DateTime(2026, 2),
        DateTime(2026, 2, day),
        [(label: 'Февраль 2026', value: 'feb')],
      ).map((month) => month.month),
      [DateTime(2026, 2)],
      reason: 'February was not offered after its first day',
    );
  });

  test('portal cells match across months only by the five row and field values',
      () {
    final row = workloadCellIdentity(_cell('old-${Random().nextInt(90)}'));
    expect(
      [
        for (final cell in [
          _cell('new'),
          _cell('new', discipline: 'Сети'),
          _cell('new', specialty: 'ПИ'),
          _cell('new', appointment: 'Совместительство'),
          _cell('new', semester: '2 семестр'),
          _cell('new', column: 'HoursAuditLec'),
        ])
          workloadCellIdentity(cell) == row,
      ],
      [true, false, false, false, false, false],
      reason: 'the comparison did not use the five portal field values',
    );
  });

  test('one choice follows a timetable line to months with different row IDs',
      () {
    final random = Random();
    final group = 'ИСТ-${random.nextInt(90) + 10}';
    final september = _line(2, discipline: '  Счёт  ', groups: [group, 'ПИ-2']);
    final october = _line(6, discipline: 'счет', groups: ['ПИ-2', group]);
    final sepCell = _cell('sep', discipline: 'Счёт');
    final octCell = _cell('oct', discipline: 'Счёт');
    final batch = WorkloadBatch([
      _month(9, [september], [sepCell]),
      _month(10, [october, _line(4, discipline: 'счет')], [octCell]),
    ]);
    expect(
      batch.changes({
        workloadLineIdentity(september): workloadCellIdentity(sepCell)
      }).map((month) => month.amounts),
      [
        {'sep': 200},
        {'oct': 600}
      ],
      reason: 'one choice did not follow the same groups to October',
    );
  });

  test('an alternate mapping is offered and used wherever that cell is free',
      () {
    final hours = Random().nextInt(9) + 2;
    final line = _line(hours);
    final alternate = _cell('alt', discipline: 'Сети');
    final choice = workloadCellIdentity(alternate);
    final id = workloadLineIdentity(line);
    final batch = WorkloadBatch([
      _month(9, [line], [_cell('lec', column: 'HoursAuditLec'), alternate]),
      _month(10, [line], [_cell('oct'), _cell('oct-alt', discipline: 'Сети')]),
      _month(11, [line],
          [_cell('nov'), _cell('nov-alt', discipline: 'Сети', amount: 100)]),
      _month(12, [line], [_cell('dec'), _cell('dec-alt', discipline: 'Сети')],
          occupied: {'dec-alt'}),
    ]);
    expect(
      [
        batch.lines[id]!.choices.contains(choice),
        batch.changes({id: choice}).map((month) => month.amounts).toList(),
      ],
      [
        true,
        [
          {'alt': hours * 100},
          {'oct-alt': hours * 100},
          <String, int>{},
          <String, int>{}
        ]
      ],
      reason: 'the alternate did not apply only to free matching cells',
    );
  });

  test('a shared choice skips a month with two indistinguishable portal rows',
      () {
    final line = _line(Random().nextInt(11) + 2);
    final september = _cell('sep');
    final batch = WorkloadBatch([
      _month(9, [line], [september]),
      _month(10, [line], [_cell('oct-1'), _cell('oct-2', amount: 100)]),
    ]);
    expect(
      batch
          .changes({
            workloadLineIdentity(line): workloadCellIdentity(september),
          })
          .where((month) => month.amounts.isNotEmpty)
          .map((month) => month.option.value),
      ['9'],
      reason: 'the indistinguishable October rows were not skipped',
    );
  });

  test('different candidate rows in different months are not suggested', () {
    final line = _line(Random().nextInt(7) + 2);
    final batch = WorkloadBatch([
      _month(9, [line], [_cell('sep')]),
      _month(10, [line], [_cell('oct', specialty: 'ПИ')]),
    ]);
    expect(
      batch.lines[workloadLineIdentity(line)]!.suggested,
      isNull,
      reason: 'different specialty rows did not require an explicit choice',
    );
  });

  test('the same unambiguous row is suggested for a shared timetable line', () {
    final line = _line(Random().nextInt(7) + 2);
    final september = _cell('sep', amount: 100);
    final october = _cell('oct');
    final batch = WorkloadBatch([
      _month(9, [line], [september]),
      _month(10, [line], [october]),
    ]);
    expect(
      batch.lines[workloadLineIdentity(line)]!.suggested,
      workloadCellIdentity(october),
      reason: 'the shared row was not suggested for the month it was free',
    );
  });

  test('only disciplines listed in the month and semester can be mapped', () {
    final line =
        _line(Random().nextInt(15) + 2, discipline: 'Иностранный язык');
    final month = _month(9, [line],
        [_cell('sep', discipline: line.discipline, semester: '2 семестр')]);
    expect(
      (month.lines.isEmpty, month.hidden.contains(line)),
      (true, true),
      reason: 'the discipline outside the loaded semester was not hidden',
    );
  });

  test('changes sum by field and month without counting skipped lines', () {
    final hours = Random().nextInt(17) + 2;
    final first = _line(hours);
    final second = _line(4, groups: ['ИСТ-22']);
    final skipped = _line(8, groups: ['ИСТ-23']);
    final sep = _cell('sep');
    final choice = workloadCellIdentity(sep);
    final batch = WorkloadBatch([
      _month(9, [first, second, skipped], [sep]),
      _month(10, [second], [_cell('oct')]),
    ]);
    final changes = batch.changes({
      workloadLineIdentity(first): choice,
      workloadLineIdentity(second): choice,
    });
    expect(
      [
        ...changes
            .map((month) => [month.option.value, month.amounts, month.total]),
        workloadBatchTotal(changes),
      ],
      [
        [
          '9',
          {'sep': (hours + 4) * 100},
          (hours + 4) * 100
        ],
        [
          '10',
          {'oct': 400},
          400
        ],
        (hours + 8) * 100,
      ],
      reason:
          'the field amounts or the per-month and grand totals did not add up',
    );
  });

  test('verification requires each requested monthly field to match', () {
    final hours = Random().nextInt(7) + 2;
    final line = _line(hours);
    final september = _cell('sep');
    final month = _month(9, [line], [september]).changes({
      workloadLineIdentity(line): workloadCellIdentity(september),
    });
    expect(
      [
        month.verifiedCount([_cell('sep', amount: hours * 100)]),
        month.verifiedCount([_cell('sep', amount: (hours - 1) * 100)]),
        month.verifiedCount([_cell('other', amount: hours * 100)]),
      ],
      [1, 0, 0],
      reason: 'verification did not require matching field keys and amounts',
    );
  });

  test('save progress shows each confirmed month and the current month', () {
    expect(
      workloadBatchProgress(['Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь'], 2),
      'Сентябрь ✓ · Октябрь ✓ · Ноябрь — сохраняем…',
      reason: 'progress did not distinguish confirmed and current months',
    );
  });

  test('the save result distinguishes confirmed, unverified and unsent months',
      () {
    expect(
      workloadBatchResult(['Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь'], 1),
      'Сохранено: Сентябрь.\nСохранение не подтверждено: Октябрь.\nНе отправлены: Ноябрь, Декабрь.',
      reason: 'the result did not report the status of every month',
    );
  });

  test('the result lists unchanged months when all submissions are verified',
      () {
    expect(
      workloadBatchResult(['Сентябрь', 'Ноябрь'], 2, unchanged: ['Октябрь']),
      'Сохранено: Сентябрь, Ноябрь.\nБез изменений: Октябрь.',
      reason: 'the result did not distinguish confirmed and unchanged months',
    );
  });
}
