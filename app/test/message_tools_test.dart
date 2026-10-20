import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:volgatech_pro/core/prefs.dart';
import 'package:volgatech_pro/mail/compose.dart';
import 'package:volgatech_pro/mail/mail_controller.dart';
import 'package:volgatech_pro/mail/mail_credentials.dart';
import 'package:volgatech_pro/mail/mail_text.dart';
import 'package:volgatech_pro/mail/ui/compose_page.dart';
import 'package:volgatech_pro/mail/ui/message_tools.dart';

import 'fakes.dart';
import 'mail_controller_test.dart' show FakeMailService;

void main() {
  setUpAll(() => initializeDateFormatting('ru_RU'));

  late Prefs prefs;
  late MailController mail;
  String? clipboard;
  final intents = <MethodCall>[];

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    prefs = await Prefs.load();
    mail = MailController(
        service: FakeMailService(),
        store: MailCredentialStore(),
        cache: FakeCache());
    clipboard = null;
    intents.clear();
    // No other apps in a test: none takes what's handed over.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('volgatech/text'),
            (call) async {
      intents.add(call);
      return false;
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        clipboard = (call.arguments as Map)['text'] as String?;
      }
      return null;
    });
  });

  Future<void> sheet(WidgetTester tester, MailLink link) async {
    await tester.pumpWidget(MultiProvider(
      providers: [
        Provider<Prefs>.value(value: prefs),
        ChangeNotifierProvider<MailController>.value(value: mail),
      ],
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () =>
                    showLinkSheet(context, link, subject: 'Защита практики'),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('a link whose text names another site: warned, then copied',
      (tester) async {
    await sheet(tester,
        linkFor('https://volgatech-net.example/login', 'volgatech.net'));
    expect(
        find.textContaining('Так выглядят фишинговые письма'), findsOneWidget);
    expect(find.text('Открыть в браузере'), findsOneWidget);
    expect(find.text('Копировать текст ссылки'), findsOneWidget);
    await tester.tap(find.text('Копировать ссылку'));
    await tester.pumpAndSettle();
    expect(clipboard, 'https://volgatech-net.example/login');
    expect(find.text('Ссылка скопирована'), findsOneWidget);
  });

  testWidgets('a meeting: join', (tester) async {
    await sheet(tester, linkFor('https://telemost.yandex.ru/j/1', 'Встреча'));
    expect(find.text('Телемост'), findsOneWidget);
    expect(find.text('Присоединиться'), findsOneWidget);
    expect(find.text('Открыть в браузере'), findsNothing);
  });

  testWidgets('a phone number: call, SMS, copy as written', (tester) async {
    final b = prepareBody(text: 'тел. 68-60-00 доб. 12');
    await sheet(tester, b.links.single);
    expect(find.text('+7 8362 68-60-00 доб. 12'), findsOneWidget);
    expect(find.text('Позвонить'), findsOneWidget);
    expect(find.text('Добавочный наберётся после соединения'), findsOneWidget);
    expect(find.text('Написать SMS'), findsOneWidget);
    await tester.tap(find.text('Копировать номер'));
    await tester.pumpAndSettle();
    expect(clipboard, '+7 8362 68-60-00 доб. 12');
  });

  testWidgets('an address: a new message to it, here', (tester) async {
    await sheet(tester,
        linkFor('mailto:dean@volgatech.net?subject=Справка', 'Деканат'));
    expect(find.text('dean@volgatech.net'), findsOneWidget);
    await tester.tap(find.text('Написать'));
    await tester.pumpAndSettle();
    expect(find.byType(ComposePage), findsOneWidget);
    expect(find.text('dean@volgatech.net'), findsWidgets);
    expect(find.text('Справка'), findsOneWidget);
  });

  testWidgets('a date: into the calendar, for the day', (tester) async {
    final b = prepareBody(text: 'Защита 14 октября 2026 г.');
    await sheet(tester, b.links.single);
    expect(find.text('14 октября 2026'), findsOneWidget);
    expect(find.text('Добавить в календарь'), findsOneWidget);
    expect(find.text('На весь день'), findsOneWidget);
    await tester.tap(find.text('Добавить в календарь'));
    await tester.pumpAndSettle();
    expect(intents.single.method, 'addEvent');
    final args = intents.single.arguments as Map;
    expect(args['title'], 'Защита практики');
    expect(args['allDay'], isTrue);
    expect(args['begin'], DateTime.utc(2026, 10, 14).millisecondsSinceEpoch);
    expect(args['end'], DateTime.utc(2026, 10, 15).millisecondsSinceEpoch);
    expect(find.text('На телефоне нет подходящего приложения'), findsOneWidget);
  });

  testWidgets('templates: one put where the cursor is, the list edited',
      (tester) async {
    await tester.pumpWidget(MultiProvider(
      providers: [
        Provider<Prefs>.value(value: prefs),
        ChangeNotifierProvider<MailController>.value(value: mail),
      ],
      child: MaterialApp(home: ComposePage(draft: ComposeDraft())),
    ));
    await tester.tap(find.byTooltip('Шаблоны'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Принято, сделаю.'));
    await tester.pumpAndSettle();
    final body = tester.widget<TextField>(find.byType(TextField).last);
    expect(body.controller!.text, startsWith('Принято, сделаю.'));

    await tester.tap(find.byTooltip('Шаблоны'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Изменить'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Удалить шаблон').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Добавить шаблон'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byType(TextField).last, 'Жду отчёт до пятницы.');
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();
    expect(prefs.mailTemplates, [
      ...kDefaultMailTemplates.skip(1),
      'Жду отчёт до пятницы.',
    ]);
  });
}
