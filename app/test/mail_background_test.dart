import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:volgatech_pro/core/crash_log.dart';
import 'package:volgatech_pro/core/prefs.dart';
import 'package:volgatech_pro/mail/mail_alerts.dart';
import 'package:volgatech_pro/mail/mail_background.dart';
import 'package:volgatech_pro/mail/mail_credentials.dart';
import 'package:volgatech_pro/mail/mail_models.dart';

import 'mail_controller_test.dart' show FakeMailService;

/// Records refusal notices without sending Android notifications.
class _Alerts implements MailAlertPlatform {
  int refusals = 0;

  @override
  Future<void> showRefused() async => refusals++;

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> show(List<MailHeader> fresh) async {}

  @override
  Future<void> hideRefused() async {}

  @override
  Future<void> clear() async {}
}

Future<Prefs> _prefs() async {
  final printBefore = debugPrint;
  debugPrint = (_, {wrapWidth}) {};
  addTearDown(() => debugPrint = printBefore);
  SharedPreferences.setMockInitialValues({'mail_notify': true});
  FlutterSecureStorage.setMockInitialValues({});
  return Prefs.load();
}

Future<MailCredentialStore> _signedIn(String login) async {
  final store = MailCredentialStore();
  await store.save(MailCredentials(login, 'secret'));
  return store;
}

/// Records scheduling operations without Android.
final class _Work implements MailBackgroundWork {
  final calls = <(String, int)>[];

  @override
  Future<void> periodic(Duration frequency) async =>
      calls.add(('periodic', frequency.inMinutes));

  @override
  Future<void> short(Duration delay, {required bool append}) async =>
      calls.add((append ? 'append' : 'replace', delay.inMinutes));

  @override
  Future<void> cancelPeriodic() async => calls.add(('cancel periodic', 0));

  @override
  Future<void> cancelShort() async => calls.add(('cancel short', 0));
}

void main() {
  test('A daily interval cancels the short chain', () async {
    final prefs = await _prefs();
    await prefs.setMailCheckMinutes(1440);
    final work = _Work();
    await BackgroundMailCheck(prefs, work: work).start();

    expect(work.calls, [('cancel short', 0), ('periodic', 1440)],
        reason: 'The daily schedule did not replace the short chain');
  });

  test('A short check appends the next check at the saved interval', () async {
    final prefs = await _prefs();
    await (await Prefs.load()).setMailCheckMinutes(10);
    final work = _Work();
    await BackgroundMailCheck(prefs, work: work).continueShort();

    expect(work.calls, [('append', 10)],
        reason: 'The next check did not use the saved interval');
  });

  test('A running check cannot continue after notifications are disabled',
      () async {
    final prefs = await _prefs();
    await prefs.setMailCheckMinutes(1);
    await (await Prefs.load()).setMailNotify(false);
    final work = _Work();
    await BackgroundMailCheck(prefs, work: work).continueShort();

    expect(work.calls, isEmpty,
        reason: 'A check was queued after notifications were disabled');
  });

  test('A short interval retains the periodic fallback', () async {
    final prefs = await _prefs();
    await prefs.setMailCheckMinutes(5);
    final work = _Work();
    await BackgroundMailCheck(prefs, work: work).start();

    expect(work.calls, [('periodic', 15), ('replace', 5)],
        reason: 'The short job or its fallback was missing');
  });

  TestWidgetsFlutterBinding.ensureInitialized();

  test('A network failure is written to the on-device error log', () async {
    final prefs = await _prefs();
    final service = FakeMailService()..down = true;
    await runBackgroundMailCheck(
      prefs: prefs,
      store: await _signedIn(service.acceptedLogin),
      service: service,
      alerts: _Alerts(),
      loadLog: () async => CrashLog(prefs),
    );
    final persisted = CrashLog(await Prefs.load());
    expect(
      persisted.entries.map((e) => e.title),
      [startsWith('Фоновая проверка почты не удалась: ')],
      reason: 'The failed check did not leave a report with context',
    );
  });

  test('A completed check saves its time even when the inbox is empty',
      () async {
    final prefs = await _prefs();
    final service = FakeMailService(acceptedLogin: r'MARSTU\n.shilov')
      ..inbox = [];
    final finishedAt = DateTime.utc(2026, 11, 17, 6, 43, 19);
    await runBackgroundMailCheck(
      prefs: prefs,
      store: await _signedIn(service.acceptedLogin),
      service: service,
      alerts: _Alerts(),
      loadLog: () async => CrashLog(prefs),
      clock: () => finishedAt,
    );
    expect(
      (await Prefs.load()).mailLastBackgroundCheck,
      finishedAt,
      reason: 'An empty inbox did not leave a completed check time',
    );
  });

  test('A refused password keeps its original notice and report', () async {
    final prefs = await _prefs();
    final alerts = _Alerts();
    final service = FakeMailService(acceptedLogin: r'MARSTU\m.osipova')
      ..refuse = true;
    await runBackgroundMailCheck(
      prefs: prefs,
      store: await _signedIn(service.acceptedLogin),
      service: service,
      alerts: alerts,
      loadLog: () async => CrashLog(prefs),
    );
    final log = CrashLog(await Prefs.load());
    expect(
      (alerts.refusals, log.entries.map((e) => e.title).join('\n')),
      (1, 'Почта: сервер не принял пароль (401 · locked)'),
      reason: 'The original refusal notice and report did not stay intact',
    );
  });

  test('An unsuccessful check cannot advance the last completed time',
      () async {
    final prefs = await _prefs();
    final previous = DateTime.utc(2026, 10, 22, 23, 18, 52);
    await prefs.setMailLastBackgroundCheck(previous);
    final service = FakeMailService()..down = true;
    await runBackgroundMailCheck(
      prefs: prefs,
      store: await _signedIn(service.acceptedLogin),
      service: service,
      alerts: _Alerts(),
      loadLog: () async => CrashLog(prefs),
      clock: () => previous.add(const Duration(minutes: 34)),
    );
    expect(
      (await Prefs.load()).mailLastBackgroundCheck,
      previous,
      reason: 'The failed check did not preserve the last completed time',
    );
  });

  test('A skipped check cannot look like a completed check', () async {
    final prefs = await _prefs();
    await runBackgroundMailCheck(
      prefs: prefs,
      store: MailCredentialStore(),
      service: FakeMailService(),
      alerts: _Alerts(),
      loadLog: () async => CrashLog(prefs),
    );
    expect(
      (await Prefs.load()).mailLastBackgroundCheck,
      isNull,
      reason: 'A check without credentials should not have a completion time',
    );
  });
}
