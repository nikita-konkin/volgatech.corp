import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:volgatech_pro/core/hourly_load.dart';
import 'package:volgatech_pro/core/lesson_grouping.dart';
import 'package:volgatech_pro/core/portal_timetable.dart';
import 'package:volgatech_pro/core/portal_workload.dart';
import 'package:volgatech_pro/models/schedule.dart';

Map<String, Object> _row(
  String group,
  String form, {
  int weekday = 4,
  String begin = '13:15',
  String discipline = 'Счёт   облаков',
  List<Map<String, String>> dates = const [],
}) =>
    {
      'weekday': weekday,
      'begin': begin,
      'discipline': discipline,
      'group': group,
      'form': form,
      'dates': dates,
    };

ScheduleEvent _event(String group, DateTime date, {String? subgroup}) =>
    ScheduleEvent(
      category: 'TimeTable',
      fullDescription: group,
      date: date,
      timeBegin: '13:15:00',
      description: '  СЧЕТ облаков  8 п/г ',
      typeWorkName: 'Лабораторные',
      subGroup: subgroup,
    );

void main() {
  test('a lesson matches weekday begin time normalized discipline and group',
      () {
    final group = 'ШР-${Random().nextInt(800) + 14}';
    final date = DateTime(2043, 12, 3);
    final timetable = PortalTimetable([
      _row(group, 'о', weekday: 2),
      _row(group, 'з', begin: '13:16'),
      _row(group, 'з', discipline: 'Счёт песчинок'),
      _row('$group-М', 'з'),
      _row(group, 'оз'),
    ]);
    expect(timetable.formFor(_event(group, date)), 'оз',
        reason: 'the matching lesson lost its form');
  });

  test('an inclusive dated range resolves competing forms', () {
    final group = 'ЖЗ-${Random().nextInt(700) + 23}';
    final timetable = PortalTimetable([
      _row(group, 'оз', dates: [
        {'from': '2043-11-28', 'to': '2043-12-03'}
      ]),
      _row(group, 'з', dates: [
        {'from': '2043-12-04', 'to': '2043-12-11'}
      ]),
    ]);
    expect(timetable.formFor(_event(group, DateTime(2043, 12, 3))), 'оз',
        reason: 'the last day of the session was excluded');
  });

  test('a single day with an implied year resolves the lesson form', () {
    final group = 'ЖВ-${Random().nextInt(300) + 37}';
    final timetable = PortalTimetable([
      _row(group, 'оз', dates: [
        {'from': '12-10', 'to': '12-10'}
      ]),
      _row(group, 'з', dates: [
        {'from': '12-03', 'to': '12-03'}
      ]),
    ]);
    expect(timetable.formFor(_event(group, DateTime(2043, 12, 3))), 'з',
        reason: 'the date without a year did not select its form');
  });

  test('an undated row still competes with a row covering the event date', () {
    final group = 'ФЭ-${Random().nextInt(600) + 51}';
    final timetable = PortalTimetable([
      _row(group, 'о'),
      _row(group, 'з', dates: [
        {'from': '12-03', 'to': '12-03'}
      ]),
    ]);
    expect(timetable.formFor(_event(group, DateTime(2043, 12, 3))), isNull,
        reason: 'an ambiguous dated lesson received a form');
  });

  test('only a unique form for the whole code can resolve an unmatched slot',
      () {
    final group = 'ШТ-${Random().nextInt(500) + 67}';
    final timetable = PortalTimetable([
      _row(group, 'о', weekday: 6),
      _row(group, 'о', begin: '11:21'),
      _row('$group-М', 'з'),
    ]);
    expect(timetable.formFor(_event(group, DateTime(2043, 12, 1))), 'о',
        reason: 'the code lost its unique form outside the matching slot');
  });

  test('merged groups display the form before the subgroup when it is known',
      () {
    final group = 'ЦШ-${Random().nextInt(500) + 45}';
    final date = DateTime(2043, 12, 3);
    final timetable = PortalTimetable([_row(group, 'оз')]);
    final slot = groupParallelLessons([
      _event(group, date, subgroup: 'подгруппа 8'),
        _event('$group-М', date),
    ], studyForm: timetable.formFor)
        .single;
    expect(slot.groups, ['$group (оз) (подгруппа 8)', '$group-М'],
        reason: 'a merged lesson lost its form or subgroup label');
  });

  test('the workload and hourly report can read the same lesson independently',
      () {
    final group = 'ЖЦ-${Random().nextInt(800) + 77}';
    final date = DateTime(2043, 12, 3);
    final timetable = PortalTimetable([_row(group, 'з')]);
    final days = [
      ScheduleDay(date: date, events: [_event(group, date)])
    ];
    final totals = monthlyWorkload(
        hourlyClassesFrom(days, studyForm: timetable.formFor),
        DateTime(2043, 12),
        DateTime(2043, 12, 11));
    expect([
      totals.single.groups,
      hourlyClassesFrom(days).single.groups
    ], [
      ['$group (з)'],
      [group]
    ],
        reason:
            'the workload form annotation was lost or leaked into report groups');
  });
}
