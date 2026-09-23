import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:volgatech_pro/core/foreign_memo.dart';
import 'package:volgatech_pro/core/memo_docx.dart';
import 'package:volgatech_pro/core/prefs.dart';
import 'package:volgatech_pro/models/profile.dart';
import 'package:volgatech_pro/models/schedule.dart';
import 'package:volgatech_pro/state/memo_controller.dart';

import 'fakes.dart';

ScheduleEvent _class(String begin, String group) => ScheduleEvent(
      timeBegin: '$begin:00',
      description: 'Информационные технологии в отрасли инфокоммуникаций',
      fullDescription: group,
      typeWorkName: 'Лекции',
      room: '414',
      category: 'TimeTable',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => initializeDateFormatting('ru_RU'));

  final today = DateTime(2026, 10, 5); // early October -> September's memo
  final sept = DateTime(2026, 9);

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

  Future<MemoController> controller() async {
    final c = MemoController(
      api: api,
      personId: 7,
      prefs: prefs,
      profile: profile,
      today: today,
      loadTemplate: () async => File(kMemoTemplateAsset).readAsBytesSync(),
    );
    await c.load();
    return c;
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await Prefs.load();
    api = FakeApi()
      ..onSchedule = (first) async => first == sept
          ? [
              day(DateTime(2026, 9, 1),
                  [_class('08:00', 'ИСТ-110'), _class('09:45', 'ИСТ-23')]),
              day(DateTime(2026, 9, 3), [_class('11:30', 'ИСТ-210')]),
            ]
          : [
              day(DateTime(2026, 10, 6), [_class('08:00', 'ИСТ-410')]),
            ];
  });

  test('the previous month is the default during the first ten days', () {
    expect(MemoController.defaultMonth(DateTime(2026, 10, 5)), sept);
    expect(MemoController.defaultMonth(DateTime(2026, 10, 11)),
        DateTime(2026, 10));
    expect(
        MemoController.defaultMonth(DateTime(2027, 1, 3)), DateTime(2026, 12));
  });

  test('loads the whole month in one request and keeps foreign classes',
      () async {
    final c = await controller();
    expect(api.scheduleCalls, [sept]);
    expect([for (final e in c.entries) e.row.groups.single],
        ['ИСТ-110', 'ИСТ-210']);
    expect(c.totalHours, 4);
    expect(c.monthLabel, 'сентябрь 2026');
    expect(c.fileName, 'Иностр студенты сентябрь 2026.docx');
  });

  test('the header starts from the profile', () async {
    final c = await controller();
    expect(c.header.teacherName, 'Смирнов Сергей Сергеевич');
    expect(c.header.teacherPost, 'ст. преподаватель');
    expect(c.header.departmentDative, 'Кафедре информационных технологий');
    expect(c.header.missing, ['адресат', 'подписывающий']);
  });

  test('unticked classes, short names and the header are remembered', () async {
    final c = await controller();
    await c.setIncluded(c.entries.first, false);
    await c.renameDiscipline(
        'Информационные технологии в отрасли инфокоммуникаций',
        'Информационные технологии в отрасли');
    await c.saveHeader(c.header.copyWith(addresseeName: 'Иванову И.И.'));

    final again = await controller();
    expect([for (final e in again.entries) e.included], [false, true]);
    expect(again.memoRows.single.discipline,
        'Информационные технологии в отрасли');
    expect(again.totalHours, 2);
    expect(again.header.addresseeName, 'Иванову И.И.');
  });

  test('hand-added classes belong to their month', () async {
    final c = await controller();
    await c.addManual(MemoRow(
      date: DateTime(2026, 9, 29),
      time: '10:00',
      groups: const ['ИСТ-110'],
      discipline: 'Замена',
      type: 'лекция',
      manual: true,
    ));
    expect(c.entries.last.row.manual, isTrue);
    expect(c.totalHours, 6);

    await c.nextMonth();
    expect([for (final e in c.entries) e.row.groups.single], ['ИСТ-410']);
    await c.prevMonth();
    expect(c.entries.where((e) => e.row.manual), hasLength(1));

    await c.removeManual(c.entries.last.row);
    expect(c.totalHours, 4);
  });

  test('a slow answer for a month the user already left is dropped', () async {
    final slowSept = Completer<List<ScheduleDay>>();
    api.onSchedule = (first) => first == sept
        ? slowSept.future
        : Future.value([
            day(DateTime(2026, 10, 6), [_class('08:00', 'ИСТ-410')]),
          ]);
    final c = MemoController(
      api: api,
      personId: 7,
      prefs: prefs,
      today: today,
      loadTemplate: () async => File(kMemoTemplateAsset).readAsBytesSync(),
    );
    final sep = c.load();
    await c.nextMonth();
    slowSept.complete([
      day(DateTime(2026, 9, 1), [_class('08:00', 'ИСТ-110')]),
    ]);
    await sep;
    expect([for (final e in c.entries) e.row.groups.single], ['ИСТ-410']);
    expect(c.loading, isFalse);
  });

  test('builds the .docx from the included classes', () async {
    final c = await controller();
    await c.setIncluded(c.entries.last, false);
    final bytes = await c.buildDocx();
    expect(bytes.length, greaterThan(10000));
  });
}
