// The web build in a browser on a computer: from kWideLayout on the menu
// stays open beside the screens, which keep their state and a readable
// width; the arrows of the keyboard work as the ones on the screen do.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:volgatech_pro/state/auth_controller.dart';
import 'package:volgatech_pro/ui/app_drawer.dart';
import 'package:volgatech_pro/ui/home_shell.dart';
import 'package:volgatech_pro/ui/layout.dart';
import 'package:volgatech_pro/ui/login_page.dart';

import 'screens_harness.dart';

const windows = [
  Size(800, 600),
  Size(1024, 700),
  Size(1280, 800),
  Size(1920, 1080),
];

void main() {
  setUpAll(setUpScreens);

  final desktop = TargetPlatformVariant.only(TargetPlatform.macOS);

  Future<void> open(WidgetTester tester, Size size, Widget home,
      {AuthStatus status = AuthStatus.authenticated,
      bool computer = true}) async {
    debugDesktopBrowser = computer;
    addTearDown(() => debugDesktopBrowser = null);
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = size;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(await screensApp(home, status: status));
    await settle(tester);
  }

  /// The day the schedule shows, as its date bar has it.
  String dayBar(DateTime day) =>
      DateFormat('d MMMM', 'ru_RU').format(day).toUpperCase();
  final today = DateTime.now();
  DateTime plus(int days) =>
      DateTime(today.year, today.month, today.day + days);

  Finder menuItem(String title) =>
      find.descendant(of: find.byType(NavMenu), matching: find.text(title));

  /// Opens [title] from the menu: from the drawer in a narrow window.
  Future<void> go(WidgetTester tester, String title) async {
    if (find.byType(NavMenu).evaluate().isEmpty) {
      tester.state<ScaffoldState>(find.byType(Scaffold).first).openDrawer();
      await settle(tester);
    }
    await tester.scrollUntilVisible(menuItem(title), 80,
        scrollable: find
            .descendant(
                of: find.byType(NavMenu), matching: find.byType(Scrollable))
            .first);
    await tester.tap(menuItem(title));
    await settle(tester);
  }

  for (final size in windows) {
    final wide = size.width >= kWideLayout;
    final name = '${size.width.toInt()}×${size.height.toInt()}';

    testWidgets('$name: every screen fits, no wider than it reads',
        (tester) async {
      await open(tester, size, const LoginPage(),
          status: AuthStatus.unauthenticated);
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(TextFormField).first).width,
          lessThanOrEqualTo(440));

      await open(tester, size, const HomeShell());
      // The menu: beside the schedule, or in its drawer.
      expect(find.byType(NavMenu), wide ? findsOneWidget : findsNothing);
      expect(find.byTooltip('Обновить'), findsOneWidget);
      final time = tester.getTopLeft(find.text('09:45 - 09:45'));
      final room = tester.getTopRight(find.text('333г (III)').at(1));
      expect(room.dx - time.dx, lessThanOrEqualTo(kReadableWidth));

      await tester.tap(find.byTooltip('Обзор недели'));
      await settle(tester);
      expect(find.byTooltip('Следующая неделя'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'Обзор недели');
      await tester.tap(find.byType(BackButton));
      await settle(tester);

      for (final (item, shows) in [
        ('Расписание экзаменов', 'Проектирование систем'),
        ('Иностранные группы', 'ИСТ-110'),
        ('Профиль', 'Константинопольский'),
        ('Настройки', 'Тема оформления'),
      ]) {
        await go(tester, item);
        expect(find.textContaining(shows), findsWidgets, reason: item);
        expect(tester.takeException(), isNull, reason: item);
        if (!wide) {
          await tester.tap(find.byType(BackButton));
          await settle(tester);
        }
      }
      await closeScreens(tester);
    }, variant: desktop);
  }

  testWidgets('beside the menu every screen stays as it was left',
      (tester) async {
    await open(tester, const Size(1280, 800), const HomeShell());
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await settle(tester);
    expect(find.text(dayBar(plus(1))), findsOneWidget);

    await go(tester, 'Иностранные группы');
    final before = tester
        .widgetList<Text>(find.textContaining(RegExp(r'\d{4}$')))
        .map((t) => t.data)
        .toSet();
    // Opened for the first time, and it already has the keyboard.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await settle(tester);

    // Back to the schedule: the same day, and the keyboard still works.
    await go(tester, 'Расписание занятий');
    expect(find.text(dayBar(plus(1))), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await settle(tester);
    expect(find.text(dayBar(plus(2))), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await settle(tester);
    expect(find.text(dayBar(plus(1))), findsOneWidget);

    // And the memo: still the next month.
    await go(tester, 'Иностранные группы');
    final after = tester
        .widgetList<Text>(find.textContaining(RegExp(r'\d{4}$')))
        .map((t) => t.data)
        .toSet();
    expect(after, isNot(before));
    await closeScreens(tester);
  }, variant: desktop);

  testWidgets('«Сегодня»: shown away from today, and back', (tester) async {
    await open(tester, const Size(1280, 800), const HomeShell());
    expect(find.byTooltip('Сегодня'), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await settle(tester);
    expect(find.text(dayBar(plus(2))), findsOneWidget);
    await tester.tap(find.byTooltip('Сегодня'));
    await settle(tester);
    expect(find.text(dayBar(today)), findsOneWidget);
    expect(find.byTooltip('Сегодня'), findsNothing);

    // The Home key does the same; in the overview, by the week.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await settle(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.home);
    await settle(tester);
    expect(find.text(dayBar(today)), findsOneWidget);
    await tester.tap(find.byTooltip('Обзор недели'));
    await settle(tester);
    expect(find.byTooltip('Сегодня'), findsNothing);
    await tester.tap(find.byTooltip('Следующая неделя'));
    await settle(tester);
    await tester.tap(find.byTooltip('Сегодня'));
    await settle(tester);
    expect(find.byTooltip('Сегодня'), findsNothing);
    expect(find.text('сегодня'), findsOneWidget); // today's card is back
    await closeScreens(tester);
  }, variant: desktop);

  testWidgets('the menu item of the open screen goes back to its start',
      (tester) async {
    await open(tester, const Size(1280, 800), const HomeShell());
    await tester.tap(find.byTooltip('Обзор недели'));
    await settle(tester);
    expect(find.text('Обзор недели'), findsOneWidget);

    await go(tester, 'Расписание занятий');
    expect(find.text('Обзор недели'), findsNothing);
    expect(find.text('Расписание занятий'), findsWidgets);
    await closeScreens(tester);
  }, variant: desktop);

  testWidgets('the week overview: its arrows and the keyboard change the week',
      (tester) async {
    await open(tester, const Size(1280, 800), const HomeShell());
    await tester.tap(find.byTooltip('Обзор недели'));
    await settle(tester);

    String range() =>
        tester.widget<Text>(find.textContaining(RegExp(r' – ')).first).data!;
    final week = range();
    await tester.tap(find.byTooltip('Следующая неделя'));
    await settle(tester);
    final next = range();
    expect(next, isNot(week));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await settle(tester);
    expect(range(), week);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await settle(tester);
    expect(range(), next);
    await tester.tap(find.byTooltip('Предыдущая неделя'));
    await settle(tester);
    expect(range(), week);

    // Side by side: Monday and Tuesday on one row.
    expect(tester.getTopLeft(find.text('Понедельник')).dy,
        tester.getTopLeft(find.text('Вторник')).dy);
    await closeScreens(tester);
  }, variant: desktop);

  testWidgets('on a phone: no buttons for a mouse', (tester) async {
    await open(tester, const Size(390, 844), const HomeShell(),
        computer: false);
    expect(find.byType(NavMenu), findsNothing);
    expect(find.byTooltip('Обновить'), findsNothing);
    await tester.tap(find.byTooltip('Обзор недели'));
    await settle(tester);
    expect(find.byTooltip('Следующая неделя'), findsNothing);
    // One day under another.
    expect(tester.getTopLeft(find.text('Понедельник')).dy,
        lessThan(tester.getTopLeft(find.text('Вторник')).dy));
    await closeScreens(tester);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
}
