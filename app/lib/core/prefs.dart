import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Non-secret preferences (remembered username, theme). Secrets live in
/// [Session] (secure storage); this is plain, and survives logout on purpose.
class Prefs {
  Prefs(this._p);
  final SharedPreferences _p;

  static Future<Prefs> load() async =>
      Prefs(await SharedPreferences.getInstance());

  static const _kLogin = 'remembered_login';
  static const _kRemember = 'remember_login';
  static const _kTheme = 'theme_mode';
  static const _kGlass = 'theme_glass';
  static const _kScuffed = 'theme_glass_scuffed';
  static const _kLessonReminder = 'lesson_reminder_minutes';
  static const _kAppLock = 'app_lock_enabled';
  static const _kPinsFolded = 'mail_pins_folded';
  static const _kPinnedFirst = 'mail_pinned_first';
  static const _kSizeColors = 'mail_size_colors';
  static const _kQuota = 'mail_quota';
  static const _kUpdateDismissed = 'update_dismissed';
  static const _kSignature = 'mail_signature';
  static const _kUnread = 'mail_unread';
  static const _kMailNotify = 'mail_notify';
  static const _kMailSeenUntil = 'mail_seen_until';
  static const _kDraft = 'mail_draft';
  static const _kSignNew = 'mail_signature_new';
  static const _kSignReplies = 'mail_signature_replies';

  String? get rememberedLogin => _p.getString(_kLogin);

  /// What the background check (another isolate) may have written meanwhile.
  Future<void> reload() => _p.reload();

  /// Notifications of new mail (MAIL builds on Android).
  bool get mailNotify => _p.getBool(_kMailNotify) ?? false;
  Future<void> setMailNotify(bool on) async => _p.setBool(_kMailNotify, on);

  /// The newest arrival in «Входящие» already shown or told of: only mail
  /// after it makes a notification.
  DateTime? get mailSeenUntil => switch (_p.getInt(_kMailSeenUntil)) {
        final ms? => DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true),
        null => null,
      };
  Future<void> setMailSeenUntil(DateTime t) async =>
      _p.setInt(_kMailSeenUntil, t.millisecondsSinceEpoch);

  /// Minutes before a lesson to remind of it; 0: no reminders.
  int get lessonReminderMinutes => _p.getInt(_kLessonReminder) ?? 0;
  Future<void> setLessonReminderMinutes(int m) async =>
      _p.setInt(_kLessonReminder, m);
  bool get rememberLogin => _p.getBool(_kRemember) ?? true;

  Future<void> setRememberedLogin(String? login) async {
    if (login == null || login.isEmpty) {
      await _p.remove(_kLogin);
    } else {
      await _p.setString(_kLogin, login);
    }
  }

  Future<void> setRememberLogin(bool v) async => _p.setBool(_kRemember, v);

  /// Require a fingerprint / PIN when the app opens. Off by default.
  bool get appLockEnabled => _p.getBool(_kAppLock) ?? false;
  Future<void> setAppLockEnabled(bool v) async => _p.setBool(_kAppLock, v);

  /// Messages pinned in Outlook shown above the rest of the mail list.
  bool get mailPinnedFirst => _p.getBool(_kPinnedFirst) ?? true;
  Future<void> setMailPinnedFirst(bool v) async => _p.setBool(_kPinnedFirst, v);

  /// Mail list rows coloured by message size, yellow to red.
  bool get mailSizeColors => _p.getBool(_kSizeColors) ?? true;
  Future<void> setMailSizeColors(bool v) async => _p.setBool(_kSizeColors, v);

  /// The mailbox limit in bytes as typed in, for a server that doesn't
  /// tell it.
  int? get mailQuota => _p.getInt(_kQuota);
  Future<void> setMailQuota(int? v) async =>
      v == null ? _p.remove(_kQuota) : _p.setInt(_kQuota, v);

  /// The mail signature; null until one is saved (or imported from the
  /// web mail).
  String? get mailSignature => _p.getString(_kSignature);
  Future<void> setMailSignature(String v) async => _p.setString(_kSignature, v);

  /// Where the signature goes: new messages, and replies and forwards.
  bool get mailSignNew => _p.getBool(_kSignNew) ?? true;
  Future<void> setMailSignNew(bool v) async => _p.setBool(_kSignNew, v);
  bool get mailSignReplies => _p.getBool(_kSignReplies) ?? true;
  Future<void> setMailSignReplies(bool v) async => _p.setBool(_kSignReplies, v);

  /// The signature for a new message, or for a reply or forward.
  String signatureFor({required bool reply}) =>
      (reply ? mailSignReplies : mailSignNew) ? mailSignature ?? '' : '';

  /// The last known unread count in «Входящие», for the badge at start-up.
  int get mailUnread => _p.getInt(_kUnread) ?? 0;
  Future<void> setMailUnread(int n) async => _p.setInt(_kUnread, n);

  /// The message last left unsent (see `ComposeDraft.toJson`), if any.
  Object? get mailDraft => readJson(_kDraft);
  Future<void> setMailDraft(Object? json) async =>
      json == null ? _p.remove(_kDraft) : writeJson(_kDraft, json);

  /// The new version put off with «Позже», not offered again by the banner.
  String? get updateDismissed => _p.getString(_kUpdateDismissed);
  Future<void> setUpdateDismissed(String? v) async => v == null
      ? _p.remove(_kUpdateDismissed)
      : _p.setString(_kUpdateDismissed, v);

  /// «Закреплённые» folded away at the top of the mail list.
  bool get mailPinsFolded => _p.getBool(_kPinsFolded) ?? false;
  Future<void> setMailPinsFolded(bool v) async => _p.setBool(_kPinsFolded, v);

  /// «Liquid Glass» (the browser's choice in Settings).
  bool get glass => _p.getBool(_kGlass) ?? false;
  Future<void> setGlass(bool on) async => _p.setBool(_kGlass, on);

  /// The glass matte — frosted and scuffed — rather than clear.
  bool get glassScuffed => _p.getBool(_kScuffed) ?? false;
  Future<void> setGlassScuffed(bool on) async => _p.setBool(_kScuffed, on);

  ThemeMode get themeMode {
    switch (_p.getString(_kTheme)) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  /// A small JSON document stored under [key] (null if absent or corrupt).
  Object? readJson(String key) {
    final raw = _p.getString(key);
    if (raw == null) return null;
    try {
      return jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }

  Future<void> writeJson(String key, Object value) async =>
      _p.setString(key, jsonEncode(value));

  Future<void> setThemeMode(ThemeMode m) async {
    await _p.setString(
        _kTheme,
        m == ThemeMode.light
            ? 'light'
            : m == ThemeMode.dark
                ? 'dark'
                : 'system');
  }
}
