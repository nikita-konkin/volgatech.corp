import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/prefs.dart';
import '../core/season.dart';

class ThemeController extends ChangeNotifier {
  ThemeController(this._prefs)
      : _mode = _prefs.themeMode,
        _glass = _prefs.glass,
        _scuffed = _prefs.glassScuffed,
        _strength = _prefs.glassStrength,
        _ornament = _prefs.glassOrnament,
        _season = _prefs.glassSeason;
  final Prefs _prefs;
  ThemeMode _mode;
  bool _glass;
  bool _scuffed;
  double _strength;
  double _ornament;
  Season? _season;

  ThemeMode get mode => _mode;

  /// «Liquid Glass» chosen; only the browser offers it.
  bool get glass => kIsWeb && _glass;

  /// The glass matte, frosted and scuffed, rather than clear.
  bool get scuffed => _scuffed;

  /// How strong the clear glass is, 0 to 1; 1, as designed.
  double get strength => _strength;

  /// How far the ornament has grown on the glass, clear or matte, 0 to 1.
  double get ornament => _ornament;

  /// The season whose ornament the glass shows, as chosen; null: the one
  /// it is.
  Season? get seasonChosen => _season;

  /// The season whose ornament the glass shows.
  Season get season => _season ?? Season.of(DateTime.now());

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

  /// As [setStrength], for the ornament.
  Future<void> setOrnament(double v, {bool save = true}) async {
    v = v.clamp(0.0, 1.0);
    if (v != _ornament) {
      _ornament = v;
      notifyListeners();
    }
    if (save) await _prefs.setGlassOrnament(v);
  }

  /// [s]'s ornament on the glass; null, the season's it is.
  Future<void> setSeason(Season? s) async {
    if (s == _season) return;
    _season = s;
    notifyListeners();
    await _prefs.setGlassSeason(s);
  }

  Future<void> setScuffed(bool on) async {
    if (on == _scuffed) return;
    _scuffed = on;
    notifyListeners();
    await _prefs.setGlassScuffed(on);
  }
}
