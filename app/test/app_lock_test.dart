import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:volgatech_pro/core/app_lock.dart';
import 'package:volgatech_pro/core/prefs.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppLock start state follows the saved preference', () {
    test('disabled by default: not enabled, not locked', () async {
      SharedPreferences.setMockInitialValues({});
      final lock = AppLock(await Prefs.load());
      expect(lock.enabled, isFalse);
      expect(lock.isLocked, isFalse);
    });

    test('enabled preference => starts locked (content hidden until auth)',
        () async {
      SharedPreferences.setMockInitialValues({'app_lock_enabled': true});
      final lock = AppLock(await Prefs.load());
      expect(lock.enabled, isTrue);
      expect(lock.isLocked, isTrue);
    });

    test('lock() is a no-op while disabled', () async {
      SharedPreferences.setMockInitialValues({});
      final lock = AppLock(await Prefs.load());
      lock.lock();
      expect(lock.isLocked, isFalse);
    });

    test('disable() clears both flags and persists', () async {
      SharedPreferences.setMockInitialValues({'app_lock_enabled': true});
      final prefs = await Prefs.load();
      final lock = AppLock(prefs);
      await lock.disable();
      expect(lock.enabled, isFalse);
      expect(lock.isLocked, isFalse);
      expect(prefs.appLockEnabled, isFalse);
    });
  });
}
