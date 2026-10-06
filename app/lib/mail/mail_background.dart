import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:workmanager/workmanager.dart';

import '../core/notifications.dart';
import '../core/prefs.dart';
import '../core/ru_plural.dart';
import 'ews_mail_service.dart';
import 'mail_alerts.dart';
import 'mail_credentials.dart';
import 'mail_models.dart';

/// Android runs the check for new mail every 15 minutes (its shortest
/// period), when there's a network, with the app closed too.
class BackgroundMailCheck implements MailCheckSchedule {
  static const _name = 'mail-check';
  static Future<void>? _ready;

  Future<void> _init() =>
      _ready ??= Workmanager().initialize(mailCheckDispatcher);

  @override
  Future<void> start() async {
    await _init();
    await Workmanager().registerPeriodicTask(
      _name,
      _name,
      frequency: const Duration(minutes: 15),
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    );
  }

  @override
  Future<void> stop() async {
    await _init();
    await Workmanager().cancelByUniqueName(_name);
  }
}

/// The background isolate's start: one check, then done. A failure waits
/// for the next turn rather than retrying.
@pragma('vm:entry-point')
void mailCheckDispatcher() {
  Workmanager().executeTask((task, input) async {
    try {
      final prefs = await Prefs.load();
      if (!prefs.mailNotify) return true;
      await checkForNewMail(
        prefs: prefs,
        store: MailCredentialStore(),
        service: EwsMailService(),
        alerts: LocalMailAlerts(),
      );
    } on Object catch (e) {
      debugPrint('mail check: $e');
    }
    return true;
  });
}

/// New mail as Android notifications: one per message (the newest few),
/// newest on top, under a summary that is the one to sound (so Android
/// doesn't lift whichever message sounded). A tap opens «Почта».
class LocalMailAlerts implements MailAlertPlatform {
  static const _tag = 'mail';
  static const _group = 'net.volgatech.mail';
  static const _summaryId = 19999;
  static const _shown = 4;

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
  Future<void> clear() async {
    await Notifications.ensureReady();
    final plugin = Notifications.plugin;
    for (final n in await plugin.getActiveNotifications()) {
      if (n.tag == _tag && n.id != null) {
        await plugin.cancel(id: n.id!, tag: _tag);
      }
    }
  }

  static String _sender(MailHeader h) =>
      h.fromName.isNotEmpty ? h.fromName : h.fromEmail;
  static String _subject(MailHeader h) =>
      h.subject.isEmpty ? '(без темы)' : h.subject;
}
