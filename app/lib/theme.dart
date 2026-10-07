import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'ui/glass.dart';

/// Brand palette approximated from the original Volgatech PRO screens.
class Brand {
  static const blue = Color(0xFF34517B); // header / app bar (light)
  static const blueDark = Color(0xFF223A57); // app bar (dark)
  // Buttons, checkboxes and switches on the dark theme: [blue] is too dark to
  // read against the near-black background there.
  static const blueOnDark = Color(0xFF7FA8E0);
  static const inkOnBlueOnDark = Color(0xFF0E2340);
  static const coral = Color(0xFFEE6C6C); // date bar, primary button
  static const roomBlueLight = Color(0xFF2C5AA0);
  static const roomBlueDark = blueOnDark;

  static const bgLight = Color(0xFFECECEC);
  static const bgDark = Color(0xFF121212);
  static const surfaceLight = Colors.white;
  static const surfaceDark = Color(0xFF1E1E1E);

  /// Accent for room/group text, adapted to the current brightness.
  static Color room(BuildContext c) => roomFor(
      dark: Theme.of(c).brightness == Brightness.dark, glass: Glass.of(c).on);

  static Color roomFor({required bool dark, bool glass = false}) =>
      dark ? (glass ? Glass.darkAccent : roomBlueDark) : roomBlueLight;

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
  static Color weekAccent(int? weekNumber, BuildContext c) {
    final accent = weekAccentFor(weekNumber,
        dark: Theme.of(c).brightness == Brightness.dark);
    // On glass, in the business palette's quieter tones.
    return Glass.of(c).on ? Glass.tone(accent) : accent;
  }
}

/// [browser]: the web build, which brings its own font (see pubspec.yaml).
/// [glass]: «Liquid Glass» (glass.dart).
ThemeData buildLightTheme({bool browser = kIsWeb, bool glass = false}) =>
    _base(Brightness.light, browser, glass);
ThemeData buildDarkTheme({bool browser = kIsWeb, bool glass = false}) =>
    _base(Brightness.dark, browser, glass);

ThemeData _base(Brightness b, bool browser, bool glass) {
  final dark = b == Brightness.dark;
  // In a browser on an iPhone the platform is iOS, whose system fonts the
  // web engine doesn't have: the Roboto bundled for it (pubspec.yaml). On
  // Android that copy would shadow the phone's own Roboto, which Material asks
  // for by name — and it lacks the 600 weight the app uses — so there the
  // system face is asked for by its generic name.
  final font = browser
      ? 'Roboto'
      : defaultTargetPlatform == TargetPlatform.android
          ? 'sans-serif'
          : null;
  final g = glass ? (dark ? Glass.dark : Glass.light) : Glass.off;
  final text = dark ? Glass.darkText : Glass.lightText;
  final scheme = (dark
          ? const ColorScheme.dark(
              primary: Brand.blueOnDark,
              onPrimary: Brand.inkOnBlueOnDark,
              secondary: Brand.coral,
              surface: Brand.surfaceDark,
            )
          : const ColorScheme.light(
              primary: Brand.blue,
              secondary: Brand.coral,
              surface: Brand.surfaceLight,
            ))
      .copyWith(
    onSurfaceVariant: glass
        ? (dark ? Glass.darkMuted : Glass.lightMuted)
        : dark
            ? const Color(0xFFB0B0B0)
            : Colors.black54,
    // Cards and tiles are glass; what comes over the page — dialogs,
    // sheets, menus — is glass thick enough to read on anything.
    primary: glass && dark ? Glass.darkAccent : null,
    surface: glass ? g.card : null,
    onSurface: glass ? text : null,
    surfaceContainerLowest: glass ? g.solid : null,
    surfaceContainerLow: glass ? g.solid : null,
    surfaceContainer: glass ? g.solid : null,
    surfaceContainerHigh: glass ? g.solid : null,
    surfaceContainerHighest: glass ? g.solid : null,
    outlineVariant: glass ? g.line : null,
  );
  // Glass's edge round what floats over the page.
  RoundedRectangleBorder edged(double radius) => RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: BorderSide(color: g.stroke));
  final fieldBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(glass ? 16 : 8),
    borderSide: glass ? BorderSide(color: g.line) : BorderSide.none,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: b,
    fontFamily: font,
    colorScheme: scheme,
    extensions: [g],
    // Each page lies on its Wallpaper (glass.dart), whether or not glass.
    pageTransitionsTheme: wallpaperTransitions(),
    scaffoldBackgroundColor: glass
        ? Colors.transparent
        : dark
            ? Brand.bgDark
            : Brand.bgLight,
    // A dropdown's menu, among others.
    canvasColor: glass ? g.solid : null,
    dividerColor: glass ? g.line : null,
    appBarTheme: AppBarTheme(
      backgroundColor: glass
          ? g.bar
          : dark
              ? Brand.blueDark
              : Brand.blue,
      // No Material tint over the glass as the page scrolls under.
      surfaceTintColor: glass ? Colors.transparent : null,
      foregroundColor: glass ? text : Colors.white,
      shape: glass ? Border(bottom: BorderSide(color: g.line)) : null,
      elevation: 0,
      centerTitle: false,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: glass
          ? g.field
          : dark
              ? const Color(0xFF2A2A2A)
              : const Color(0xFFEDEDED),
      border: fieldBorder,
      enabledBorder: glass ? fieldBorder : null,
      focusedBorder: glass
          ? fieldBorder.copyWith(
              borderSide: BorderSide(color: scheme.primary, width: 2))
          : null,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: Brand.coral,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(glass ? 16 : 8)),
        // Replaces the theme's text style rather than adding to it.
        textStyle: TextStyle(
            fontFamily: font, fontSize: 16, fontWeight: FontWeight.bold),
      ),
    ),
    cardTheme: glass
        ? CardThemeData(color: g.card, elevation: 0, shape: edged(18))
        : null,
    dialogTheme: glass
        ? DialogThemeData(backgroundColor: g.solid, shape: edged(28))
        : null,
    popupMenuTheme:
        glass ? PopupMenuThemeData(color: g.solid, shape: edged(16)) : null,
    bottomSheetTheme: glass
        ? BottomSheetThemeData(
            backgroundColor: g.solid,
            shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
          )
        : null,
    snackBarTheme: glass
        ? SnackBarThemeData(
            backgroundColor: g.solid,
            contentTextStyle: TextStyle(fontFamily: font, color: text),
            actionTextColor: scheme.primary,
            behavior: SnackBarBehavior.floating,
            shape: edged(18),
          )
        : null,
  );
}
