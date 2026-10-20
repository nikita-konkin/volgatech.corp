import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:volgatech_pro/core/prefs.dart';
import 'package:volgatech_pro/core/session.dart';
import 'package:volgatech_pro/data/volgatech_api.dart';
import 'package:volgatech_pro/models/schedule.dart';
import 'package:volgatech_pro/state/auth_controller.dart';
import 'package:volgatech_pro/state/memo_controller.dart';
import 'package:volgatech_pro/ui/hourly_load_page.dart';

import 'fakes.dart';

void main() {
  setUpAll(() => initializeDateFormatting('ru_RU'));

  testWidgets('pick a discipline, give it topics, or leave them empty',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    final prefs = await Prefs.load();
    // Classes in the month shown alone, so the plan starts there.
    final shown = MemoController.defaultMonth(DateTime.now());
    final api = FakeApi()
      ..onSchedule = (first) async => [
            if (first == shown)
              for (final d in [3, 10])
                day(DateTime(first.year, first.month, d), [
                  const ScheduleEvent(
                    timeBegin: '08:00:00',
                    description: 'Машинное обучение и анализ данных',
                    fullDescription: 'ИСТ-310',
                    typeWorkName: 'Практические',
                    category: 'TimeTable',
                  ),
                  const ScheduleEvent(
                    timeBegin: '09:45:00',
                    description: 'Физика',
                    fullDescription: 'ИСТ-23',
                    typeWorkName: 'Лекции',
                    category: 'TimeTable',
                  ),
                ]),
          ];
    final auth = AuthController(api, Session(), FakeCache())..personId = 7;
    addTearDown(auth.dispose);

    await tester.pumpWidget(MultiProvider(
      providers: [
        Provider<VolgatechApi>.value(value: api),
        Provider<Prefs>.value(value: prefs),
        ChangeNotifierProvider<AuthController>.value(value: auth),
      ],
      child: const MaterialApp(home: HourlyLoadPage()),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Выбрать дисциплины'), findsOneWidget);

    await tester.tap(find.text('Выбрать дисциплины'));
    await tester.pumpAndSettle();
    expect(find.text('Физика'), findsOneWidget);
    await tester.tap(find.text('Машинное обучение и анализ данных'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('2 занятия · 4 ч.'), findsOneWidget);
    expect(find.text('Практика · Машинное обучение и анализ данных'),
        findsNWidgets(2));
    expect(find.text('Тема не указана'), findsNWidgets(2));

    // A plan pasted in: the first topic for both classes.
    await tester.tap(find.byTooltip('Темы занятий'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Вставить список'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byType(TextField), 'Pandas для МО ×2\nСтатистика');
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();
    expect(find.text('Pandas для МО'), findsOneWidget);
    expect(find.text('× 2'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Pandas для МО'), findsNWidgets(2));

    // «Не заполнять»: the column is left for the teacher.
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(find.text('Pandas для МО'), findsNothing);
    expect(find.textContaining('Колонка останется пустой'), findsOneWidget);

    // Any months: February and April.
    await tester.tap(find.byIcon(Icons.arrow_drop_down));
    await tester.pumpAndSettle();
    expect(find.byType(FilterChip), findsNWidgets(12));
    expect(tester.takeException(), isNull);
  });
}
