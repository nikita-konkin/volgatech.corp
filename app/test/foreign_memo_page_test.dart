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
import 'package:volgatech_pro/ui/foreign_memo_page.dart';

import 'fakes.dart';

void main() {
  setUpAll(() => initializeDateFormatting('ru_RU'));

  testWidgets('lists the month’s foreign classes and counts only ticked ones',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    final prefs = await Prefs.load();
    final api = FakeApi()
      ..onSchedule = (first) async => [
            day(DateTime(first.year, first.month, 2), [
              const ScheduleEvent(
                timeBegin: '08:00:00',
                description: 'Введение в инженерную деятельность',
                fullDescription: 'ИСТ-110',
                typeWorkName: 'Практические',
                category: 'TimeTable',
              ),
              const ScheduleEvent(
                timeBegin: '09:45:00',
                description: 'Физика',
                fullDescription: 'ИСТ-23', // regular group: not listed
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
      child: const MaterialApp(home: ForeignMemoPage()),
    ));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.textContaining('ИСТ-110'), findsOneWidget);
    expect(find.textContaining('ИСТ-23'), findsNothing);
    expect(find.text('Введение в инженерную деятельность'), findsOneWidget);
    expect(find.text('1 занятие · 2 ч.'), findsOneWidget);

    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    expect(find.text('0 занятий · 0 ч.'), findsOneWidget);
  });
}
