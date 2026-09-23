import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/cache.dart';
import '../core/login_utils.dart';
import '../core/session.dart';
import '../data/volgatech_api.dart';
import '../models/profile.dart';

enum AuthStatus { unknown, unauthenticated, authenticating, authenticated }

class AuthController extends ChangeNotifier {
  AuthController(this._api, this._session, this._cache) {
    _expiredSub = _session.onExpired.listen((_) => _onSessionExpired());
  }
  final VolgatechApi _api;
  final Session _session;
  final JsonCache _cache;
  late final StreamSubscription<void> _expiredSub;
  bool _sessionExpired = false;

  AuthStatus status = AuthStatus.unknown;
  PersonProfile? profile;
  int? personId;
  String? error;

  String _profileKey(int id) => 'profile_$id';

  Future<void> bootstrap() async {
    if (await _session.hasSession) {
      personId = await _session.personId;
      // Show cached profile immediately (works offline), refresh in background.
      if (personId != null) {
        final cached = await _cache.get(_profileKey(personId!));
        if (cached != null && cached.data is Map) {
          profile =
              PersonProfile.fromCache(Map<String, dynamic>.from(cached.data as Map));
        }
      }
      status = AuthStatus.authenticated;
      notifyListeners();
      unawaited(_refreshProfile());
    } else {
      status = AuthStatus.unauthenticated;
      notifyListeners();
    }
  }

  Future<bool> login(String login, String password) async {
    error = null;
    status = AuthStatus.authenticating;
    notifyListeners();
    try {
      final tokens = await _api.getToken(normalizeLogin(login), password);
      await _session.saveTokens(tokens);
      final base = await _api.getProfile(); // personId
      personId = base.personId;
      profile = base;
      await _session.savePersonId(base.personId);
      status = AuthStatus.authenticated;
      notifyListeners();
      // Pull the full profile (name/photo/salary) in the background.
      unawaited(_refreshProfile());
      return true;
    } catch (e) {
      error = e.toString();
      status = AuthStatus.unauthenticated;
      await _session.clear();
      notifyListeners();
      return false;
    }
  }

  /// Best-effort fetch of the full profile (/GetInfo); updates + caches it.
  Future<void> _refreshProfile() async {
    final id = personId;
    if (id == null) return;
    try {
      final full = await _api.getPersonInfo(id);
      profile = full;
      await _cache.put(_profileKey(id), full.toJson());
      notifyListeners();
    } catch (_) {/* keep whatever we have (cached or basic) */}
  }

  Future<void> refreshProfile() => _refreshProfile();

  Future<void> logout() async {
    await _session.clear();
    profile = null;
    personId = null;
    status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  /// True once after the server ended the session; the login screen uses it
  /// to explain why the user is back there.
  bool consumeSessionExpired() {
    final v = _sessionExpired;
    _sessionExpired = false;
    return v;
  }

  void _onSessionExpired() {
    if (status != AuthStatus.authenticated) return;
    profile = null;
    personId = null;
    _sessionExpired = true;
    status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(_expiredSub.cancel());
    super.dispose();
  }
}
