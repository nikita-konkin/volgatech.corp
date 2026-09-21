import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/auth.dart';

/// Secure token/identity storage.
///
/// SECURITY: unlike the original app (which wrote the raw login+password to
/// localStorage as `logpassCache`), we NEVER persist the password. Only the
/// access/refresh tokens and the numeric personId are stored, in the platform
/// keystore/keychain via flutter_secure_storage.
class Session {
  Session({FlutterSecureStorage? storage})
      : _s = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  final FlutterSecureStorage _s;

  static const _kAccess = 'accessToken';
  static const _kRefresh = 'refreshToken';
  static const _kPersonId = 'personId';

  // In-memory cache so the hot path (attaching the bearer header) is sync-fast.
  String? _accessCache;
  String? _refreshCache;
  int? _personIdCache;

  Future<String?> get accessToken async =>
      _accessCache ??= await _s.read(key: _kAccess);

  Future<String?> get refreshToken async =>
      _refreshCache ??= await _s.read(key: _kRefresh);

  Future<int?> get personId async {
    if (_personIdCache != null) return _personIdCache;
    final v = await _s.read(key: _kPersonId);
    return _personIdCache = (v == null ? null : int.tryParse(v));
  }

  Future<void> saveTokens(AuthTokens t) async {
    _accessCache = t.accessToken;
    _refreshCache = t.refreshToken;
    await _s.write(key: _kAccess, value: t.accessToken);
    await _s.write(key: _kRefresh, value: t.refreshToken);
  }

  Future<void> savePersonId(int id) async {
    _personIdCache = id;
    await _s.write(key: _kPersonId, value: id.toString());
  }

  Future<bool> get hasSession async => (await accessToken)?.isNotEmpty == true;

  Future<void> clear() async {
    _accessCache = null;
    _refreshCache = null;
    _personIdCache = null;
    await _s.deleteAll();
  }

  // Helper for callers that need the raw map form.
  static Map<String, dynamic> decode(String s) =>
      jsonDecode(s) as Map<String, dynamic>;
}
