import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:volgatech_pro/theme.dart';

/// WCAG contrast ratio of two opaque colours.
double _contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  return (max(la, lb) + 0.05) / (min(la, lb) + 0.05);
}

void main() {
  for (final (name, theme) in [
    ('light', buildLightTheme()),
    ('dark', buildDarkTheme()),
  ]) {
    test('$name theme: primary buttons read as enabled', () {
      final s = theme.colorScheme;
      // Button label on its fill.
      expect(_contrast(s.onPrimary, s.primary), greaterThanOrEqualTo(4.5));
      // Button fill, checkbox, outlined-button text against the page.
      expect(_contrast(s.primary, theme.scaffoldBackgroundColor),
          greaterThanOrEqualTo(4.5));
      expect(_contrast(s.primary, s.surface), greaterThanOrEqualTo(4.5));
    });
  }
}
