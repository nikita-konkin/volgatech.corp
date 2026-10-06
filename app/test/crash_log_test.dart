import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:volgatech_pro/core/crash_log.dart';
import 'package:volgatech_pro/core/prefs.dart';
import 'package:volgatech_pro/ui/crash_log_page.dart';

Future<CrashLog> _log() async {
  SharedPreferences.setMockInitialValues({});
  return CrashLog(await Prefs.load(), platform: 'android')
    ..version = '0.5.2+14';
}

StackTrace _at(String where) => StackTrace.fromString(
    '#0      $where (package:volgatech_pro/ui/x.dart:12:5)\n'
    '#1      main (package:volgatech_pro/main.dart:40:3)\n');

void main() {
  test('errors are kept across launches, newest first', () async {
    final log = await _log();
    log
      ..record(StateError('первая'), _at('a'), at: DateTime.utc(2026, 10, 1))
      ..record(StateError('вторая'), _at('b'), at: DateTime.utc(2026, 10, 2));
    await Future<void>.delayed(Duration.zero);

    final again = CrashLog(await Prefs.load());
    expect(again.entries.map((e) => e.title),
        ['Bad state: вторая', 'Bad state: первая']);
    expect(again.entries.first.version, '0.5.2+14');
    expect(again.entries.first.stack, contains('x.dart:12:5'));
  });

  test('the same error again counts up and comes to the top', () async {
    final log = await _log();
    log
      ..record(StateError('та же'), _at('a'))
      ..record(StateError('другая'), _at('b'))
      ..record(StateError('та же'), _at('a'));
    expect(log.entries.map((e) => (e.title, e.count)),
        [('Bad state: та же', 2), ('Bad state: другая', 1)]);
    // The same words from somewhere else are another error.
    log.record(StateError('та же'), _at('c'));
    expect(log.entries, hasLength(3));
  });

  test('only the last ones are kept', () async {
    final log = await _log();
    for (var i = 0; i < CrashLog.limit + 5; i++) {
      log.record(StateError('$i'), _at('f$i'));
    }
    expect(log.entries, hasLength(CrashLog.limit));
    expect(log.entries.first.title, 'Bad state: ${CrashLog.limit + 4}');
  });

  test('a report carries no addresses, tokens or ids', () {
    const jwt = 'eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxIn0.c2lnbmF0dXJl';
    expect(
        scrubReport('GET /person/1234567/photo for ivanov.ii@volgatech.net '
            'with Bearer abc.def and $jwt failed at x.dart:123:45, v0.5.2'),
        'GET /person/<число>/photo for <почта> with Bearer <токен> and '
        '<токен> failed at x.dart:123:45, v0.5.2');
  });

  test('a long message is cut, a long stack trimmed', () async {
    final log = await _log()
      ..record(
          'x' * 5000,
          StackTrace.fromString(
              [for (var i = 0; i < 60; i++) '#$i f'].join('\n')));
    expect(log.entries.single.error.length, lessThan(1100));
    expect(log.entries.single.stack.split('\n'), hasLength(20));
  });

  test('the report names the version and how often', () async {
    final log = await _log()
      ..record(StateError('сломалось'), _at('a'),
          at: DateTime.utc(2026, 10, 3, 9))
      ..record(StateError('сломалось'), _at('a'),
          at: DateTime.utc(2026, 10, 3, 9));
    final report = log.report();
    expect(report,
        startsWith('Волгатех.Коллектив 0.5.2+14 · android\nОшибок: 1\n'));
    expect(report,
        contains('2026-10-03T09:00:00 · 0.5.2+14 · ×2\nBad state: сломалось'));
  });

  test('once installed, it hears both kinds of error and passes them on',
      () async {
    final log = await _log();
    final flutterBefore = FlutterError.onError;
    final platformBefore = PlatformDispatcher.instance.onError;
    final passedOn = <String>[];
    FlutterError.onError = (d) => passedOn.add('flutter');
    PlatformDispatcher.instance.onError = (e, s) {
      passedOn.add('platform');
      return true;
    };
    try {
      log.install();
      FlutterError.onError!(FlutterErrorDetails(
          exception: StateError('в построении'), stack: _at('build')));
      final handled = PlatformDispatcher.instance.onError!(
          StateError('потерянная'), _at('f'));
      expect(handled, isTrue);
      expect(passedOn, ['flutter', 'platform']);
      expect(log.entries.map((e) => e.title),
          ['Bad state: потерянная', 'Bad state: в построении']);
    } finally {
      FlutterError.onError = flutterBefore;
      PlatformDispatcher.instance.onError = platformBefore;
    }
  });

  group('in Settings', () {
    Future<CrashLog> pump(WidgetTester tester, {int errors = 0}) async {
      final log = await _log();
      for (var i = 0; i < errors; i++) {
        log.record(StateError('ошибка $i'), _at('f$i'));
      }
      await tester.pumpWidget(ChangeNotifierProvider.value(
        value: log,
        child: const MaterialApp(
          locale: Locale('ru'),
          supportedLocales: [Locale('ru')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: Scaffold(body: CrashLogTile()),
        ),
      ));
      await tester.pump();
      return log;
    }

    testWidgets('none yet', (tester) async {
      await pump(tester);
      expect(find.text('Ошибок не было'), findsOneWidget);
      await tester.tap(find.text('Отчёты об ошибках'));
      await tester.pumpAndSettle();
      expect(find.text('Ошибок не было'), findsOneWidget);
      expect(find.text('Скопировать'), findsNothing);
    });

    testWidgets('read, copied and cleared', (tester) async {
      String? copied;
      tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      });
      final log = await pump(tester, errors: 3);
      expect(find.text('3 ошибки — посмотреть и отправить разработчику'),
          findsOneWidget);

      await tester.tap(find.text('Отчёты об ошибках'));
      await tester.pumpAndSettle();
      expect(find.text('Bad state: ошибка 2'), findsOneWidget);
      await tester.tap(find.text('Bad state: ошибка 2'));
      await tester.pumpAndSettle();
      expect(find.textContaining('x.dart:12:5'), findsOneWidget);

      await tester.tap(find.text('Скопировать'));
      await tester.pump();
      expect(copied, log.report());
      expect(find.textContaining('Отчёт скопирован'), findsOneWidget);

      await tester.tap(find.byTooltip('Очистить'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Очистить'));
      await tester.pumpAndSettle();
      expect(log.entries, isEmpty);
      expect(find.text('Ошибок не было'), findsOneWidget);
    });
  });
}
