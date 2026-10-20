import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:volgatech_pro/core/hourly_docx.dart';
import 'package:volgatech_pro/core/hourly_load.dart';
import 'package:volgatech_pro/core/prefs.dart';
import 'package:volgatech_pro/models/profile.dart';
import 'package:volgatech_pro/models/schedule.dart';
import 'package:volgatech_pro/state/hourly_controller.dart';

import 'fakes.dart';

const _ml = 'Машинное обучение и анализ данных';

ScheduleEvent _ev(String begin, String group, String type,
        {String subject = _ml}) =>
    ScheduleEvent(
      timeBegin: '$begin:00',
      description: subject,
      fullDescription: group,
      typeWorkName: type,
      room: '414',
      category: 'TimeTable',
    );

/// Thursdays as in the sample report: a practice each week, a lecture
/// every other week; another discipline for another group alongside.
List<ScheduleDay> _month(int month) {
  if (month != 2 && month != 3) return const [];
  return [
    for (final d in [5, 12, 19, 26])
      ScheduleDay(date: DateTime(2026, month, d), events: [
        _ev('08:00', 'ИСТ-310', 'Практические'),
        if (d == 12 || d == 26) _ev('09:45', 'ИСТ-310', 'Лекции'),
        _ev('11:30', 'ИСТ-23', 'Лабораторные', subject: 'Базы данных'),
      ]),
  ];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => initializeDateFormatting('ru_RU'));

  late FakeApi api;
  late Prefs prefs;

  const profile = PersonProfile(
    personId: 7,
    personFIO: 'Смирнов Сергей Сергеевич',
    salaries: [
      SalaryEntry(
          postName: 'старший преподаватель',
          departmentName: 'Кафедра информационных технологий',
          isMainJob: true),
    ],
  );

  Future<HourlyController> controller({List<DateTime>? months}) async {
    final c = HourlyController(
      api: api,
      personId: 7,
      prefs: prefs,
      profile: profile,
      today: DateTime(2026, 4, 5), // early April -> March
      loadTemplate: () async => File(kHourlyTemplateAsset).readAsBytesSync(),
    );
    await c.setMonths(months ?? [DateTime(2026, 2), DateTime(2026, 3)]);
    return c;
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await Prefs.load();
    api = FakeApi()..onSchedule = (start) async => _month(start.month);
  });

  List<String> topics(HourlyController c) => [
        for (final e in c.entries)
          [
            '${e.lesson.date.day}.${e.lesson.date.month}',
            e.lesson.type,
            e.topic,
          ].join(' '),
      ];

  test('the semester\'s disciplines, none picked yet', () async {
    final c = await controller();
    expect(c.semester, 'Весенний семестр 2026');
    expect([for (final x in c.courses) x.discipline], ['Базы данных', _ml]);
    expect(c.courses.last.typeSummary(), 'практики 8 · лекции 4');
    expect(c.entries, isEmpty);
    expect(c.periodLabel, 'Февраль — март 2026');
    expect(c.fileName, 'Приложение к форме 28 02-03.26.docx');
    // The semester, a month per request, each asked once.
    expect(api.scheduleCalls.toSet(), {
      for (var m = 2; m <= 8; m++) DateTime(2026, m),
    });
    final asked = api.scheduleCalls.length;
    await c.setMonths([DateTime(2026, 3)]);
    expect(api.scheduleCalls, hasLength(asked));
  });

  test('a picked discipline: its classes, 2 hours each, topics by the plan',
      () async {
    final c = await controller();
    await c.setPicked(_ml, true);
    expect(c.entries, hasLength(12));
    expect(c.totalHours, 24);
    expect(c.header.teacherPost, 'ст. преподаватель');
    expect(c.header.teacherName, 'Смирнов Сергей Сергеевич');

    await c.savePlan('$_ml|Практика', const [
      PlanTopic('Pandas для МО', 4),
      PlanTopic('Статистика в задачах МО', 4),
    ]);
    await c.savePlan('$_ml|Лекция', const [
      PlanTopic('Типы данных в МО'),
      PlanTopic('Типы данных числовые и категориальные'),
      PlanTopic('Предобработка и анализ данных', 2),
    ]);
    // As the sample report has them.
    expect(topics(c), [
      '5.2 Практика Pandas для МО',
      '12.2 Практика Pandas для МО',
      '12.2 Лекция Типы данных в МО',
      '19.2 Практика Pandas для МО',
      '26.2 Практика Pandas для МО',
      '26.2 Лекция Типы данных числовые и категориальные',
      '5.3 Практика Статистика в задачах МО',
      '12.3 Практика Статистика в задачах МО',
      '12.3 Лекция Предобработка и анализ данных',
      '19.3 Практика Статистика в задачах МО',
      '26.3 Практика Статистика в задачах МО',
      '26.3 Лекция Предобработка и анализ данных',
    ]);

    // March alone goes on from where February stopped.
    await c.setMonths([DateTime(2026, 3)]);
    expect(topics(c).first, '5.3 Практика Статистика в задачах МО');

    // A class taken out takes no topic: the next one gets it.
    await c.setMonths([DateTime(2026, 2), DateTime(2026, 3)]);
    await c.setIncluded(c.entries.first, false);
    expect(c.entries.first.included, isFalse);
    expect(c.rows, hasLength(11));
    expect(topics(c)[6], '5.3 Практика Pandas для МО');
  });

  test('a topic for one class, renaming a plan topic, no topics at all',
      () async {
    final c = await controller();
    await c.setPicked(_ml, true);
    await c.savePlan('$_ml|Практика', const [PlanTopic('Pandas для МО', 8)]);

    await c.setTopic(c.entries[1], 'Контрольная работа');
    expect(c.entries[1].topic, 'Контрольная работа');
    expect(c.entries[1].edited, isTrue);
    expect(c.entries[2].topic, isEmpty, reason: 'a lecture: no plan');
    expect(c.entries[3].topic, 'Pandas для МО');

    await c.renamePlanTopic(c.entries[0], 'Pandas');
    expect(c.plan('$_ml|Практика'), const [PlanTopic('Pandas', 8)]);
    expect(c.entries[1].topic, 'Контрольная работа', reason: 'still its own');

    await c.setTopic(c.entries[1], '');
    expect(c.entries[1].topic, 'Pandas');

    await c.setFillTopics(false);
    expect({for (final e in c.entries) e.topic}, {''});
    expect({for (final r in c.rows) r.topic}, {''});
  });

  test('only some groups; remembered for next time', () async {
    final c = await controller();
    await c.setPicked('Базы данных', true, groups: ['ИСТ-23']);
    await c.savePlan('Базы данных|Лабораторная', const [PlanTopic('SQL', 3)]);
    await c.setFillTopics(false);
    expect([
      for (final e in c.entries) e.groups
    ], [
      for (var i = 0; i < 8; i++) ['ИСТ-23'],
    ]);
    expect(c.entries.first.lesson.type, 'Лабораторная');

    final again = await controller();
    expect(again.isPicked('Базы данных', 'ИСТ-23'), isTrue);
    expect(again.isPicked(_ml, 'ИСТ-310'), isFalse);
    expect(again.plan('Базы данных|Лабораторная'), const [PlanTopic('SQL', 3)]);
    expect(again.fillTopics, isFalse);
    expect(again.planSlots, {'Базы данных|Лабораторная': 8});
  });

  test('plans from an earlier report: only disciplines taught now', () async {
    final c = await controller();
    final n = await c.importPlans({
      '$_ml|Практика': const [PlanTopic('Pandas для МО', 4)],
      'История|Лекция': const [PlanTopic('Древний мир')],
    });
    expect(n, 1);
    expect(c.plan('$_ml|Практика'), const [PlanTopic('Pandas для МО', 4)]);
    expect(c.plan('История|Лекция'), isEmpty);
  });

  test('the finished report', () async {
    final c = await controller(months: [DateTime(2026, 3)]);
    await c.setPicked(_ml, true);
    await c.saveHeader(const HourlyHeader(
        teacherPost: 'ст. преподаватель',
        teacherName: 'Смирнов Сергей Сергеевич',
        signerPost: 'Зав. кафедрой ИТ',
        signerName: 'А.Б. Иванова'));
    expect(c.header.missing, isEmpty);
    final docx = await c.buildDocx();
    expect(plansFromReport(docx), isEmpty, reason: 'no topics yet');
    expect(docx.length, greaterThan(1000));
  });
}
