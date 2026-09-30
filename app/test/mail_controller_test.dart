import 'dart:convert';
import 'dart:typed_data';

import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:volgatech_pro/core/prefs.dart';
import 'package:volgatech_pro/mail/compose.dart';
import 'package:volgatech_pro/mail/ews_client.dart' show EwsException;
import 'package:volgatech_pro/mail/mail_badge.dart';
import 'package:volgatech_pro/mail/mail_controller.dart';
import 'package:volgatech_pro/mail/mail_credentials.dart';
import 'package:volgatech_pro/mail/mail_models.dart';
import 'package:volgatech_pro/mail/mail_service.dart';
import 'package:volgatech_pro/mail/ui/compose_page.dart';
import 'package:volgatech_pro/mail/ui/mail_page.dart' as ui;
import 'package:volgatech_pro/mail/ui/message_tile.dart' show sizeTint;
import 'package:volgatech_pro/mail/ui/signature_page.dart';

import 'fakes.dart';

const _inbox =
    MailFolder(name: 'Inbox', path: 'id-inbox', role: FolderRole.inbox);
const _trash =
    MailFolder(name: 'Удаленные', path: 'id-trash', role: FolderRole.trash);

MailHeader _h(int n, {bool seen = false, bool pinned = false, int? size}) =>
    MailHeader(
      id: 'msg$n',
      seq: 5 - n,
      fromName: 'Отправитель $n',
      fromEmail: 'user$n@volgatech.net',
      subject: 'Письмо $n',
      date: DateTime(2026, 9, n),
      seen: seen,
      pinned: pinned,
      size: size ?? n * 1024,
    );

/// In-memory Exchange: accepts one login/password pair.
class FakeMailService implements MailService {
  FakeMailService({this.acceptedLogin = r'MARSTU\konkinna'});

  final String acceptedLogin;
  bool down = false;
  final tried = <String>[];
  final seenOnServer = <String>{};
  final deleted = <String, String>{};
  final sent = <String>[];
  final pinnedFirstAsked = <bool>[];
  List<MailHeader> inbox = [for (var i = 1; i <= 5; i++) _h(i)];
  bool connected = false;

  @override
  Future<void> connect(MailCredentials c) async {
    tried.add(c.login);
    if (down) throw const MailNetworkException('down');
    if (c.login != acceptedLogin || c.password != 'secret') {
      throw const MailAuthException();
    }
    connected = true;
  }

  void _check() {
    if (down || !connected) throw const MailNetworkException('down');
  }

  @override
  Future<List<MailFolder>> folders() async {
    _check();
    return [_inbox.withUnseen(await inboxUnread()), _trash];
  }

  @override
  Future<List<MailHeader>> search(MailFolder f, String query,
      {int count = 50}) async {
    _check();
    return [
      for (final h in inbox.reversed)
        if (h.subject.contains(query)) h
    ];
  }

  @override
  Future<int> inboxUnread() async {
    _check();
    return inbox.where((h) => !seenOnServer.contains(h.id) && !h.seen).length;
  }

  @override
  Future<MailPage> headers(MailFolder f,
      {int? before, int count = 40, bool pinnedFirst = true}) async {
    _check();
    pinnedFirstAsked.add(pinnedFirst);
    final list = f == _inbox ? inbox.reversed.toList() : <MailHeader>[];
    return MailPage(list, hasMore: false);
  }

  @override
  Future<MimeMessage> message(MailFolder f, String id) async {
    _check();
    return MessageBuilder.buildSimpleTextMessage(
        const MailAddress('Отправитель', 'a@volgatech.net'),
        const [MailAddress('Я', 'me@volgatech.net')],
        'Текст письма $id',
        subject: 'Письмо $id');
  }

  @override
  Future<void> setSeen(MailFolder f, String id, {required bool seen}) async {
    _check();
    seen ? seenOnServer.add(id) : seenOnServer.remove(id);
  }

  final moved = <String, String>{};

  @override
  Future<void> move(MailFolder f, String id, MailFolder to) async {
    _check();
    moved[id] = to.path;
    inbox.removeWhere((h) => h.id == id);
  }

  @override
  Future<void> delete(MailFolder f, String id) async {
    _check();
    deleted[id] = f.path;
    inbox.removeWhere((h) => h.id == id);
  }

  @override
  Future<void> send(Uint8List mime) async {
    _check();
    if (rejectSend) throw const EwsException('Mailbox quota exceeded');
    sent.add(utf8.decode(mime));
  }

  bool rejectSend = false;

  AutoReply autoReplySet = const AutoReply(message: 'Я в отпуске.');

  int? quota;
  int recoverable = 0;

  @override
  Future<MailboxUsage> usage() async {
    _check();
    return MailboxUsage(
        used: 3 * 1024 * 1024,
        quota: quota,
        recoverable: recoverable,
        folders: [
          const FolderUsage(_inbox, size: 2 * 1024 * 1024, count: 5),
          const FolderUsage(_trash, size: 1024 * 1024, count: 21),
        ]);
  }

  @override
  Future<AutoReply> autoReply() async {
    _check();
    return autoReplySet;
  }

  @override
  Future<void> setAutoReply(AutoReply reply) async {
    _check();
    autoReplySet = reply;
  }

  final directory = const [
    MailAddress('Орлов Антон Дмитриевич', 'OrlovAD@volgatech.net'),
    MailAddress('Орлова Мария Сергеевна', 'OrlovaMS@volgatech.net'),
    MailAddress('Петрова Анна', 'PetrovaA@volgatech.net'),
  ];
  final searched = <String>[];
  String? webSig;

  @override
  Future<String?> webSignature() async {
    _check();
    return webSig;
  }

  @override
  Future<List<MailAddress>> searchDirectory(String query) async {
    _check();
    searched.add(query);
    return [
      for (final a in directory)
        if (a.personalName!.toLowerCase().startsWith(query.toLowerCase())) a
    ];
  }

  @override
  Future<void> disconnect() async => connected = false;
}

void main() {
  late FakeMailService server;
  late FakeCache cache;
  late MailCredentialStore store;

  MailController controller() =>
      MailController(service: server, store: store, cache: cache);

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    server = FakeMailService();
    cache = FakeCache();
    store = MailCredentialStore();
  });

  test('login: always MARSTU\name, one attempt', () {
    expect(loginCandidates(' konkinna '), [r'MARSTU\konkinna']);
    expect(loginCandidates('KonkinNA@volgatech.net'), [r'MARSTU\KonkinNA']);
    expect(loginCandidates(r'OTHER\konkinna'), [r'OTHER\konkinna']);
    expect(loginCandidates('  '), isEmpty);
  });

  test('without a saved password the form is shown', () async {
    final c = controller();
    await c.start();
    expect(c.status, MailStatus.signedOut);
    expect(server.tried, isEmpty);
  });

  test('sign-in finds the login format Exchange accepts and remembers it',
      () async {
    final c = controller();
    await c.start();
    expect(await c.signIn('konkinna', 'secret'), isTrue);
    expect(server.tried, [r'MARSTU\konkinna']);
    expect(c.status, MailStatus.ready);
    expect([for (final h in c.headers) h.id],
        ['msg5', 'msg4', 'msg3', 'msg2', 'msg1']);
    expect(c.folders.first, _inbox); // inbox first, then the rest
    final saved = await store.read();
    expect(saved?.login, r'MARSTU\konkinna');
    expect(saved?.password, 'secret');
  });

  test('a wrong password leaves nothing stored', () async {
    final c = controller();
    await c.start();
    expect(await c.signIn('konkinna', 'wrong'), isFalse);
    expect(c.status, MailStatus.signedOut);
    expect(c.error, isA<MailAuthException>());
    expect(await store.read(), isNull);
  });

  test('offline: the saved list is shown with the offline state', () async {
    await store.save(const MailCredentials(r'MARSTU\konkinna', 'secret'));
    cache.seed('mail_inbox', [_h(9, seen: true).toJson()], DateTime.now());
    server.down = true;
    final c = controller();
    await c.start();
    expect(c.status, MailStatus.offline);
    expect([for (final h in c.headers) h.id], ['msg9']);

    server.down = false;
    await c.refresh();
    expect(c.status, MailStatus.ready);
    expect(c.headers, hasLength(5));
  });

  test('a changed password sends the user back to the form', () async {
    await store.save(const MailCredentials(r'MARSTU\konkinna', 'old'));
    final c = controller();
    await c.start();
    expect(c.status, MailStatus.signedOut);
    expect(await store.read(), isNull);
  });

  test('opening marks read; delete moves to the trash folder', () async {
    final c = controller();
    await c.start();
    await c.signIn('konkinna', 'secret');
    final first = c.headers.first;

    final msg = await c.open(first);
    expect(msg.decodeTextPlainPart(), contains('Текст письма msg5'));
    await Future<void>.delayed(Duration.zero);
    expect(c.headers.first.seen, isTrue);
    expect(server.seenOnServer, {'msg5'});

    await c.markUnread(c.headers.first);
    expect(c.headers.first.seen, isFalse);
    expect(server.seenOnServer, isEmpty);

    await c.delete(c.headers.first);
    expect(server.deleted, {'msg5': 'id-inbox'});
    expect([for (final h in c.headers) h.id], ['msg4', 'msg3', 'msg2', 'msg1']);
  });

  test('sending goes through the service as MIME', () async {
    final c = controller();
    await c.start();
    await c.signIn('konkinna', 'secret');
    await c.send(ComposeDraft(
        to: 'ivanov@volgatech.net', subject: 'Проверка', text: 'Привет'));
    expect(server.sent.single, contains('ivanov@volgatech.net'));
  });

  test('a dropped connection is re-established once', () async {
    final c = controller();
    await c.start();
    await c.signIn('konkinna', 'secret');
    server.connected = false; // server closed the idle connection
    final msg = await c.open(c.headers.first);
    expect(msg, isNotNull);
    expect(server.tried.last, r'MARSTU\konkinna');
  });

  test('signing out forgets the password and the saved letters', () async {
    final c = controller();
    await c.start();
    await c.signIn('konkinna', 'secret');
    await Future<void>.delayed(Duration.zero);
    expect(cache.json.keys, contains('mail_inbox'));

    await c.signOut();
    expect(c.status, MailStatus.signedOut);
    expect(await store.read(), isNull);
    expect(cache.json.keys.where((k) => k.startsWith('mail_')), isEmpty);
    expect(server.connected, isFalse);
  });

  testWidgets('pinned messages come first, under a header that folds',
      (tester) async {
    await initializeDateFormatting('ru_RU');
    SharedPreferences.setMockInitialValues({});
    final prefs = await Prefs.load();
    await store.save(const MailCredentials(r'MARSTU\konkinna', 'secret'));
    // Newest first on screen: 5, 4, 3, 2, 1; 2 and 4 are pinned.
    server.inbox = [for (var i = 1; i <= 5; i++) _h(i, pinned: i.isEven)];
    await tester.pumpWidget(Provider<Prefs>.value(
      value: prefs,
      child: MaterialApp(home: ui.MailPage(create: (_) => controller())),
    ));
    await tester.pumpAndSettle();

    double y(String text) => tester.getTopLeft(find.text(text)).dy;
    expect(find.text('Закреплённые · 2'), findsOneWidget);
    expect(find.text('5 КБ'), findsOneWidget); // message size
    expect(y('Письмо 4'), lessThan(y('Письмо 2')));
    expect(y('Письмо 2'), lessThan(y('Письмо 5'))); // pinned block first
    expect(y('Письмо 3'), lessThan(y('Письмо 1')));

    await tester.tap(find.text('Закреплённые · 2'));
    await tester.pumpAndSettle();
    expect(find.text('Письмо 4'), findsNothing);
    expect(find.text('Письмо 5'), findsOneWidget);
    expect(prefs.mailPinsFolded, isTrue);

    // Switched off in the menu: plain date order, and it sticks.
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Закреплённые сверху'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Закреплённые ·'), findsNothing);
    expect(y('Письмо 5'), lessThan(y('Письмо 4')));
    expect(y('Письмо 4'), lessThan(y('Письмо 3')));
    expect(prefs.mailPinnedFirst, isFalse);
    expect(server.pinnedFirstAsked.last, isFalse);
  });

  testWidgets('big messages are tinted by size; the menu turns it off',
      (tester) async {
    await initializeDateFormatting('ru_RU');
    SharedPreferences.setMockInitialValues({});
    final prefs = await Prefs.load();
    await store.save(const MailCredentials(r'MARSTU\konkinna', 'secret'));
    const big = 12 * 1024 * 1024;
    server.inbox = [_h(1), _h(2, size: big)];
    await tester.pumpWidget(Provider<Prefs>.value(
      value: prefs,
      child: MaterialApp(home: ui.MailPage(create: (_) => controller())),
    ));
    await tester.pumpAndSettle();

    Color? row(String subject) => tester
        .widget<Material>(find
            .ancestor(of: find.text(subject), matching: find.byType(Material))
            .first)
        .color;
    expect(row('Письмо 1'), Colors.transparent);
    expect(row('Письмо 2'), sizeTint(big, dark: false));

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Цвет по размеру'));
    await tester.pumpAndSettle();
    expect(row('Письмо 2'), Colors.transparent);
    expect(prefs.mailSizeColors, isFalse);
  });

  test('address book: suggestions, and none offline', () async {
    await store.save(const MailCredentials(r'MARSTU\konkinna', 'secret'));
    final c = controller();
    await c.start();
    expect([for (final a in await c.searchDirectory('орл')) a.email],
        ['OrlovAD@volgatech.net', 'OrlovaMS@volgatech.net']);
    server.down = true;
    expect(await c.searchDirectory('орл'), isEmpty);
    expect(c.status, MailStatus.ready); // a failed lookup isn't «offline»
  });

  testWidgets('«Кому» suggests people from the address book', (tester) async {
    await store.save(const MailCredentials(r'MARSTU\konkinna', 'secret'));
    final c = controller();
    await c.start();
    SharedPreferences.setMockInitialValues({});
    final prefs = await Prefs.load();
    final draft = ComposeDraft(to: 'a@volgatech.net, ');
    await tester.pumpWidget(MultiProvider(
      providers: [
        Provider<Prefs>.value(value: prefs),
        ChangeNotifierProvider.value(value: c),
      ],
      child: MaterialApp(home: ComposePage(draft: draft)),
    ));
    final to = find.byType(TextField).first;

    await tester.enterText(to, 'a@volgatech.net, ка'); // too short
    await tester.pump(const Duration(milliseconds: 400));
    expect(server.searched, isEmpty);

    await tester.enterText(to, 'a@volgatech.net, орл');
    await tester.pump(const Duration(milliseconds: 400));
    expect(server.searched, ['орл']);
    expect(find.text('OrlovaMS@volgatech.net'), findsOneWidget);
    expect(find.text('PetrovaA@volgatech.net'), findsNothing);

    await tester.tap(find.text('Орлова Мария Сергеевна'));
    await tester.pump();
    expect(tester.widget<TextField>(to).controller!.text,
        'a@volgatech.net, Орлова Мария Сергеевна <OrlovaMS@volgatech.net>, ');
    expect(find.text('OrlovAD@volgatech.net'), findsNothing);
  });

  testWidgets('signature: the web mail\'s is offered, then signs new mail',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await Prefs.load();
    await store.save(const MailCredentials(r'MARSTU\konkinna', 'secret'));
    final c = controller();
    await c.start();
    server.webSig = 'С уважением, Конкин Н.А.';
    Widget app(Widget home) => MultiProvider(
          providers: [
            Provider<Prefs>.value(value: prefs),
            ChangeNotifierProvider.value(value: c),
          ],
          child: MaterialApp(home: home),
        );

    await tester.pumpWidget(app(const SignaturePage()));
    await tester.pumpAndSettle();
    expect(find.text('С уважением, Конкин Н.А.'), findsOneWidget);
    expect(prefs.mailSignature, 'С уважением, Конкин Н.А.');

    // Once saved, the web mail isn't asked again: the user's text stays.
    await tester.enterText(find.byType(TextField), 'Конкин Н.А.');
    await tester.pumpWidget(app(const SizedBox()));
    await tester.pumpWidget(app(const SignaturePage()));
    await tester.pumpAndSettle();
    expect(find.text('Конкин Н.А.'), findsOneWidget);

    await tester.pumpWidget(app(ComposePage(draft: ComposeDraft())));
    TextField field(int i) =>
        tester.widget<TextField>(find.byType(TextField).at(i));
    expect(field(2).controller!.text, '\n\nКонкин Н.А.'); // Кому, Тема, текст

    // Switched off for new mail: none.
    await prefs.setMailSignNew(false);
    await tester.pumpWidget(app(const SizedBox()));
    await tester.pumpWidget(app(ComposePage(draft: ComposeDraft())));
    expect(field(2).controller!.text, '');
  });

  test('swipe delete: undo brings it back, otherwise the server deletes',
      () async {
    await store.save(const MailCredentials(r'MARSTU\konkinna', 'secret'));
    final c = controller();
    await c.start();
    final third = c.headers[2];
    c.deleteSoon(third, delay: const Duration(milliseconds: 20));
    expect(c.headers.map((h) => h.id), isNot(contains(third.id)));
    c.undoDelete();
    expect(c.headers[2].id, third.id); // back in its place
    await Future<void>.delayed(const Duration(milliseconds: 40));
    expect(server.deleted, isEmpty);

    c.deleteSoon(third, delay: const Duration(milliseconds: 20));
    await c.refresh(); // the server still has it: stays hidden
    expect(c.headers.map((h) => h.id), isNot(contains(third.id)));
    await Future<void>.delayed(const Duration(milliseconds: 40));
    expect(server.deleted.keys, [third.id]);

    // Leaving the screen doesn't cancel one still counting down.
    final first = c.headers.first;
    c.deleteSoon(first);
    c.dispose();
    await Future<void>.delayed(Duration.zero);
    expect(server.deleted.keys, contains(first.id));
  });

  testWidgets('swiping a message left deletes it, «Отменить» restores it',
      (tester) async {
    await initializeDateFormatting('ru_RU');
    SharedPreferences.setMockInitialValues({});
    final prefs = await Prefs.load();
    await store.save(const MailCredentials(r'MARSTU\konkinna', 'secret'));
    await tester.pumpWidget(Provider<Prefs>.value(
      value: prefs,
      child: MaterialApp(home: ui.MailPage(create: (_) => controller())),
    ));
    await tester.pumpAndSettle();

    await tester.drag(find.text('Письмо 3'), const Offset(-600, 0));
    await tester.pumpAndSettle();
    expect(find.text('Письмо 3'), findsNothing);
    expect(find.text('Письмо перемещено в «Удалённые»'), findsOneWidget);
    await tester.tap(find.text('Отменить'));
    await tester.pumpAndSettle();
    expect(find.text('Письмо 3'), findsOneWidget);

    await tester.drag(find.text('Письмо 3'), const Offset(-600, 0));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(server.deleted.keys, ['msg3']);
    expect(find.text('Письмо 3'), findsNothing);
  });

  testWidgets('swiping right marks read / unread and keeps the message',
      (tester) async {
    await initializeDateFormatting('ru_RU');
    SharedPreferences.setMockInitialValues({});
    final prefs = await Prefs.load();
    await store.save(const MailCredentials(r'MARSTU\konkinna', 'secret'));
    await tester.pumpWidget(Provider<Prefs>.value(
      value: prefs,
      child: MaterialApp(home: ui.MailPage(create: (_) => controller())),
    ));
    await tester.pumpAndSettle();

    await tester.drag(find.text('Письмо 3'), const Offset(600, 0));
    await tester.pumpAndSettle();
    expect(find.text('Письмо 3'), findsOneWidget);
    expect(server.seenOnServer, contains('msg3'));

    await tester.drag(find.text('Письмо 3'), const Offset(600, 0));
    await tester.pumpAndSettle();
    expect(server.seenOnServer, isNot(contains('msg3')));
    expect(server.deleted, isEmpty);
  });

  test('back in the app: reloads only a list that is not fresh', () async {
    await store.save(const MailCredentials(r'MARSTU\konkinna', 'secret'));
    final c = controller();
    await c.start();
    final loads = server.pinnedFirstAsked.length;
    await c.refreshIfStale();
    expect(server.pinnedFirstAsked.length, loads);
    await c.refreshIfStale(maxAge: Duration.zero);
    expect(server.pinnedFirstAsked.length, loads + 1);
  });

  test('unread count: reported as messages are read, marked and deleted',
      () async {
    await store.save(const MailCredentials(r'MARSTU\konkinna', 'secret'));
    final reported = <int>[];
    final c = MailController(
        service: server,
        store: store,
        cache: cache,
        onInboxUnread: reported.add);
    await c.start();
    expect(reported.last, 5);
    await c.open(c.headers.first);
    expect(reported.last, 4);
    await c.markUnread(c.headers.first);
    expect(reported.last, 5);
    await c.markRead(c.headers.first);
    c.deleteSoon(c.headers[1], delay: const Duration(hours: 1));
    expect(reported.last, 3);
    c.undoDelete();
    expect(reported.last, 4);
    expect(c.folderWith(FolderRole.inbox)!.unseen, 4);
    await c.signOut();
    expect(reported.last, 0);
  });

  group('menu badge', () {
    late Prefs prefs;
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await Prefs.load();
    });

    MailBadge badge() =>
        MailBadge(prefs: prefs, store: store, service: () => server);

    test('counts the inbox, remembers it, and checks at most so often',
        () async {
      await store.save(const MailCredentials(r'MARSTU\konkinna', 'secret'));
      final b = badge();
      await b.check();
      expect(b.unread, 5);
      expect(prefs.mailUnread, 5);
      server.seenOnServer.add('msg1');
      await b.check(); // too soon
      expect(b.unread, 5);
      await b.check(force: true);
      expect(b.unread, 4);
      expect(badge().unread, 4); // straight from preferences at start-up
    });

    test('offline keeps the last count; a rejected password is forgotten',
        () async {
      await store.save(const MailCredentials(r'MARSTU\konkinna', 'secret'));
      final b = badge();
      await b.check();
      server.down = true;
      await b.check(force: true);
      expect(b.unread, 5);
      server.down = false;
      await store.save(const MailCredentials(r'MARSTU\konkinna', 'old'));
      await b.check(force: true);
      expect(b.unread, 0);
      expect(await store.read(), isNull);
      server.tried.clear();
      await b.check(force: true);
      expect(server.tried, isEmpty); // no further attempts
    });

    test('no mail password: no badge, no server', () async {
      final b = badge();
      await b.check();
      expect(b.unread, 0);
      expect(server.tried, isEmpty);
    });
  });

  testWidgets('search: results for what is typed, «Ничего не найдено»',
      (tester) async {
    await initializeDateFormatting('ru_RU');
    SharedPreferences.setMockInitialValues({});
    final prefs = await Prefs.load();
    await store.save(const MailCredentials(r'MARSTU\konkinna', 'secret'));
    await tester.pumpWidget(Provider<Prefs>.value(
      value: prefs,
      child: MaterialApp(home: ui.MailPage(create: (_) => controller())),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Поиск'));
    await tester.pumpAndSettle();
    expect(find.text('Отправитель, тема или слова из письма'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'мо 3');
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
    expect(find.text('Письмо 3'), findsOneWidget);
    expect(find.text('Письмо 4'), findsNothing);

    await tester.enterText(find.byType(TextField), 'нет такого');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(find.text('Ничего не найдено'), findsOneWidget);
  });

  test('undo send: taken back, sent after the delay, or the error', () async {
    await store.save(const MailCredentials(r'MARSTU\konkinna', 'secret'));
    final c = controller();
    await c.start();
    ComposeDraft draft() =>
        ComposeDraft(to: 'a@volgatech.net', subject: 'Тест', text: 'Привет');

    final taken = c.sendSoon(draft(), delay: const Duration(hours: 1));
    expect(c.cancelSend()!.subject, 'Тест');
    expect(await taken, same(sendCancelled));
    expect(server.sent, isEmpty);
    expect(c.cancelSend(), isNull);

    expect(await c.sendSoon(draft(), delay: Duration.zero), isNull);
    expect(server.sent, hasLength(1));

    server.rejectSend = true;
    final failed = await c.sendSoon(draft(), delay: Duration.zero);
    expect('$failed', contains('Mailbox quota exceeded'));
    server.rejectSend = false;

    // Leaving the mail screen sends the one still waiting.
    final waiting = c.sendSoon(draft(), delay: const Duration(hours: 1));
    c.dispose();
    expect(await waiting, isNull);
    expect(server.sent, hasLength(2));
  });

  testWidgets('compose: undo send, and what is left unsent comes back',
      (tester) async {
    await initializeDateFormatting('ru_RU');
    SharedPreferences.setMockInitialValues({});
    final prefs = await Prefs.load();
    await store.save(const MailCredentials(r'MARSTU\konkinna', 'secret'));
    await tester.pumpWidget(Provider<Prefs>.value(
      value: prefs,
      child: MaterialApp(home: ui.MailPage(create: (_) => controller())),
    ));
    await tester.pumpAndSettle();
    Finder field(int i) => find.byType(TextField).at(i); // Кому, Тема, текст

    // Left unsent: kept, and «Написать» brings it back.
    await tester.tap(find.byTooltip('Написать'));
    await tester.pumpAndSettle();
    await tester.enterText(field(1), 'Черновик');
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Черновик сохранён — он откроется в «Написать»'),
        findsOneWidget);
    expect((prefs.mailDraft as Map)['subject'], 'Черновик');
    await tester.tap(find.byTooltip('Написать'));
    await tester.pumpAndSettle();
    expect(find.text('Восстановлен несохранённый черновик'), findsOneWidget);
    expect(find.text('Черновик'), findsOneWidget);

    // Sent, then taken back within the few seconds.
    await tester.enterText(field(0), 'a@volgatech.net');
    await tester.tap(find.byTooltip('Отправить'));
    await tester.pumpAndSettle();
    expect(prefs.mailDraft, isNull);
    expect(find.text('Письмо отправляется…'), findsOneWidget);
    await tester.tap(find.text('Отменить'));
    await tester.pumpAndSettle();
    expect(find.text('Черновик'), findsOneWidget); // back in compose
    expect(server.sent, isEmpty);

    // Sent for real once the notice is gone.
    await tester.tap(find.byTooltip('Отправить'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 6));
    expect(server.sent, hasLength(1));
    // «Отправляется…» closes by itself, then «отправлено» follows.
    await tester.pumpAndSettle();
    expect(find.text('Письмо отправляется…'), findsNothing);
    expect(find.text('Письмо отправлено'), findsOneWidget);
  });

  testWidgets('«Автоответ»: loads what is set, switches it on for dates',
      (tester) async {
    await initializeDateFormatting('ru_RU');
    SharedPreferences.setMockInitialValues({});
    final prefs = await Prefs.load();
    await store.save(const MailCredentials(r'MARSTU\konkinna', 'secret'));
    await tester.pumpWidget(Provider<Prefs>.value(
      value: prefs,
      child: MaterialApp(home: ui.MailPage(create: (_) => controller())),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Автоответ'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Отправлять автоответы'));
    await tester.pumpAndSettle();
    expect(find.text('Я в отпуске.'), findsOneWidget); // what was set
    await tester.tap(find.text('Только в эти дни'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'В отпуске до 10.10.');
    await tester.tap(find.byTooltip('Сохранить'));
    await tester.pumpAndSettle();

    final r = server.autoReplySet;
    expect(r.state, AutoReplyState.scheduled);
    expect(r.message, 'В отпуске до 10.10.');
    expect(r.end!.difference(r.start!), const Duration(days: 8));
    expect(find.text('Автоответ включён'), findsOneWidget);
  });

  test('move: off the list, unread counted in the other folder', () async {
    await store.save(const MailCredentials(r'MARSTU\konkinna', 'secret'));
    final c = controller();
    await c.start();
    final h = c.headers.first;
    final trash = c.folderWith(FolderRole.trash)!;
    await c.move(h, trash);
    expect(server.moved, {h.id: trash.path});
    expect(c.headers.map((x) => x.id), isNot(contains(h.id)));
    expect(c.folderWith(FolderRole.inbox)!.unseen, 4);
    expect(c.folderWith(FolderRole.trash)!.unseen, 1);
  });

  testWidgets('«Размер ящика»: used, folders, and the limit when known',
      (tester) async {
    await initializeDateFormatting('ru_RU');
    SharedPreferences.setMockInitialValues({});
    final prefs = await Prefs.load();
    await store.save(const MailCredentials(r'MARSTU\konkinna', 'secret'));
    await tester.pumpWidget(Provider<Prefs>.value(
      value: prefs,
      child: MaterialApp(home: ui.MailPage(create: (_) => controller())),
    ));
    await tester.pumpAndSettle();
    Future<void> openSize() async {
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Размер ящика'));
      await tester.pumpAndSettle();
    }

    await openSize();
    expect(find.text('3,0 МБ  занято'), findsOneWidget);
    expect(find.text('Удалённые'), findsOneWidget);
    expect(find.text('21 письмо'), findsOneWidget);
    expect(find.textContaining('Лимит виден в веб-почте'), findsOneWidget);

    server.quota = 4 * 1024 * 1024;
    await tester.pageBack();
    await tester.pumpAndSettle();
    await openSize();
    expect(find.text('3,0 МБ  из 4,0 МБ'), findsOneWidget);
    expect(find.text('Свободно 1,0 МБ'), findsOneWidget);
  });

  test('mailbox size: known after connecting, remembered for next time',
      () async {
    await store.save(const MailCredentials(r'MARSTU\konkinna', 'secret'));
    server.quota = 4 * 1024 * 1024;
    final c = controller();
    await c.start();
    await Future<void>.delayed(Duration.zero);
    expect(c.usageSummary?.used, 3 * 1024 * 1024);
    expect(c.usageSummary?.quota, 4 * 1024 * 1024);

    server.down = true; // next start, offline: the remembered one
    final again = controller();
    await again.start();
    expect(again.usageSummary?.quota, 4 * 1024 * 1024);
  });

  testWidgets('a limit typed in when the server keeps it to itself',
      (tester) async {
    await initializeDateFormatting('ru_RU');
    SharedPreferences.setMockInitialValues({});
    final prefs = await Prefs.load();
    await store.save(const MailCredentials(r'MARSTU\konkinna', 'secret'));
    server.recoverable = 2 * 1024 * 1024;
    await tester.pumpWidget(Provider<Prefs>.value(
      value: prefs,
      child: MaterialApp(
          home: ui.MailPage(
              create: (_) => MailController(
                  service: server,
                  store: store,
                  cache: cache,
                  manualQuota: prefs.mailQuota))),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('3,0 МБ занято')); // no limit: no bar
    await tester.pumpAndSettle();
    expect(find.textContaining('Не входят в лимит: 2,0 МБ'), findsOneWidget);

    await tester.tap(find.text('Указать лимит'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Сохранить')); // nothing typed
    await tester.pumpAndSettle();
    expect(find.text('Число мегабайт, например 512'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '4');
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();
    expect(find.text('3,0 МБ  из 4,0 МБ'), findsOneWidget);
    expect(find.text('Свободно 1,0 МБ'), findsOneWidget);
    expect(find.text('Лимит указан вручную'), findsOneWidget);
    expect(prefs.mailQuota, 4 * 1024 * 1024);

    // The top bar has the bar now.
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('3 из 4 МБ'), findsOneWidget);

    // Changed, then taken away.
    await tester.tap(find.text('3 из 4 МБ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Изменить'));
    await tester.pumpAndSettle();
    expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text, '4');
    await tester.tap(find.text('Убрать'));
    await tester.pumpAndSettle();
    expect(find.text('Указать лимит'), findsOneWidget);
    expect(prefs.mailQuota, isNull);

    // The server's own limit, when it tells, wins over a typed one.
    server.quota = 8 * 1024 * 1024;
    await tester.tap(find.text('Указать лимит'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '4');
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Размер ящика'));
    await tester.pumpAndSettle();
    expect(find.text('3,0 МБ  из 8,0 МБ'), findsOneWidget);
    expect(find.text('Лимит указан вручную'), findsNothing);
  });

  testWidgets('the limit bar sits in the top bar and opens «Размер ящика»',
      (tester) async {
    // A narrow phone: the title, the bar, search and the menu must fit.
    tester.view
      ..physicalSize = const Size(360 * 3, 740 * 3)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await initializeDateFormatting('ru_RU');
    SharedPreferences.setMockInitialValues({});
    final prefs = await Prefs.load();
    await store.save(const MailCredentials(r'MARSTU\konkinna', 'secret'));
    server.quota = 4 * 1024 * 1024;
    await tester.pumpWidget(Provider<Prefs>.value(
      value: prefs,
      child: MaterialApp(home: ui.MailPage(create: (_) => controller())),
    ));
    await tester.pumpAndSettle();
    expect(find.text('3 из 4 МБ'), findsOneWidget);
    expect(
        find.descendant(
            of: find.byType(AppBar),
            matching: find.byType(LinearProgressIndicator)),
        findsOneWidget);
    await tester.tap(find.text('3 из 4 МБ'));
    await tester.pumpAndSettle();
    expect(find.text('Свободно 1,0 МБ'), findsOneWidget);
  });
}
