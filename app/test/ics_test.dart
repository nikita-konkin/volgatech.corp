import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:volgatech_pro/core/ics.dart';
import 'package:volgatech_pro/models/exams.dart';
import 'package:volgatech_pro/models/schedule.dart';

ScheduleEvent _lesson(String begin, String end, String subject, String group,
        {String type = 'Лекции'}) =>
    ScheduleEvent(
      timeBegin: '$begin:00',
      timeEnd: '$end:00',
      description: subject,
      fullDescription: group,
      typeWorkName: type,
      room: '333г',
      building: 'III',
      fio: 'Иванов И.И.',
    );

/// The file's lines with the folding undone.
List<String> _unfolded(String ics) =>
    ics.replaceAll('\r\n ', '').split('\r\n')..removeLast();

void main() {
  final day = DateTime(2026, 10, 6);

  test('a lesson: Moscow time written in UTC, the rest escaped', () {
    final ics = buildIcs(
        lessonEvents({
          day: [
            _lesson('08:00', '09:35', 'Системы ИИ; часть 1, введение',
                'ИСТ-43',
                type: 'Лабораторные'),
          ],
        }),
        name: 'Расписание',
        now: DateTime.utc(2026, 10, 1, 12));
    final lines = _unfolded(ics);
    expect(lines.first, 'BEGIN:VCALENDAR');
    expect(lines.last, 'END:VCALENDAR');
    expect(lines, contains('DTSTART:20261006T050000Z'));
    expect(lines, contains('DTEND:20261006T063500Z'));
    expect(lines, contains('DTSTAMP:20261001T120000Z'));
    expect(lines,
        contains(r'SUMMARY:Системы ИИ\; часть 1\, введение (лаб.)'));
    expect(lines, contains('LOCATION:333г (III)'));
    expect(
        lines,
        contains(r'DESCRIPTION:Лабораторные\nГруппы: ИСТ-43\n'
            'Преподаватель: Иванов И.И.'));
    expect(ics, endsWith('\r\n'));
  });

  test('long lines are folded at 75 bytes, never inside a letter', () {
    final ics = buildIcs(
        lessonEvents({
          day: [_lesson('08:00', '09:35', 'Проектирование ' * 8, 'ИСТ-43')],
        }),
        name: 'Р');
    for (final line in ics.split('\r\n')) {
      expect(utf8.encode(line).length, lessThanOrEqualTo(75), reason: line);
      expect(line.contains('�'), isFalse);
    }
    expect(_unfolded(ics).where((l) => l.startsWith('SUMMARY:')).single,
        'SUMMARY:${('Проектирование ' * 8).trim()} (лекция)');
  });

  test('a shared slot is one event; ids hold from one export to the next',
      () {
    List<IcsEvent> week() => lessonEvents({
          day: [
            _lesson('09:45', '11:20', 'Сети', 'ИСТ-41'),
            _lesson('09:45', '11:20', 'Сети', 'ИСТ-42'),
            _lesson('11:30', '13:05', 'Сети', 'ИСТ-41'),
          ],
          DateTime(2026, 10, 7): [_lesson('bad', '', 'Без времени', 'ИСТ-41')],
        });
    final a = week(), b = week();
    expect(a, hasLength(2));
    expect(a.first.description, contains('Группы: ИСТ-41, ИСТ-42'));
    expect([for (final e in a) e.uid], [for (final e in b) e.uid]);
    expect(a[0].uid, isNot(a[1].uid));
  });

  test('exams: three hours from the start; undated ones left out', () {
    final events = examEvents([
      Exam(
          examDate: DateTime(2026, 1, 15, 9),
          subjectName: 'Сети',
          groupName: 'ИСТ-41',
          roomName: '333г',
          buildingName: 'III'),
      const Exam(subjectName: 'Без даты'),
    ]);
    expect(events, hasLength(1));
    final lines = _unfolded(buildIcs(events, name: 'Экзамены'));
    expect(lines, contains('DTSTART:20260115T060000Z'));
    expect(lines, contains('DTEND:20260115T090000Z'));
    expect(lines, contains('SUMMARY:Экзамен: Сети'));
    expect(lines, contains('LOCATION:333г (III)'));
  });
}
