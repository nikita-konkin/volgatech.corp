import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:volgatech_pro/core/portal_workload.dart';
import 'package:volgatech_pro/core/portal_workload_batch.dart';

PortalWorkloadCell _cell(String key, String form, {int amount = 0}) =>
    PortalWorkloadCell.fromJson({
      'key': key,
      'rowKey': key,
      'column': 'HoursAuditLab',
      'discipline': 'Геометрия ветра',
      'specialty': '73.14.21-ШВ ($form) ($key) - 3 курс',
      'appointment': 'Совместительство',
      'semester': '1 семестр',
      'amount': amount,
    });

void main() {
  test('a unique available row with the shared form is suggested', () {
    final key = '${Random().nextInt(700) + 91}';
    final total = WorkloadTotal('Геометрия ветра', 'HoursAuditLab',
        ['ЧВ-73 (оз)', 'ШФ-19 (оз) (2 п/г)']);
    expect(
      workloadTargets(
          total,
          [
            _cell('7', 'о'),
            _cell(key, 'оз'),
            _cell('16', 'оз', amount: 240),
            _cell('31', 'оз'),
          ],
          DateTime(2043, 11),
          occupied: {'31'}).suggested,
      key,
      reason: 'the unique free row with the right study form was not suggested',
    );
  });

  test('a known form cannot stand in for an unknown group form', () {
    final key = '${Random().nextInt(900) + 31}';
    final total = WorkloadTotal(
        'Геометрия ветра', 'HoursAuditLab', ['ЧВ-$key (оз)', 'ШФ-72']);
    expect(
      workloadTargets(
              total, [_cell('29', 'о'), _cell(key, 'оз')], DateTime(2043, 11))
          .suggested,
      isNull,
      reason: 'a row was guessed while one group had an unknown form',
    );
  });

  test('two free rows with the same form still require a choice', () {
    final key = '${Random().nextInt(700) + 92}';
    final total =
        WorkloadTotal('Геометрия ветра', 'HoursAuditLab', ['УВ-$key (з)']);
    expect(
      workloadTargets(
              total, [_cell('12', 'з'), _cell(key, 'з')], DateTime(2043, 11))
          .suggested,
      isNull,
      reason: 'an ambiguous specialty was selected automatically',
    );
  });

  test('a shared batch choice uses the same form across months', () {
    final key = '${Random().nextInt(800) + 61}';
    final total =
        WorkloadTotal('Геометрия ветра', 'HoursAuditLab', ['УЖ-$key (з)']);
    final right = _cell(key, 'з');
    final batch = WorkloadBatch([
      WorkloadBatchMonth(
          (month: DateTime(2043, 11), label: 'Ноябрь', value: '11'),
          [total],
          [right, _cell('57', 'о')]),
      WorkloadBatchMonth(
          (month: DateTime(2043, 12), label: 'Декабрь', value: '12'),
          [total],
          [_cell('83', 'оз'), right]),
    ]);
    expect(batch.lines[workloadLineIdentity(total)]!.suggested,
        workloadCellIdentity(right),
        reason: 'the shared batch row lost its unique matching form');
  });
}
