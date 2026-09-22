import 'package:flutter_test/flutter_test.dart';
import 'package:volgatech_pro/core/lesson_grouping.dart';
import 'package:volgatech_pro/models/schedule.dart';

ScheduleEvent _e({
  required String begin,
  required String room,
  required String subject,
  required String group,
  String? subGroup,
  String building = 'III',
  String type = 'Лабораторные',
}) =>
    ScheduleEvent(
      timeBegin: begin,
      timeEnd: '${int.parse(begin.substring(0, 2)) + 1}${begin.substring(2)}',
      building: building,
      room: room,
      description: subject,
      fullDescription: group,
      subGroup: subGroup,
      typeWorkName: type,
    );

void main() {
  const py = 'Основы программирования систем ИИ на языке Python';

  test('two groups in the same room/time/subject merge into one shared slot', () {
    final slots = groupParallelLessons([
      _e(begin: '15:15:00', room: '333г', subject: py, group: 'ИТС-21', subGroup: 'подгруппа 2'),
      _e(begin: '15:15:00', room: '333г', subject: py, group: 'ИТС-22', subGroup: 'подгруппа 2'),
    ]);
    expect(slots.length, 1);
    expect(slots.first.isShared, isTrue);
    expect(slots.first.groups,
        ['ИТС-21 (подгруппа 2)', 'ИТС-22 (подгруппа 2)']);
  });

  test('different time, room, or subject do NOT merge', () {
    expect(groupParallelLessons([
      _e(begin: '15:15:00', room: '333г', subject: py, group: 'ИТС-21'),
      _e(begin: '17:00:00', room: '333г', subject: py, group: 'ИТС-21'),
    ]).length, 2); // different time

    expect(groupParallelLessons([
      _e(begin: '15:15:00', room: '333г', subject: py, group: 'ИТС-21'),
      _e(begin: '15:15:00', room: '414', subject: py, group: 'ИТС-22'),
    ]).length, 2); // different room

    expect(groupParallelLessons([
      _e(begin: '15:15:00', room: '333г', subject: py, group: 'ИТС-21'),
      _e(begin: '15:15:00', room: '333г', subject: 'Другой предмет', group: 'ИТС-22'),
    ]).length, 2); // different subject (real clash, not a merge)
  });

  test('single lesson is a non-shared slot; order preserved', () {
    final slots = groupParallelLessons([
      _e(begin: '08:00:00', room: '438а', subject: 'Введение', group: 'ИСТ-110'),
      _e(begin: '09:45:00', room: '414', subject: 'МО', group: 'ИСТ-410'),
    ]);
    expect(slots.length, 2);
    expect(slots.every((s) => !s.isShared), isTrue);
    expect(slots.first.groups, ['ИСТ-110']);
    expect(slots[0].lead.timeBegin, '08:00:00'); // input order kept
  });
}
