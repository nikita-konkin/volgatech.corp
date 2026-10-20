import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:volgatech_pro/core/hourly_docx.dart';
import 'package:volgatech_pro/core/hourly_load.dart';
import 'package:volgatech_pro/models/schedule.dart';

ScheduleEvent _ev(String begin, String group,
        {String subject = 'Машинное обучение и анализ данных',
        String type = 'Практические',
        String room = '414',
        String? category = 'TimeTable',
        String? sub}) =>
    ScheduleEvent(
      timeBegin: '$begin:00',
      description: subject,
      fullDescription: group,
      subGroup: sub,
      typeWorkName: type,
      room: room,
      category: category,
    );

String _docText(Uint8List docx) {
  final doc = utf8.decode(
      ZipDecoder().decodeBytes(docx).findFile('word/document.xml')!.content);
  return RegExp(r'<w:t(?: [^>]*)?>([^<]*)</w:t>')
      .allMatches(doc)
      .map((m) => m[1])
      .join('|');
}

void main() {
  test('lesson types as the form writes them', () {
    expect(hourlyLessonType('Лекции'), 'Лекция');
    expect(hourlyLessonType('Практические'), 'Практика');
    expect(hourlyLessonType('Лабораторные'), 'Лабораторная');
    expect(hourlyLessonType('консультации'), 'Консультации');
    expect(hourlyLessonType(null), '');
  });

  test('semesters: spring February–August, autumn September–January', () {
    expect(semesterStart(DateTime(2026, 3, 12)), DateTime(2026, 2));
    expect(semesterStart(DateTime(2026, 8, 30)), DateTime(2026, 2));
    expect(semesterStart(DateTime(2026, 10, 1)), DateTime(2026, 9));
    expect(semesterStart(DateTime(2027, 1, 20)), DateTime(2026, 9));
    expect(semesterMonths(DateTime(2026, 10)),
        [for (var m = 9; m <= 13; m++) DateTime(2026, m)]);
    expect(semesterMonths(DateTime(2026, 4)), hasLength(7));
    expect(semesterLabel(DateTime(2026, 3)), 'Весенний семестр 2026');
    expect(semesterLabel(DateTime(2026, 11)), 'Осенний семестр 2026/27');
  });

  test('classes: groups taught together are one, events are not classes', () {
    final classes = hourlyClassesFrom([
      ScheduleDay(date: DateTime(2026, 2, 12), events: [
        _ev('09:45', 'ИСТ-310', type: 'Лекции'),
        _ev('09:45', 'ИСТ-311', type: 'Лекции'),
        _ev('08:00', 'ИСТ-310'),
        _ev('13:00', 'ИСТ-310', category: 'Event'),
        _ev('15:00', 'ИСТ-23', sub: 'подгруппа 1', subject: 'Базы данных'),
      ]),
    ]);
    expect([
      for (final c in classes) '${c.time} ${c.type} ${c.groups}'
    ], [
      '08:00 Практика [ИСТ-310]',
      '09:45 Лекция [ИСТ-310, ИСТ-311]',
      '15:00 Практика [ИСТ-23 (подгруппа 1)]',
    ]);
    expect(classes[1].hours, 2);

    final courses = coursesFrom(classes);
    expect([for (final c in courses) c.discipline],
        ['Базы данных', 'Машинное обучение и анализ данных']);
    expect(courses.first.groups.keys, ['ИСТ-23'], reason: 'by the base group');
    expect(courses.last.typeSummary(), 'практики 1 · лекции 1');
    expect(courses.last.typeSummary('ИСТ-311'), 'лекции 1');

    // Only the picked groups of a joint class are printed.
    final picked = {pickKey('Машинное обучение и анализ данных', 'ИСТ-311')};
    expect(pickedGroups(classes[1], picked), ['ИСТ-311']);
    expect(pickedGroups(classes[0], picked), isEmpty);
  });

  test('a plan: topics held for so many classes, then nothing', () {
    const plan = [PlanTopic('Pandas для МО', 2), PlanTopic('Статистика')];
    expect([for (var i = 0; i < 4; i++) topicAt(plan, i)?.title],
        ['Pandas для МО', 'Pandas для МО', 'Статистика', null]);
    expect(topicAt(plan, 2)?.item, 1);
    expect(planLength(plan), 3);
  });

  test('a pasted plan: numbering dropped, counts at the end', () {
    expect(
        parsePlan('1. Pandas для МО ×4\n'
            '2) Статистика в задачах МО x 4\n'
            '\n'
            '- Предобработка данных (2)\n'
            '• Типы данных   в МО\n'
            'Стандарт IEEE 802.11 *3\n'),
        const [
          PlanTopic('Pandas для МО', 4),
          PlanTopic('Статистика в задачах МО', 4),
          PlanTopic('Предобработка данных', 2),
          PlanTopic('Типы данных в МО'),
          PlanTopic('Стандарт IEEE 802.11', 3),
        ]);
  });

  test('the period in a file name', () {
    expect(periodTag([DateTime(2026, 3), DateTime(2026, 2)]), '02-03.26');
    expect(periodTag([DateTime(2026, 9)]), '09.26');
    expect(periodTag([DateTime(2026, 2), DateTime(2026, 4)]), '02,04.26');
    expect(periodTag([DateTime(2026, 12), DateTime(2027, 1)]), '12.26-01.27');
  });

  group('the .docx', () {
    final template = File(kHourlyTemplateAsset).readAsBytesSync();
    const header = HourlyHeader(
      teacherPost: 'ст. преподаватель',
      teacherName: 'Смирнов Сергей Сергеевич',
      signerPost: 'Зав. кафедрой ИТ',
      signerName: 'А.Б. Иванова',
    );
    HourlyRow r(int day, String type, String topic) => HourlyRow(
        date: DateTime(2026, 2, day),
        hours: 2,
        groups: const ['ИСТ-310'],
        type: type,
        discipline: 'Машинное обучение и анализ данных',
        topic: topic);

    test('rows, the total and the signature, as the form has them', () {
      final docx = buildHourlyDocx(Uint8List.fromList(template), header, [
        r(5, 'Практика', 'Pandas для МО'),
        r(12, 'Лекция', 'Типы данных & <признаки>'),
        r(19, 'Практика', ''),
      ]);
      final text = _docText(docx);
      expect(text, contains('ст. преподаватель Смирнов Сергей Сергеевич'));
      expect(
          text,
          contains('05.02.26|2|ИСТ-310|Практика|'
              'Машинное обучение и анализ данных|Pandas для МО'));
      expect(text, contains('Типы данных &amp; &lt;признаки&gt;'));
      expect(text, contains('Итого|6|-'));
      expect(text, contains('Зав. кафедрой ИТ'));
      expect(text.replaceAll('|', ''), contains('/А.Б. Иванова/'));
      expect(text, isNot(contains('{{')));
      final doc = utf8.decode(ZipDecoder()
          .decodeBytes(docx)
          .findFile('word/document.xml')!
          .content);
      expect(doc, contains('w:orient="landscape"'));
      expect(RegExp('<w:cantSplit/>').allMatches(doc), hasLength(4),
          reason: 'three classes and «Итого»');
    });

    test('plans read back from a report, repeats counted', () {
      final docx = buildHourlyDocx(Uint8List.fromList(template), header, [
        r(5, 'Практика', 'Pandas для МО'),
        r(12, 'Лекция', 'Типы данных в МО'),
        r(12, 'Практика', 'Pandas для МО'),
        r(19, 'Практика', 'Статистика в задачах МО'),
        r(26, 'Практика', ''),
      ]);
      expect(plansFromReport(docx), {
        'Машинное обучение и анализ данных|Практика': const [
          PlanTopic('Pandas для МО', 2),
          PlanTopic('Статистика в задачах МО'),
        ],
        'Машинное обучение и анализ данных|Лекция': const [
          PlanTopic('Типы данных в МО'),
        ],
      });
    });

    test('the template carries no names', () {
      final archive = ZipDecoder().decodeBytes(template);
      for (final f in ['word/document.xml', 'docProps/core.xml']) {
        final xml = utf8.decode(archive.findFile(f)!.content);
        expect(xml, isNot(matches(RegExp(r'<dc:creator>[^<]'))));
        expect(xml, isNot(matches(RegExp(r'<cp:lastModifiedBy>[^<]'))));
      }
      expect(_docText(Uint8List.fromList(template)),
          allOf(contains('{{teacher}}'), contains('{{signer_name}}')));
    });
  });
}
