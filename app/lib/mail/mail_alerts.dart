import 'package:flutter/foundation.dart';

import '../core/prefs.dart';
import 'mail_config.dart';
import 'mail_credentials.dart';
import 'mail_models.dart';
import 'mail_refusals.dart';
import 'mail_service.dart';

/// The unread messages of [inbox] that came after [since], newest first.
List<MailHeader> freshMail(List<MailHeader> inbox, DateTime since) => [
      for (final h in inbox)
        if (!h.seen && (h.date?.isAfter(since) ?? false)) h
    ]..sort((a, b) => b.date!.compareTo(a.date!));

/// Where notifications of new mail go: Android's (mail_background.dart),
/// or a fake in tests.
abstract class MailAlertPlatform {
  Future<bool> requestPermission();
  Future<void> show(List<MailHeader> fresh);

  /// That the server refused the saved password, so checks are paused
  /// until it takes it again; and, once it has, no more.
  Future<void> showRefused();
  Future<void> hideRefused();

  /// The ones shown, and the refusal, once the inbox is open in the app.
  Future<void> clear();
}

/// Runs the check every so often, with the app closed too.
abstract class MailCheckSchedule {
  Future<void> start();
  Future<void> stop();
}

/// One check for new mail, run in the background: tells of the unread
/// messages that came after the newest one already shown or told of. The
/// first time it only notes where «new» begins. A refused password is kept
/// (see [MailRefusals]): the checks pause, longer each time, and the first
/// refusal in a row is told of, and [report]ed.
Future<void> checkForNewMail({
  required Prefs prefs,
  required MailCredentialStore store,
  required MailService service,
  required MailAlertPlatform alerts,
  Future<void> Function(MailAuthException e)? report,
  DateTime Function()? clock,
}) async {
  final creds = await store.read();
  if (creds == null) return;
  final refusals = MailRefusals(prefs, clock: clock);
  if (!await refusals.mayTry()) return;
  try {
    await service.connect(creds);
    if (await refusals.accepted()) await alerts.hideRefused();
    final inbox = await service.latestInbox();
    final since = prefs.mailSeenUntil;
    if (since != null) {
      final fresh = freshMail(inbox, since);
      if (fresh.isNotEmpty) await alerts.show(fresh);
    }
    await _advance(prefs, inbox);
  } on MailAuthException catch (e) {
    if (await refusals.refused() == 1) await alerts.showRefused();
    await report?.call(e);
  } finally {
    await service.disconnect();
  }
}

Future<void> _advance(Prefs prefs, List<MailHeader> inbox) async {
  final since = prefs.mailSeenUntil;
  DateTime? newest = since;
  for (final h in inbox) {
    final d = h.date;
    if (d != null && (newest == null || d.isAfter(newest))) newest = d;
  }
  if (newest != null && newest != since) {
    await prefs.setMailSeenUntil(newest.toUtc());
  }
}

/// «Новые письма» in Settings, and what the mail screen tells it.
class MailAlerts extends ChangeNotifier {
  MailAlerts(this._prefs, this._platform, this._schedule,
      {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  final Prefs _prefs;
  final MailAlertPlatform _platform;
  final MailCheckSchedule _schedule;
  final DateTime Function() _clock;

  /// The MAIL build on Android.
  static bool get supported =>
      kNativeMail && defaultTargetPlatform == TargetPlatform.android;

  bool get enabled => _prefs.mailNotify;

  /// At launch: Android keeps the schedule, but an update may have lost it.
  Future<void> resume() async {
    if (enabled) await _schedule.start();
  }

  /// On asks to show notifications first; false when that was refused.
  Future<bool> setEnabled(bool on) async {
    if (on) {
      if (!await _platform.requestPermission()) return false;
      // Mail from now on is news; older mail isn't.
      await _prefs.reload();
      if (_prefs.mailSeenUntil == null) {
        await _prefs.setMailSeenUntil(_clock().toUtc());
      }
      await _schedule.start();
    } else {
      await _schedule.stop();
    }
    await _prefs.setMailNotify(on);
    notifyListeners();
    return true;
  }

  /// The inbox as the mail screen shows it: none of it is news any more.
  Future<void> seen(List<MailHeader> inbox) async {
    await _prefs.reload();
    await _advance(_prefs, inbox);
    if (enabled) await _platform.clear();
  }
}
