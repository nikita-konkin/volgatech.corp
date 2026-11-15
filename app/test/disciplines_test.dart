import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:volgatech_pro/core/session.dart';
import 'package:volgatech_pro/data/volgatech_api.dart';
import 'package:volgatech_pro/models/schedule.dart';
import 'package:volgatech_pro/state/auth_controller.dart';
import 'package:volgatech_pro/state/disciplines_controller.dart';
import 'package:volgatech_pro/ui/disciplines_page.dart';
import 'package:volgatech_pro/ui/widgets/copy_text.dart';

import 'fakes.dart';

ScheduleEvent _class(String subject, String group, String type) =>
    ScheduleEvent(
      timeBegin: '08:00:00',
      description: subject,
      fullDescription: group,
      typeWorkName: type,
      category: 'TimeTable',
    );

/// Every month of the autumn semester 2026/27 has the same two classes;
/// any other month, Физика alone.
FakeApi _api() => FakeApi()
  ..onSchedule = (first) async => [
        if ((first.year == 2026 && first.month >= 9) ||
            (first.year == 2027 && first.month == 1))
          day(DateTime(first.year, first.month, 5), [
            _class('Системы искусственного интеллекта', 'ИСТ-43', 'Лекции'),
            _class('Базы данных', 'ИСТ-23 (подгруппа 1)', 'Лабораторные'),
          ])
        else
          day(DateTime(first.year, first.month, 5),
              [_class('Физика', 'ИСТ-13', 'Практические')]),
      ];

void main() {
  setUpAll(() => initializeDateFormatting('ru_RU'));

  test('the semester of today, its disciplines by name, and the next ones',
      () async {
    final api = _api();
    final c = DisciplinesController(api, 7, today: DateTime(2027, 1, 20));
    addTearDown(c.dispose);
    expect(c.label, 'Осенний семестр 2026/27');

    await c.load();
    expect(api.scheduleCalls, [
      for (var m = 9; m <= 13; m++) DateTime(2026, m),
    ]);
    expect(c.courses.map((e) => e.discipline),
        ['Базы данных', 'Системы искусственного интеллекта']);
    expect(c.courses.first.groups.keys, ['ИСТ-23']);
    expect(c.courses.first.typeSummary(), 'лабораторные 5');
    expect(c.namesText, 'Базы данных\nСистемы искусственного интеллекта');

    await c.shift(1);
    expect(c.label, 'Весенний семестр 2027');
    expect(c.namesText, 'Физика');
    await c.shift(-2);
    expect(c.label, 'Весенний семестр 2026');
    await c.shift(1);
    expect(c.label, 'Осенний семестр 2026/27');
    expect(c.courses, hasLength(2), reason: 'kept from the first load');
  });

  testWidgets('one name or all of them goes to the clipboard', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied = (call.arguments as Map)['text'] as String?;
      }
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));

    final api = _api();
    final auth = AuthController(api, Session(), FakeCache())..personId = 7;
    addTearDown(auth.dispose);
    await tester.pumpWidget(MultiProvider(
      providers: [
        Provider<VolgatechApi>.value(value: api),
        ChangeNotifierProvider<AuthController>.value(value: auth),
      ],
      child: const MaterialApp(home: DisciplinesPage()),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // Whatever semester today is in, its own disciplines are shown; move to
    // the autumn one with two.
    while (find.text('ОСЕННИЙ СЕМЕСТР 2026/27').evaluate().isEmpty) {
      final now = DateTime.now();
      await tester.tap(find.byTooltip(now.isAfter(DateTime(2027, 2))
          ? 'Предыдущий семестр'
          : 'Следующий семестр'));
      await tester.pumpAndSettle();
    }
    expect(find.text('ИСТ-23\nлабораторные 5'), findsOneWidget);
    expect(find.textContaining('2 дисциплины'), findsOneWidget);

    await tester.tap(find.byTooltip('Копировать все названия'));
    await tester.pump();
    expect(copied, 'Базы данных\nСистемы искусственного интеллекта');
    expect(find.text('Скопировано: 2 дисциплины'), findsOneWidget);

    await tester.longPress(find.text('Системы искусственного интеллекта'));
    await tester.pump();
    expect(copied, 'Системы искусственного интеллекта');
    expect(find.text('Название скопировано'), findsOneWidget);
  });

  testWidgets('a held card gives its name', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied = (call.arguments as Map)['text'] as String?;
      }
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));

    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: CopyOnHold(
          text: '  Физика ',
          child: SizedBox(width: 200, height: 80, child: Text('карточка')),
        ),
      ),
    ));
    await tester.longPress(find.text('карточка'));
    await tester.pump();
    expect(copied, 'Физика');
    expect(find.text('Название скопировано'), findsOneWidget);
  });
}
