import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:volgatech_pro/core/prefs.dart';
import 'package:volgatech_pro/mail/ews_mail_service.dart';
import 'package:volgatech_pro/mail/mail_alerts.dart';
import 'package:volgatech_pro/mail/mail_credentials.dart';
import 'package:volgatech_pro/mail/mail_models.dart';

import 'mail_controller_test.dart' show FakeMailService;

class _Alerts implements MailAlertPlatform {
  bool allow = true;
  final shown = <List<String>>[];
  int cleared = 0;

  @override
  Future<bool> requestPermission() async => allow;

  @override
  Future<void> show(List<MailHeader> fresh) async =>
      shown.add([for (final h in fresh) h.subject]);

  @override
  Future<void> clear() async => cleared++;
}

class _Schedule implements MailCheckSchedule {
  bool? running;

  @override
  Future<void> start() async => running = true;

  @override
  Future<void> stop() async => running = false;
}

MailHeader _mail(String subject, DateTime date, {bool seen = false}) =>
    MailHeader(
      id: subject,
      seq: 0,
      fromName: 'Отправитель',
      fromEmail: 'user@volgatech.net',
      subject: subject,
      date: date,
      seen: seen,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final t0 = DateTime.utc(2026, 10, 6, 9);
  DateTime at(int minutes) => t0.add(Duration(minutes: minutes));

  late Prefs prefs;
  late MailCredentialStore store;
  late FakeMailService service;
  late _Alerts alerts;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    prefs = await Prefs.load();
    store = MailCredentialStore();
    await store.save(const MailCredentials(r'MARSTU\konkinna', 'secret'));
    service = FakeMailService();
    alerts = _Alerts();
  });

  Future<void> check() => checkForNewMail(
      prefs: prefs, store: store, service: service, alerts: alerts);

  test('freshMail: unread and later only, newest first', () {
    expect(
        freshMail([
          _mail('старое', at(-5)),
          _mail('прочитанное', at(3), seen: true),
          _mail('новое', at(1)),
          _mail('новее', at(2)),
          _mail('ровно тогда', at(0)),
        ], t0)
            .map((h) => h.subject),
        ['новее', 'новое']);
  });

  test('the first check notes where «new» begins and tells of nothing',
      () async {
    service.inbox = [_mail('давнее', at(0))];
    await check();
    expect(alerts.shown, isEmpty);
    expect(prefs.mailSeenUntil, at(0));
  });

  test('later checks tell of each new unread message once', () async {
    await prefs.setMailSeenUntil(at(0));
    service.inbox = [
      _mail('давнее', at(-1)),
      _mail('первое', at(1)),
      _mail('прочитано на компьютере', at(2), seen: true),
    ];
    await check();
    expect(alerts.shown, [
      ['первое']
    ]);
    expect(prefs.mailSeenUntil, at(2));

    service.inbox = [...service.inbox, _mail('второе', at(3))];
    await check();
    await check();
    expect(alerts.shown, [
      ['первое'],
      ['второе']
    ]);
    expect(service.connected, isFalse, reason: 'disconnected each time');
  });

  test('a changed password stops the checks', () async {
    await store.save(const MailCredentials(r'MARSTU\konkinna', 'old'));
    await check();
    expect(await store.read(), isNull);
    await check();
    expect(service.tried, hasLength(1), reason: 'no second attempt');
  });

  test('no mail password: nothing asked of the server', () async {
    await store.clear();
    await check();
    expect(service.tried, isEmpty);
  });

  group('MailAlerts', () {
    late _Schedule schedule;
    late MailAlerts mailAlerts;

    setUp(() {
      schedule = _Schedule();
      mailAlerts = MailAlerts(prefs, alerts, schedule, clock: () => at(10));
    });

    test('on: mail from now is news, and the checks start', () async {
      expect(await mailAlerts.setEnabled(true), isTrue);
      expect(mailAlerts.enabled, isTrue);
      expect(schedule.running, isTrue);
      expect(prefs.mailSeenUntil, at(10));

      expect(await mailAlerts.setEnabled(false), isTrue);
      expect(schedule.running, isFalse);
      expect(prefs.mailNotify, isFalse);
    });

    test('stays off when notifications are refused', () async {
      alerts.allow = false;
      expect(await mailAlerts.setEnabled(true), isFalse);
      expect(mailAlerts.enabled, isFalse);
      expect(schedule.running, isNull);
    });

    test('mail shown in the app is not news; its notifications go', () async {
      await mailAlerts.setEnabled(true);
      await mailAlerts.seen([_mail('видели', at(20))]);
      expect(prefs.mailSeenUntil, at(20));
      expect(alerts.cleared, 1);

      service.inbox = [_mail('видели', at(20))];
      await check();
      expect(alerts.shown, isEmpty);
    });

    test('resume restarts the checks only when on', () async {
      await mailAlerts.resume();
      expect(schedule.running, isNull);
      await prefs.setMailNotify(true);
      await mailAlerts.resume();
      expect(schedule.running, isTrue);
    });
  });

  test('the inbox by its well-known name, in one request', () {
    final soap = findItemsSoap('inbox', 0, 20, distinguished: true);
    expect(soap, contains('<t:DistinguishedFolderId Id="inbox"/>'));
    expect(findItemsSoap('AAMk=', 0, 20), contains('<t:FolderId Id="AAMk="/>'));
  });
}
