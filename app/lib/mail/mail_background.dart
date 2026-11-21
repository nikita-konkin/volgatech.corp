import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:workmanager/workmanager.dart';

import '../core/crash_log.dart';
import '../core/notifications.dart';
import '../core/prefs.dart';
import '../core/ru_plural.dart';
import 'ews_mail_service.dart';
import 'mail_alerts.dart';
import 'mail_credentials.dart';
import 'mail_models.dart';
import 'mail_refusals.dart';
import 'mail_service.dart';

/// Registers and cancels the two jobs used for background mail checks.
abstract interface class MailBackgroundWork {
  Future<void> periodic(Duration frequency);
  Future<void> short(Duration delay, {required bool append});
  Future<void> cancelPeriodic();
  Future<void> cancelShort();
}

/// Schedules mail checks with a periodic fallback for short intervals.
final class BackgroundMailCheck implements MailCheckSchedule {
  const BackgroundMailCheck(this._prefs,
      {MailBackgroundWork work = const _AndroidMailBackgroundWork()})
      : _work = work;

  final Prefs _prefs;
  final MailBackgroundWork _work;

  @override
  Future<void> start() async {
    final minutes = _prefs.mailCheckMinutes;
    if (minutes < 15) {
      await _work.periodic(const Duration(minutes: 15));
      await _work.short(Duration(minutes: minutes), append: false);
    } else {
      await _work.cancelShort();
      await _work.periodic(Duration(minutes: minutes));
    }
  }

  Future<void> continueShort() async {
    await _prefs.reload();
    final minutes = _prefs.mailCheckMinutes;
    if (_prefs.mailNotify && minutes < 15) {
      await _work.short(Duration(minutes: minutes), append: true);
    }
  }

  @override
  Future<void> stop() async {
    await _work.cancelShort();
    await _work.cancelPeriodic();
  }
}

/// Registers the Android jobs through WorkManager.
final class _AndroidMailBackgroundWork implements MailBackgroundWork {
  const _AndroidMailBackgroundWork();

  static const _periodicName = 'mail-check';
  static const shortName = 'mail-check-short';
  static Future<void>? _ready;

  Future<void> _init() =>
      _ready ??= Workmanager().initialize(mailCheckDispatcher);

  @override
  Future<void> periodic(Duration frequency) async {
    await _init();
    await Workmanager().registerPeriodicTask(
      _periodicName,
      _periodicName,
      frequency: frequency,
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
    );
  }

  @override
  Future<void> short(Duration delay, {required bool append}) async {
    if (!append) await _init();
    await Workmanager().registerOneOffTask(
      shortName,
      shortName,
      initialDelay: delay,
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy:
          append ? ExistingWorkPolicy.update : ExistingWorkPolicy.replace,
    );
  }

  @override
  Future<void> cancelPeriodic() =>
      Workmanager().cancelByUniqueName(_periodicName);

  @override
  Future<void> cancelShort() => Workmanager().cancelByUniqueName(shortName);
}

/// Checks mail in the background and continues the short schedule when enabled.
@pragma('vm:entry-point')
void mailCheckDispatcher() {
  Workmanager().executeTask((task, input) async {
    try {
      final prefs = await Prefs.load();
      try {
        await runBackgroundMailCheck(
          prefs: prefs,
          store: MailCredentialStore(),
          service: EwsMailService(),
          alerts: LocalMailAlerts(),
          loadLog: () => _loadLog(prefs),
        );
      } finally {
        if (task == _AndroidMailBackgroundWork.shortName) {
          await BackgroundMailCheck(prefs).continueShort();
        }
      }
    } on Object catch (e) {
      debugPrint('mail check: $e');
    }
    return true;
  });
}

/// Runs an enabled check and keeps its result on the device.
Future<void> runBackgroundMailCheck({
  required Prefs prefs,
  required MailCredentialStore store,
  required MailService service,
  required MailAlertPlatform alerts,
  required Future<CrashLog> Function() loadLog,
  DateTime Function()? clock,
}) async {
  try {
    await prefs.reload();
    if (!prefs.mailNotify) return;
    final completed = await checkForNewMail(
      prefs: prefs,
      store: store,
      service: service,
      alerts: alerts,
      clock: clock,
      report: (e) async {
        final log = await loadLog();
        await log.add(
            refusalReport(e), StackTrace.fromString('фоновая проверка почты'));
      },
    );
    if (completed) {
      await prefs.setMailLastBackgroundCheck((clock ?? DateTime.now)());
    }
  } on MailAuthException {
    return;
  } on Object catch (error, stack) {
    final log = await loadLog();
    final detail =
        '$error'.split('\n').first.trim().replaceFirst(RegExp(r'\.+$'), '');
    await log.add('Фоновая проверка почты не удалась: $detail', stack);
  }
}

Future<CrashLog> _loadLog(Prefs prefs) async {
  String version;
  try {
    final app = await PackageInfo.fromPlatform();
    version = '${app.version}+${app.buildNumber}';
  } on Object {
    version = '';
  }
  await prefs.reload().catchError((Object _) {});
  return CrashLog(prefs, platform: 'android')..version = version;
}

/// New mail as Android notifications: one per message (the newest few),
/// newest on top, under a summary that is the one to sound (so Android
/// doesn't lift whichever message sounded). A tap opens «Почта».
class LocalMailAlerts implements MailAlertPlatform {
  static const _tag = 'mail';
  static const _group = 'net.volgatech.mail';
  static const _summaryId = 19999;
  static const _shown = 4;

  /// The refusal notice: on its own, apart from the messages.
  static const _refusedTag = 'mail-password';
  static const _refusedId = 19998;

  /// [at]: when the message came, which also orders them in the group.
  static AndroidNotificationDetails _android(DateTime? at,
          {bool summary = false, StyleInformation? style}) =>
      AndroidNotificationDetails(
        'mail',
        'Новые письма',
        channelDescription: 'Письма во «Входящих»',
        importance: Importance.high,
        priority: Priority.high,
        icon: 'ic_stat_mail',
        category: AndroidNotificationCategory.email,
        groupKey: _group,
        setAsGroupSummary: summary,
        groupAlertBehavior: GroupAlertBehavior.summary,
        styleInformation: style,
        tag: _tag,
        when: at?.millisecondsSinceEpoch,
      );

  @override
  Future<bool> requestPermission() => Notifications.requestPermission();

  @override
  Future<void> show(List<MailHeader> fresh) async {
    if (fresh.isEmpty) return;
    await Notifications.ensureReady();
    final plugin = Notifications.plugin;
    final ids = <int>{
      // Still there from an earlier check.
      for (final n in await plugin.getActiveNotifications())
        if (n.tag == _tag && n.id != null && n.id != _summaryId) n.id!,
    };
    for (final h in fresh.take(_shown)) {
      final id = 20000 + (h.id.hashCode & 0x3fff);
      ids.add(id);
      await plugin.show(
        id: id,
        title: _sender(h),
        body: _subject(h),
        notificationDetails: NotificationDetails(
            android:
                _android(h.date, style: BigTextStyleInformation(_subject(h)))),
        payload: 'mail',
      );
    }
    // With one message Android shows just it; the summary speaks for it in
    // the pop-up.
    final newest = fresh.first;
    final n = ids.length;
    final title = n == 1
        ? _sender(newest)
        : '$n ${pluralRu(n, 'новое письмо', 'новых письма', 'новых писем')}';
    await plugin.show(
      id: _summaryId,
      title: title,
      body: n == 1 ? _subject(newest) : fresh.map(_sender).toSet().join(', '),
      notificationDetails: NotificationDetails(
        android: _android(
          newest.date,
          summary: true,
          style: n == 1
              ? BigTextStyleInformation(_subject(newest))
              : InboxStyleInformation(
                  [
                    for (final h in fresh.take(6))
                      '${_sender(h)}: ${_subject(h)}'
                  ],
                  contentTitle: title,
                ),
        ),
      ),
      payload: 'mail',
    );
  }

  @override
  Future<void> showRefused() async {
    await Notifications.ensureReady();
    await Notifications.plugin.show(
      id: _refusedId,
      title: 'Почта не принимает пароль',
      body: 'Новые письма пока не проверяются. Откройте почту, чтобы войти '
          'снова.',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'mail',
          'Новые письма',
          channelDescription: 'Письма во «Входящих»',
          icon: 'ic_stat_mail',
          category: AndroidNotificationCategory.error,
          tag: _refusedTag,
          styleInformation: BigTextStyleInformation(
              'Новые письма пока не проверяются. Откройте почту, чтобы '
              'войти снова.'),
        ),
      ),
      payload: 'mail',
    );
  }

  @override
  Future<void> hideRefused() async {
    await Notifications.ensureReady();
    await Notifications.plugin.cancel(id: _refusedId, tag: _refusedTag);
  }

  @override
  Future<void> clear() async {
    await Notifications.ensureReady();
    final plugin = Notifications.plugin;
    for (final n in await plugin.getActiveNotifications()) {
      if ((n.tag == _tag || n.tag == _refusedTag) && n.id != null) {
        await plugin.cancel(id: n.id!, tag: n.tag);
      }
    }
  }

  static String _sender(MailHeader h) =>
      h.fromName.isNotEmpty ? h.fromName : h.fromEmail;
  static String _subject(MailHeader h) =>
      h.subject.isEmpty ? '(без темы)' : h.subject;
}
