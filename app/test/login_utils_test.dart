import 'package:flutter_test/flutter_test.dart';
import 'package:volgatech_pro/core/login_utils.dart';

void main() {
  group('normalizeLogin', () {
    test('drops the e-mail domain and lowercases', () {
      expect(normalizeLogin('KonkinNA@volgatech.net'), 'konkinna');
      expect(normalizeLogin('IvanovII@marstu.net'), 'ivanovii');
    });
    test('trims whitespace', () {
      expect(normalizeLogin('  KonkinNA@volgatech.net  '), 'konkinna');
      expect(normalizeLogin('\tkonkinna\n'), 'konkinna');
    });
    test('lowercases a bare login (no @)', () {
      expect(normalizeLogin('KonkinNA'), 'konkinna');
      expect(normalizeLogin('konkinna'), 'konkinna');
    });
    test('keeps only the local part before the first @', () {
      expect(normalizeLogin('user@a@b.net'), 'user');
    });
    test('empty stays empty', () {
      expect(normalizeLogin(''), '');
      expect(normalizeLogin('   '), '');
    });
  });
}
