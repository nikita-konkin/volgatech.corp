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
  static const _kAppLock = 'app_lock_enabled';

  String? get rememberedLogin => _p.getString(_kLogin);
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
