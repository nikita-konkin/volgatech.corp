import 'package:flutter_test/flutter_test.dart';
import 'package:volgatech_pro/core/foreign_memo.dart';
import 'package:volgatech_pro/models/schedule.dart';

ScheduleEvent _e(
  String begin,
  String group, {
  String subject = 'Информационные технологии в отрасли',
  String room = '414',
  String type = 'Лекции',
  String? category = 'TimeTable',
}) =>
    ScheduleEvent(
      timeBegin: '$begin:00',
      timeEnd: '$begin:00',
      building: 'III',
      room: room,
      description: subject,
      fullDescription: group,
      typeWorkName: type,
      category: category,
    );

void main() {
  group('isForeignGroup: three digits after the hyphen', () {
    test('foreign groups', () {
      for (final g in [
        'ИСТ-110',
        'ИСТ-210',
        'ИСТ-310',
        'ИСТ-410',
        ' ИСТ-110 '
      ]) {
        expect(isForeignGroup(g), isTrue, reason: g);
      }
    });
    test('regular groups and junk', () {
      for (final g in [
        'ИСТ-23',
        'ИТС-21',
        'ИСТм-21',
        'ИСТ-1100',
        '',
        'ИСТ110'
      ]) {
        expect(isForeignGroup(g), isFalse, reason: g);
      }
    });
  });

  test('memoLessonType writes the memo wording', () {
    expect(memoLessonType('Лекции'), 'лекция');
    expect(memoLessonType('Практические'), 'практическая');
    expect(memoLessonType('Лабораторные'), 'лабораторная');
    expect(memoLessonType('Зачёт'), 'зачёт');
    expect(memoLessonType(null), '');
  });

  test('shortPost and departmentDative', () {
    expect(shortPost('старший преподаватель'), 'ст. преподаватель');
    expect(shortPost('доцент'), 'доцент');
    expect(
        departmentDative(
            'Кафедра информационных технологий, радиотехники и связи'),
        'Кафедре информационных технологий, радиотехники и связи');
    expect(departmentDative('Деканат'), 'Деканат');
  });

  group('memoRowsFrom', () {
    final tue = DateTime(2026, 9, 1);
    final wed = DateTime(2026, 9, 2);
    late List<MemoRow> rows;

    setUp(() {
      rows = memoRowsFrom([
        // Days out of order on purpose.
        ScheduleDay(date: wed, events: [
          _e('08:00', 'ИСТ-110',
              subject: ' Введение в  инженерную деятельность ',
              type: 'Практические'),
        ]),
        ScheduleDay(date: tue, events: [
          _e('13:30', 'ИТС-21', room: '333г'), // shared with a regular group
          _e('13:30', 'ИСТ-310', room: '333г'),
          _e('09:45', 'ИСТ-23', type: 'Лабораторные'), // regular group only
          _e('11:30', 'ИСТ-110'), // two foreign groups together
          _e('11:30', 'ИСТ-210'),
          _e('08:00', 'ИСТ-410', type: 'Лабораторные'),
          _e('15:00', 'ИСТ-110', category: 'Event'), // not a class
        ]),
      ]);
    });

    test('keeps only classes with a foreign group, in date/time order', () {
      expect([
        for (final r in rows) '${r.date.day} ${r.time} ${r.groups}'
      ], [
        '1 08:00 [ИСТ-410]',
        '1 11:30 [ИСТ-110, ИСТ-210]',
        '1 13:30 [ИСТ-310]',
        '2 08:00 [ИСТ-110]',
      ]);
    });

    test('groups taught together are one class, credited once', () {
      final shared = rows[1];
      expect(shared.groups, ['ИСТ-110', 'ИСТ-210']);
      expect(shared.hours, kHoursPerClass);
    });

    test('a class shared with a regular group lists only the foreign one', () {
      expect(rows[2].groups, ['ИСТ-310']);
    });

    test('fields are in memo wording', () {
      final r = rows[3];
      expect(r.discipline, 'Введение в инженерную деятельность');
      expect(r.type, 'практическая');
      expect(r.hours, 2);
      expect(r.manual, isFalse);
    });
  });

  test('a hand-added row survives a JSON round trip', () {
    final r = MemoRow(
      date: DateTime(2026, 9, 3),
      time: '10:00',
      groups: const ['ИСТ-110'],
      discipline: 'Физика',
      type: 'лекция',
      manual: true,
    );
    final back = MemoRow.fromJson(r.toJson());
    expect(back.key, r.key);
    expect(back.manual, isTrue);
  });
}
