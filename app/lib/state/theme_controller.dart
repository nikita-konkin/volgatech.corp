import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/prefs.dart';

class ThemeController extends ChangeNotifier {
  ThemeController(this._prefs)
      : _mode = _prefs.themeMode,
        _glass = _prefs.glass,
        _scuffed = _prefs.glassScuffed,
        _strength = _prefs.glassStrength,
        _frost = _prefs.glassFrost;
  final Prefs _prefs;
  ThemeMode _mode;
  bool _glass;
  bool _scuffed;
  double _strength;
  double _frost;

  ThemeMode get mode => _mode;

  /// «Liquid Glass» chosen; only the browser offers it.
  bool get glass => kIsWeb && _glass;

  /// The glass matte, frosted and scuffed, rather than clear.
  bool get scuffed => _scuffed;

  /// How strong the clear glass is, 0 to 1; 1, as designed.
  double get strength => _strength;

  /// How far frost has grown on the matte glass, 0 to 1.
  double get frost => _frost;

  Future<void> setMode(ThemeMode m) async {
    if (m == _mode) return;
    _mode = m;
    notifyListeners();
    await _prefs.setThemeMode(m);
  }

  Future<void> setGlass(bool on) async {
    if (on == _glass) return;
    _glass = on;
    notifyListeners();
    await _prefs.setGlass(on);
  }

  /// While the slider moves: the look follows, [save] keeps it.
  Future<void> setStrength(double v, {bool save = true}) async {
    v = v.clamp(0.0, 1.0);
    if (v != _strength) {
      _strength = v;
      notifyListeners();
    }
    if (save) await _prefs.setGlassStrength(v);
  }

  /// As [setStrength], for the frost on the matte glass.
  Future<void> setFrost(double v, {bool save = true}) async {
    v = v.clamp(0.0, 1.0);
    if (v != _frost) {
      _frost = v;
      notifyListeners();
    }
    if (save) await _prefs.setGlassFrost(v);
  }

  Future<void> setScuffed(bool on) async {
    if (on == _scuffed) return;
    _scuffed = on;
    notifyListeners();
    await _prefs.setGlassScuffed(on);
  }
}
