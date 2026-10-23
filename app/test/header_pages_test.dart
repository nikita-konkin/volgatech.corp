import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:volgatech_pro/core/prefs.dart';
import 'package:volgatech_pro/core/session.dart';
import 'package:volgatech_pro/data/volgatech_api.dart';
import 'package:volgatech_pro/state/auth_controller.dart';
import 'package:volgatech_pro/theme.dart';
import 'package:volgatech_pro/ui/foreign_memo_page.dart';
import 'package:volgatech_pro/ui/hourly_load_page.dart';

import 'fakes.dart';

void main() {
  setUpAll(() => initializeDateFormatting('ru_RU'));

  /// [home] in the web's plain theme (no glass: a blue bar); pumped again
  /// from scratch, as a reload of the page, it reads what was saved.
  Future<void> open(WidgetTester tester, Widget home) async {
    final api = FakeApi()..onSchedule = (_) async => [];
    final auth = AuthController(api, Session(), FakeCache())..personId = 7;
    addTearDown(auth.dispose);
    final prefs = await Prefs.load();
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(MultiProvider(
      providers: [
        Provider<VolgatechApi>.value(value: api),
        Provider<Prefs>.value(value: prefs),
        ChangeNotifierProvider<AuthController>.value(value: auth),
      ],
      child: MaterialApp(theme: buildLightTheme(browser: true), home: home),
    ));
    await tester.pumpAndSettle();
  }

  Color? saveColour(WidgetTester tester) => tester
      .widget<TextButton>(find.widgetWithText(TextButton, 'Сохранить'))
      .style
      ?.foregroundColor
      ?.resolve({});

  Future<void> leaveByBackAndReload(WidgetTester tester, Widget home,
      {required String tooltip,
      required String field,
      required String typed}) async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    await open(tester, home);
    await tester.tap(find.byTooltip(tooltip));
    await tester.pumpAndSettle();
    // Seen on the blue bar, not the theme's blue on it.
    expect(saveColour(tester), Colors.white);

    await tester.enterText(find.widgetWithText(TextField, field), typed);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await open(tester, home);
    await tester.tap(find.byTooltip(tooltip));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, typed), findsOneWidget);
    expect(tester.takeException(), isNull);
  }

  testWidgets('the hourly header is kept when left by «назад»',
      (tester) async {
    await leaveByBackAndReload(tester, const HourlyLoadPage(),
        tooltip: 'Шапка и подпись',
        field: 'И.О. Фамилия',
        typed: 'А.Б. Петрова');
  });

  testWidgets('the memo header is kept when left by «назад»', (tester) async {
    await leaveByBackAndReload(tester, const ForeignMemoPage(),
        tooltip: 'Шапка и подписи',
        field: 'Фамилия И.О. (кому)',
        typed: 'Петровой А.Б.');
  });
}
