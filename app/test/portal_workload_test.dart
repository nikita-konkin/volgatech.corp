import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:volgatech_pro/core/portal_workload.dart';

PortalWorkloadCell _cell(String discipline,
        {String column = 'HoursAuditLab', int amount = 0}) =>
    PortalWorkloadCell.fromJson({
      'key': '$discipline/$column',
      'rowKey': discipline,
      'column': column,
      'discipline': discipline,
      'specialty': '09.03.02-ИСТ (о) (51) - 2 курс',
      'appointment': 'Основное место работы',
      'semester': '1 семестр',
      'amount': amount,
    });

WorkloadTotal _total(String discipline, {String column = 'HoursAuditLab'}) =>
    WorkloadTotal(discipline, column, ['ИСТ-${Random().nextInt(400) + 10}'])
      ..hours = 2 * (Random().nextInt(8) + 1);

void main() {
  test('a discipline the department form does not list is hidden from autofill',
      () {
    expect(
      departmentWorkload([
        _total('Машинное обучение и анализ данных'),
        _total('Введение в инженерную деятельность'),
      ], [
        _cell('Введение в инженерную деятельность')
      ]).hidden.map((total) => total.discipline),
      equals(['Машинное обучение и анализ данных']),
      reason: 'a discipline of another department was not hidden',
    );
  });

  test('a discipline the department form lists stays without the needed field',
      () {
    expect(
      departmentWorkload([
        _total('Инженерия информационных систем', column: 'HoursAuditLec'),
      ], [
        _cell('Инженерия информационных систем', column: 'HoursAuditPract')
      ]).shown,
      hasLength(1),
      reason: 'a discipline of this department was hidden',
    );
  });

  test('a discipline spelled with other case and ё stays in autofill', () {
    expect(
      departmentWorkload([
        _total('Основы  программирования на Python ЁЖ'),
      ], [
        _cell('основы программирования на python еж')
      ]).hidden,
      isEmpty,
      reason: 'a differently spelled discipline of this department was hidden',
    );
  });

  test('a change reads as discipline, kind and hours before and after', () {
    final hours = Random().nextInt(40) + 1;
    expect(
      workloadChange(
          _cell('Введение в инженерную деятельность',
              column: 'HoursAuditPract', amount: 200),
          hours * 100),
      equals(
          'Введение в инженерную деятельность · Практические: 2 → $hours ч.'),
      reason: 'the change does not show the old and new hours',
    );
  });

  test('in the first week of a month the form opens on the previous month', () {
    expect(
      workloadMonth(DateTime(2027, 1, Random().nextInt(7) + 1)),
      equals(DateTime(2026, 12)),
      reason: 'the previous month was not chosen early in January',
    );
  });

  test('after the first week the form opens on the current month', () {
    expect(
      workloadMonth(DateTime(2026, 11, Random().nextInt(23) + 8)),
      equals(DateTime(2026, 11)),
      reason: 'the current month was not chosen after its first week',
    );
  });
}
