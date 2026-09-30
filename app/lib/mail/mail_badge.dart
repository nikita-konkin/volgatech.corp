import 'dart:async';

import 'package:flutter/widgets.dart';

import '../core/prefs.dart';
import 'ews_mail_service.dart';
import 'mail_credentials.dart';
import 'mail_models.dart';
import 'mail_service.dart';

/// Unread mail in «Входящие», for the badge on the menu button and on
/// «Почта». Checked when the app starts or comes back (at most every
/// [minInterval]); while the mail screen is open it reports every change.
class MailBadge extends ChangeNotifier {
  MailBadge({
    required Prefs prefs,
    required MailCredentialStore store,
    MailService Function()? service,
    this.minInterval = const Duration(minutes: 2),
  })  : _prefs = prefs,
        _store = store,
        _service = service ?? EwsMailService.new,
        _unread = prefs.mailUnread;

  final Prefs _prefs;
  final MailCredentialStore _store;
  final MailService Function() _service;
  final Duration minInterval;

  int _unread;
  int get unread => _unread;

  DateTime? _checkedAt;
  bool _checking = false;
  AppLifecycleListener? _lifecycle;

  /// Checks now and whenever the app comes back to the screen.
  void watch() {
    _lifecycle ??= AppLifecycleListener(onResume: () => unawaited(check()));
    unawaited(check());
  }

  Future<void> check({bool force = false}) async {
    final at = _checkedAt;
    if (_checking ||
        (!force && at != null && DateTime.now().difference(at) < minInterval)) {
      return;
    }
    _checking = true;
    final service = _service();
    try {
      final creds = await _store.read();
      if (creds == null) {
        set(0);
        return;
      }
      await service.connect(creds);
      set(await service.inboxUnread());
      _checkedAt = DateTime.now();
    } on MailAuthException {
      // The password changed: forget it, as the mail screen does, so no
      // further attempt counts towards the account's lockout.
      await _store.clear();
      set(0);
    } on Object {
      // Offline or the server is busy: keep showing the last count.
    } finally {
      await service.disconnect();
      _checking = false;
    }
  }

  void set(int n) {
    if (n == _unread) return;
    _unread = n;
    unawaited(_prefs.setMailUnread(n));
    notifyListeners();
  }

  @override
  void dispose() {
    _lifecycle?.dispose();
    super.dispose();
  }
}
