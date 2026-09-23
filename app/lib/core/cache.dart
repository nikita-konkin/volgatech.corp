import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

/// One cached payload plus when it was stored.
class CachedEntry {
  final DateTime savedAt;
  final dynamic data;
  const CachedEntry(this.savedAt, this.data);
}

/// Tiny on-disk cache for offline resilience: JSON payloads (schedule,
/// exams, ...) plus raw bytes (the profile photo).
/// Not for secrets — tokens live in [Session] (secure storage).
class JsonCache {
  Directory? _dir;

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
      final f = await _file(key);
      await f.writeAsString(jsonEncode({
        'savedAt': DateTime.now().toIso8601String(),
        'data': data,
      }));
    } catch (_) {/* cache is best-effort */}
  }

  Future<CachedEntry?> get(String key) async {
    try {
      final f = await _file(key);
      if (!await f.exists()) return null;
      final m = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      return CachedEntry(
          DateTime.tryParse(m['savedAt'] as String? ?? '') ?? DateTime.now(),
          m['data']);
    } catch (_) {
      return null;
    }
  }

  Future<void> putBytes(String key, Uint8List bytes) async {
    try {
      await (await _file(key, 'bin')).writeAsBytes(bytes, flush: true);
    } catch (_) {/* cache is best-effort */}
  }

  Future<Uint8List?> getBytes(String key) async {
    try {
      final f = await _file(key, 'bin');
      if (!await f.exists()) return null;
      final bytes = await f.readAsBytes();
      return bytes.isEmpty ? null : bytes;
    } catch (_) {
      return null;
    }
  }

  Future<void> clear() async {
    try {
      final d = await _cacheDir();
      if (await d.exists()) await d.delete(recursive: true);
      _dir = null;
    } catch (_) {}
  }
}
