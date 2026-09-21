import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// One cached payload plus when it was stored.
class CachedEntry {
  final DateTime savedAt;
  final dynamic data;
  const CachedEntry(this.savedAt, this.data);
}

/// Tiny on-disk JSON cache for offline resilience (schedule, exams, ...).
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

  Future<File> _file(String key) async =>
      File('${(await _cacheDir()).path}/${_safe(key)}.json');

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

  Future<void> clear() async {
    try {
      final d = await _cacheDir();
      if (await d.exists()) await d.delete(recursive: true);
      _dir = null;
    } catch (_) {}
  }
}
