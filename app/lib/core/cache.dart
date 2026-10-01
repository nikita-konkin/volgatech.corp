import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One cached payload plus when it was stored.
class CachedEntry {
  final DateTime savedAt;
  final dynamic data;
  const CachedEntry(this.savedAt, this.data);
}

/// Tiny on-disk cache for offline resilience: JSON payloads (schedule,
/// exams, ...) plus raw bytes (the profile photo). In a browser, which has no
/// files, the site's local storage instead.
/// Not for secrets — tokens live in [Session] (secure storage).
class JsonCache {
  JsonCache({bool? inBrowser}) : _browser = inBrowser ?? kIsWeb;

  final bool _browser;
  Directory? _dir;

  /// Local storage holds a few megabytes for the whole site: a bigger photo
  /// is simply fetched again next time.
  static const _maxBrowserBytes = 256 * 1024;
  static const _browserPrefix = 'cache:';

  String _browserKey(String key, String ext) =>
      '$_browserPrefix${_safe(key)}.$ext';

  Future<Directory> _cacheDir() async {
    if (_dir != null) return _dir!;
    final base = await getApplicationSupportDirectory();
    final d = Directory('${base.path}/cache');
    if (!await d.exists()) await d.create(recursive: true);
    return _dir = d;
  }

  String _safe(String key) => key.replaceAll(RegExp(r'[^A-Za-z0-9_.-]'), '_');

  Future<File> _file(String key, [String ext = 'json']) async =>
      File('${(await _cacheDir()).path}/${_safe(key)}.$ext');

  Future<void> put(String key, Object data) async {
    try {
      final text = jsonEncode({
        'savedAt': DateTime.now().toIso8601String(),
        'data': data,
      });
      if (_browser) {
        await (await SharedPreferences.getInstance())
            .setString(_browserKey(key, 'json'), text);
      } else {
        await (await _file(key)).writeAsString(text);
      }
    } catch (_) {/* cache is best-effort */}
  }

  Future<CachedEntry?> get(String key) async {
    try {
      final String text;
      if (_browser) {
        final saved = (await SharedPreferences.getInstance())
            .getString(_browserKey(key, 'json'));
        if (saved == null) return null;
        text = saved;
      } else {
        final f = await _file(key);
        if (!await f.exists()) return null;
        text = await f.readAsString();
      }
      final m = jsonDecode(text) as Map<String, dynamic>;
      return CachedEntry(
          DateTime.tryParse(m['savedAt'] as String? ?? '') ?? DateTime.now(),
          m['data']);
    } catch (_) {
      return null;
    }
  }

  Future<void> putBytes(String key, Uint8List bytes) async {
    try {
      if (_browser) {
        if (bytes.length > _maxBrowserBytes) return;
        await (await SharedPreferences.getInstance())
            .setString(_browserKey(key, 'bin'), base64Encode(bytes));
      } else {
        await (await _file(key, 'bin')).writeAsBytes(bytes, flush: true);
      }
    } catch (_) {/* cache is best-effort */}
  }

  Future<Uint8List?> getBytes(String key) async {
    try {
      if (_browser) {
        final saved = (await SharedPreferences.getInstance())
            .getString(_browserKey(key, 'bin'));
        return saved == null || saved.isEmpty ? null : base64Decode(saved);
      }
      final f = await _file(key, 'bin');
      if (!await f.exists()) return null;
      final bytes = await f.readAsBytes();
      return bytes.isEmpty ? null : bytes;
    } catch (_) {
      return null;
    }
  }

  /// Drops every entry whose key starts with [prefix].
  Future<void> removePrefix(String prefix) async {
    try {
      if (_browser) {
        final prefs = await SharedPreferences.getInstance();
        final start = '$_browserPrefix${_safe(prefix)}';
        for (final k in prefs.getKeys().where((k) => k.startsWith(start))) {
          await prefs.remove(k);
        }
        return;
      }
      final d = await _cacheDir();
      final start = _safe(prefix);
      await for (final f in d.list()) {
        if (f is File && f.uri.pathSegments.last.startsWith(start)) {
          await f.delete();
        }
      }
    } catch (_) {/* cache is best-effort */}
  }

  Future<void> clear() async {
    try {
      if (_browser) {
        await removePrefix('');
        return;
      }
      final d = await _cacheDir();
      if (await d.exists()) await d.delete(recursive: true);
      _dir = null;
    } catch (_) {}
  }
}
