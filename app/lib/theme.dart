import 'package:flutter/material.dart';

/// Brand palette approximated from the original Volgatech PRO screens.
class Brand {
  static const blue = Color(0xFF34517B); // header / app bar (light)
  static const blueDark = Color(0xFF223A57); // app bar (dark)
  static const coral = Color(0xFFEE6C6C); // date bar, primary button
  static const roomBlueLight = Color(0xFF2C5AA0);
  static const roomBlueDark = Color(0xFF7FA8E0);

  static const bgLight = Color(0xFFECECEC);
  static const bgDark = Color(0xFF121212);
  static const surfaceLight = Colors.white;
  static const surfaceDark = Color(0xFF1E1E1E);

  /// Accent for room/group text, adapted to the current brightness.
  static Color room(BuildContext c) =>
      Theme.of(c).brightness == Brightness.dark ? roomBlueDark : roomBlueLight;

  /// Card / tile background.
  static Color card(BuildContext c) => Theme.of(c).colorScheme.surface;

  /// Muted secondary text.
  static Color muted(BuildContext c) =>
      Theme.of(c).colorScheme.onSurfaceVariant;

  // Week-type accent. Mirrors the original app's schedule.ts logic
  // (`weekNumber == 1 ? 'red' : 'blue'`, grey when unknown), so the date bar,
  // lesson cards and chip all take the current week's colour.
  static const _weekRedLight = Color(0xFFE53935);
  static const _weekRedDark = Color(0xFFEF5350);
  static const _weekBlueLight = Color(0xFF1E66C7);
  static const _weekBlueDark = Color(0xFF5E92F3);
  static const _weekGreyLight = Color(0xFF9E9E9E);
  static const _weekGreyDark = Color(0xFF6E6E6E);

  /// Pure mapping (unit-testable, no context): red for week 1, blue for any
  /// other week, grey when the week is unknown.
  static Color weekAccentFor(int? weekNumber, {required bool dark}) {
    if (weekNumber == null) return dark ? _weekGreyDark : _weekGreyLight;
    if (weekNumber == 1) return dark ? _weekRedDark : _weekRedLight;
    return dark ? _weekBlueDark : _weekBlueLight;
  }

  /// Accent colour for a week, resolved against the current brightness.
  /// Shades are tuned per brightness so white text stays legible on top.
  static Color weekAccent(int? weekNumber, BuildContext c) =>
      weekAccentFor(weekNumber, dark: Theme.of(c).brightness == Brightness.dark);
}

ThemeData buildLightTheme() => _base(Brightness.light);
ThemeData buildDarkTheme() => _base(Brightness.dark);

ThemeData _base(Brightness b) {
  final dark = b == Brightness.dark;
  final scheme = (dark
          ? const ColorScheme.dark(
              primary: Brand.blue,
              secondary: Brand.coral,
              surface: Brand.surfaceDark,
            )
          : const ColorScheme.light(
              primary: Brand.blue,
              secondary: Brand.coral,
              surface: Brand.surfaceLight,
            ))
      .copyWith(
    onSurfaceVariant: dark ? const Color(0xFFB0B0B0) : Colors.black54,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: b,
    colorScheme: scheme,
    scaffoldBackgroundColor: dark ? Brand.bgDark : Brand.bgLight,
    appBarTheme: AppBarTheme(
      backgroundColor: dark ? Brand.blueDark : Brand.blue,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? const Color(0xFF2A2A2A) : const Color(0xFFEDEDED),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: Brand.coral,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle:
            const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    ),
  );
}
