import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/prefs.dart';

class ThemeController extends ChangeNotifier {
  ThemeController(this._prefs)
      : _mode = _prefs.themeMode,
        _glass = _prefs.glass,
        _scuffed = _prefs.glassScuffed,
        _strength = _prefs.glassStrength,
        _etch = _prefs.glassEtch;
  final Prefs _prefs;
  ThemeMode _mode;
  bool _glass;
  bool _scuffed;
  double _strength;
  double _etch;

  ThemeMode get mode => _mode;

  /// «Liquid Glass» chosen; only the browser offers it.
  bool get glass => kIsWeb && _glass;

  /// The glass matte, frosted and scuffed, rather than clear.
  bool get scuffed => _scuffed;

  /// How strong the clear glass is, 0 to 1; 1, as designed.
  double get strength => _strength;

  /// How richly the matte glass is etched with spirals, 0 to 1.
  double get etch => _etch;

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

  /// As [setStrength], for the matte glass's etching.
  Future<void> setEtch(double v, {bool save = true}) async {
    v = v.clamp(0.0, 1.0);
    if (v != _etch) {
      _etch = v;
      notifyListeners();
    }
    if (save) await _prefs.setGlassEtch(v);
  }

  Future<void> setScuffed(bool on) async {
    if (on == _scuffed) return;
    _scuffed = on;
    notifyListeners();
    await _prefs.setGlassScuffed(on);
  }
}
