import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:volgatech_pro/core/crash_log.dart';
import 'package:volgatech_pro/core/prefs.dart';
import 'package:volgatech_pro/mail/mail_alerts.dart';
import 'package:volgatech_pro/mail/mail_background.dart';
import 'package:volgatech_pro/mail/mail_background_settings.dart';
import 'package:volgatech_pro/ui/crash_log_page.dart';
import 'package:volgatech_pro/ui/mail_alert_tile.dart';

/// Supplies device restrictions and records requests to open system settings.
class _Settings implements MailBackgroundSettings {
  _Settings({this.hasAppLaunch = true, this.ignoresBattery = false});

  final bool hasAppLaunch;
  bool ignoresBattery;
  final opened = <String>[];

  @override
  Future<({bool hasAppLaunch, bool canRequestBatteryExemption})>
      status() async => (
            hasAppLaunch: hasAppLaunch,
            canRequestBatteryExemption: hasAppLaunch && !ignoresBattery,
          );

  @override
  Future<bool> openAppLaunch() async {
    opened.add('app launch');
    return true;
  }

  @override
  Future<bool> requestBatteryExemption() async {
    opened.add('battery');
    return true;
  }
}

Future<void> _pump(
  WidgetTester tester,
  _Settings settings, {
  bool enabled = true,
  DateTime? last,
  int minutes = 15,
}) async {
  SharedPreferences.setMockInitialValues({'mail_notify': enabled});
  final prefs = await Prefs.load();
  await prefs.setMailCheckMinutes(minutes);
  if (last != null) await prefs.setMailLastBackgroundCheck(last);
  await tester.pumpWidget(
    ChangeNotifierProvider(
      create: (_) =>
          MailAlerts(prefs, LocalMailAlerts(), BackgroundMailCheck(prefs)),
      child:
          MaterialApp(home: Scaffold(body: MailAlertTile(settings: settings))),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('A short interval shows the Android idle warning',
      (tester) async {
    await _pump(tester, _Settings(hasAppLaunch: false), minutes: 10);

    expect(
        find.text('Android может проверять реже, пока телефон не используется'),
        findsOneWidget,
        reason: 'The short interval did not show the idle warning');
  });

  testWidgets('Enabled notifications show when no checks have completed',
      (tester) async {
    await _pump(tester, _Settings(hasAppLaunch: false));
    expect(
      find.text('Последняя проверка в фоне: ещё не было'),
      findsOneWidget,
      reason: 'The setting did not explain that no check had completed',
    );
  });

  testWidgets('The saved check time is shown in local time', (tester) async {
    await _pump(tester, _Settings(), last: DateTime(2026, 9, 23, 17, 36));
    expect(
      find.text('Последняя проверка в фоне: 23.09.2026, 17:36'),
      findsOneWidget,
      reason: 'The setting did not show the saved local date and time',
    );
  });

  testWidgets('Disabled notifications dont show background check details',
      (tester) async {
    await _pump(tester, _Settings(), enabled: false);
    expect(
      find.textContaining(RegExp('Последняя проверка в фоне|Запуск приложений|'
          'Отключить экономию батареи')),
      findsNothing,
      reason: 'Disabled notifications should not show background check details',
    );
  });

  testWidgets('Other manufacturers dont get Honor and Huawei actions',
      (tester) async {
    await _pump(tester, _Settings(hasAppLaunch: false));
    expect(
      find.textContaining(
          RegExp('Запуск приложений|Отключить экономию батареи')),
      findsNothing,
      reason:
          'Unsupported devices should not show manufacturer-specific actions',
    );
  });

  testWidgets(
      'Affected phones explain what happens when the app is swiped away',
      (tester) async {
    await _pump(tester, _Settings(ignoresBattery: true));
    expect(
      find.textContaining('смахнуть'),
      findsOneWidget,
      reason: 'Affected phones did not explain why the checks can stop',
    );
  });

  testWidgets('The two actions open their corresponding Android settings',
      (tester) async {
    final settings = _Settings();
    await _pump(tester, settings);
    await tester.tap(find.text('Открыть «Запуск приложений»'));
    await tester.tap(find.text('Отключить экономию батареи'));
    expect(
      settings.opened,
      ['app launch', 'battery'],
      reason: 'The buttons did not open the corresponding Android settings',
    );
  });

  testWidgets('The battery action disappears after the system grants exemption',
      (tester) async {
    final settings = _Settings();
    await _pump(tester, settings);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    settings.ignoresBattery = true;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(
      find.text('Отключить экономию батареи'),
      findsNothing,
      reason: 'An exempt app should not keep asking for a battery exemption',
    );
  });

  testWidgets('The last check updates when the app returns to the foreground',
      (tester) async {
    await _pump(tester, _Settings(hasAppLaunch: false));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    final prefs = await Prefs.load();
    await prefs.setMailLastBackgroundCheck(DateTime(2026, 11, 6, 8, 51));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(
      find.text('Последняя проверка в фоне: 06.11.2026, 08:51'),
      findsOneWidget,
      reason: 'Returning to settings did not pick up the new check time',
    );
  });

  testWidgets('Error reports pick up background entries without an app restart',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await Prefs.load();
    final foreground = CrashLog(prefs);
    await CrashLog(prefs)
        .add('Фоновая проверка почты не удалась: обрыв связи', null);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: foreground,
        child: const MaterialApp(home: Scaffold(body: CrashLogTile())),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('1 ошибка'),
      findsOneWidget,
      reason: 'The reports tile did not pick up the saved background error',
    );
  });
}
