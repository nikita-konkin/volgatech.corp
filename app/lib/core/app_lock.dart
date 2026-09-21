import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

import 'prefs.dart';

/// Optional "lock on open" using the device fingerprint / face / PIN.
///
/// Safety by design:
///  * Off by default; the raw password is never involved (tokens stay in the
///    keystore) — this only gates the UI.
///  * Turning it ON first performs a real auth, so a device that cannot
///    authenticate can never end up in a locked-out state.
///  * `biometricOnly: false` lets the device PIN/pattern stand in for a
///    fingerprint, so old phones without a sensor still work.
class AppLock extends ChangeNotifier {
  AppLock(this._prefs) {
    _enabled = _prefs.appLockEnabled;
    // If enabled, start locked so content is hidden until the first auth.
    _locked = _enabled;
  }

  final Prefs _prefs;
  final LocalAuthentication _auth = LocalAuthentication();

  bool _enabled = false;
  bool _locked = false;
  bool _authInProgress = false;

  bool get enabled => _enabled;

  /// True when content must stay hidden behind the lock screen.
  bool get isLocked => _enabled && _locked;

  /// Can this device authenticate at all (any biometric or a device PIN)?
  Future<bool> canAuthenticate() async {
    try {
      return await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  Future<bool> _authenticate(String reason) async {
    if (_authInProgress) return false;
    _authInProgress = true;
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: false, // allow device PIN/pattern fallback
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
    } catch (_) {
      return false;
    } finally {
      _authInProgress = false;
    }
  }

  /// Enable the lock. Requires a successful auth up front; returns false (and
  /// stays disabled) if the device can't authenticate, so we never lock the
  /// user out.
  Future<bool> enable() async {
    if (!await canAuthenticate()) return false;
    final ok = await _authenticate('Подтвердите, чтобы включить блокировку');
    if (!ok) return false;
    _enabled = true;
    _locked = false;
    await _prefs.setAppLockEnabled(true);
    notifyListeners();
    return true;
  }

  Future<void> disable() async {
    _enabled = false;
    _locked = false;
    await _prefs.setAppLockEnabled(false);
    notifyListeners();
  }

  /// Called from the lock screen. Returns true on success.
  Future<bool> unlock() async {
    if (!_enabled) return true;
    final ok = await _authenticate('Разблокируйте Volgatech PRO');
    if (ok) {
      _locked = false;
      notifyListeners();
    }
    return ok;
  }

  /// Re-lock when the app is backgrounded (if enabled).
  void lock() {
    if (_enabled && !_locked) {
      _locked = true;
      notifyListeners();
    }
  }
}
