import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:volgatech_pro/core/hourly_load.dart';
import 'package:volgatech_pro/core/portal_workload.dart';

void main() {
  test('a monthly payload keeps academic hours and timetable group labels', () {
    final random = Random();
    final year = 2030 + random.nextInt(30);
    final month = DateTime(year, 1);
    final groups = ['ЗИ-${random.nextInt(74) + 11} (2)', 'БАС-87'];
    final discipline = 'Расчёт антенн №${random.nextInt(57) + 3}';
    final hours = random.nextInt(13) + 2;
    final totals = monthlyWorkload([
      HourlyClass(
        date: DateTime(year, 1, 9),
        time: '14:37',
        groups: groups,
        discipline: discipline,
        type: 'Лабораторная',
        hours: hours,
      ),
      HourlyClass(
        date: DateTime(year, 1, 13),
        time: '11:29',
        groups: groups,
        discipline: discipline,
        type: 'Практика',
      ),
    ], month, DateTime(year, 1, 13));
    expect(
        jsonDecode(workloadPortalPayload(month, totals)),
        {
          'volgatech': 'workload/1',
          'month': '$year-01',
          'semester': '1 семестр',
          'lines': [
            {
              'discipline': discipline,
              'column': 'HoursAuditLab',
              'hours': hours,
              'groups': ['БАС-87', groups.first],
            }
          ],
        },
        reason: 'the payload does not preserve the completed timetable hours');
  });
}
