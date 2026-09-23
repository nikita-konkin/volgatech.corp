import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:volgatech_pro/theme.dart';

void main() {
  group('Brand.weekAccentFor mirrors the original weekNumber==1?red:blue rule',
      () {
    test('week 1 is red', () {
      expect(Brand.weekAccentFor(1, dark: false), const Color(0xFFE53935));
      expect(Brand.weekAccentFor(1, dark: true), const Color(0xFFEF5350));
    });

    test('week 2 (and any other) is blue', () {
      expect(Brand.weekAccentFor(2, dark: false), const Color(0xFF1E66C7));
      expect(Brand.weekAccentFor(3, dark: false), const Color(0xFF1E66C7));
      expect(Brand.weekAccentFor(2, dark: true), const Color(0xFF5E92F3));
    });

    test('unknown week is grey', () {
      expect(Brand.weekAccentFor(null, dark: false), const Color(0xFF9E9E9E));
      expect(Brand.weekAccentFor(null, dark: true), const Color(0xFF6E6E6E));
    });

    test('red and blue are always distinct (both themes)', () {
      expect(
          Brand.weekAccentFor(1, dark: false) ==
              Brand.weekAccentFor(2, dark: false),
          isFalse);
      expect(
          Brand.weekAccentFor(1, dark: true) ==
              Brand.weekAccentFor(2, dark: true),
          isFalse);
    });
  });
}
