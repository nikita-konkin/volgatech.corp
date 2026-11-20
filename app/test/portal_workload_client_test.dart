import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:volgatech_pro/data/portal_workload_client.dart';

String _marker(Random random) =>
    '&AuthResend${List.generate(32, (_) => random.nextInt(16).toRadixString(16).toUpperCase()).join()}';

String _page(String name) =>
    'https://portal.volgatech.net/my/personal/u${Random().nextInt(9999)}/SitePages/'
    '${Uri.encodeComponent(name)}';

PortalWorkloadReport _report({
  String department = '1726',
  List<(String, String)> departments = const [
    ('ЕСиОД', '2095'),
    ('ИТРС', '1726'),
  ],
  List<(String, String)> years = const [
    ('2026/2027', '2026'),
    ('2025/2026', '2025'),
  ],
  List<(String, String)> months = const [
    ('Сентябрь 2026', '1'),
    ('Октябрь 2026', '2'),
    ('Ноябрь 2026', '3'),
  ],
}) {
  Map<String, Object> filter(List<(String, String)> options, String value) => {
        'selected': {
          'label': options.firstWhere((o) => o.$2 == value).$1,
          'value': value,
        },
        'options': [
          for (final (label, value) in options) {'label': label, 'value': value}
        ],
      };
  return PortalWorkloadReport({
    'scope': 'scope',
    'filters': {
      'person': filter(const [('Преподаватель', '1')], '1'),
      'department': filter(departments, department),
      'year': filter(years, years.first.$2),
      'month': filter(months, months.first.$2),
    },
    'cells': <Object>[],
  });
}

void main() {
  test(
      'a workload page the gateway marked after sign-in is still the workload page',
      () {
    expect(
      isWorkloadPage(Uri.parse(
          '${_page('Нагрузка на первую половину дня.aspx')}${_marker(Random())}')),
      isTrue,
      reason: 'the marked workload page was not recognised',
    );
  });

  test('another page marked by the gateway is not the workload page', () {
    expect(
      isWorkloadPage(
          Uri.parse('${_page('Расписание.aspx')}${_marker(Random())}')),
      isFalse,
      reason: 'a foreign page was taken for the workload page',
    );
  });

  test('the remembered workload address drops the gateway marker', () {
    final page = _page('Нагрузка на первую половину дня.aspx');
    expect(
      portalAddress(Uri.parse('$page${_marker(Random())}')),
      equals(Uri.parse(page)),
      reason: 'the gateway marker stayed in the remembered address',
    );
  });

  test('the form opens on the remembered department', () {
    expect(
      workloadSelection(_report(department: '2095'), DateTime(2026, 11),
          department: '1726')['department'],
      equals('1726'),
      reason: 'the remembered department was not chosen',
    );
  });

  test('a remembered department the portal no longer offers is ignored', () {
    expect(
      workloadSelection(_report(department: '2095'), DateTime(2026, 11),
          department: '${Random().nextInt(900) + 3000}')['department'],
      equals('2095'),
      reason: 'a department missing on the portal was requested',
    );
  });

  test('the form opens on the study year of the month', () {
    expect(
      workloadSelection(_report(), DateTime(2026, 11))['year'],
      equals('2026'),
      reason: 'the study year of November 2026 was not chosen',
    );
  });

  test('the form opens on the month found by its label', () {
    expect(
      workloadSelection(_report(), DateTime(2026, 11))['month'],
      equals('3'),
      reason: 'November 2026 was not chosen by its label',
    );
  });

  test('a month the portal does not list leaves the month unchanged', () {
    expect(
      workloadSelection(_report(), DateTime(2027, 3))['month'],
      equals('1'),
      reason: 'a month missing on the portal was requested',
    );
  });
}
