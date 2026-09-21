import 'package:flutter/material.dart';
import '../core/prefs.dart';

class ThemeController extends ChangeNotifier {
  ThemeController(this._prefs) : _mode = _prefs.themeMode;
  final Prefs _prefs;
  ThemeMode _mode;

  ThemeMode get mode => _mode;

  Future<void> setMode(ThemeMode m) async {
    if (m == _mode) return;
    _mode = m;
    notifyListeners();
    await _prefs.setThemeMode(m);
  }
}
