import 'dart:async';

import 'package:flutter/foundation.dart';

import 'prefs.dart';

/// One error the app ran into (the same one again only counts up).
@immutable
class CrashEntry {
  const CrashEntry({
    required this.at,
    required this.version,
    required this.error,
    required this.stack,
    this.count = 1,
  });

  factory CrashEntry.fromJson(Map<String, dynamic> j) => CrashEntry(
        at: DateTime.tryParse(j['at'] as String? ?? '') ?? DateTime(2000),
        version: j['version'] as String? ?? '',
        error: j['error'] as String? ?? '',
        stack: j['stack'] as String? ?? '',
        count: j['count'] as int? ?? 1,
      );

  /// The last time.
  final DateTime at;
  final String version;
  final String error;
  final String stack;
  final int count;

  String get title => error.split('\n').first;

  /// Which errors are «the same»: the message and where it came from.
  String get _key => '$title|${stack.split('\n').firstOrNull ?? ''}';

  Map<String, Object> toJson() => {
        'at': at.toIso8601String(),
        'version': version,
        'error': error,
        'stack': stack,
        'count': count,
      };
}

/// What a report keeps of an error's text: no addresses, sign-in tokens or
/// long numbers (people's ids), which errors from the network can carry.
String scrubReport(String s) => s
    .replaceAll(RegExp(r'eyJ[\w-]+\.[\w-]+\.[\w-]+'), '<токен>')
    .replaceAll(RegExp(r'Bearer\s+\S+'), 'Bearer <токен>')
    .replaceAll(RegExp(r'[\w.+-]+@[\w-]+(\.[\w-]+)+'), '<почта>')
    .replaceAll(RegExp(r'(?<![\w.])\d{5,}(?![\w.])'), '<число>');

/// Errors the app ran into, kept on the device — the last [limit] — until
/// they are shared from Settings → «Отчёты об ошибках». No server: nothing
/// leaves the device unless its owner sends it, and they can read it first.
class CrashLog extends ChangeNotifier {
  CrashLog(this._prefs, {this.platform = ''}) : _entries = _read(_prefs);

  static const limit = 20;
  static const _key = 'crash_log';

  final Prefs _prefs;
  List<CrashEntry> _entries;

  /// The installed version, once known (PackageInfo is asynchronous).
  String version = '';

  /// «Android», «браузер»…: for the report's heading.
  final String platform;

  /// Newest first.
  List<CrashEntry> get entries => _entries;

  static List<CrashEntry> _read(Prefs prefs) => switch (prefs.readJson(_key)) {
        final List<dynamic> list => [
            for (final e in list)
              if (e is Map<String, dynamic>) CrashEntry.fromJson(e)
          ],
        _ => const [],
      };

  /// Every error from now on: Flutter's (a widget that failed to build,
  /// say) and any left uncaught. What was done with them before still is.
  void install() {
    final flutter = FlutterError.onError;
    FlutterError.onError = (details) {
      flutter?.call(details);
      record(details.exception, details.stack);
    };
    final platform = PlatformDispatcher.instance.onError;
    PlatformDispatcher.instance.onError = (error, stack) {
      record(error, stack);
      return platform?.call(error, stack) ?? false;
    };
  }

  void record(Object error, StackTrace? stack, {DateTime? at}) {
    try {
      final entry = CrashEntry(
        at: at ?? DateTime.now(),
        version: version,
        error: scrubReport(_cut('$error', 1000)),
        stack: scrubReport([
          for (final line in '${stack ?? ''}'.split('\n'))
            if (line.trim().isNotEmpty) line
        ].take(20).join('\n')),
      );
      final same = _entries.where((e) => e._key == entry._key).firstOrNull;
      _entries = [
        if (same == null)
          entry
        else
          CrashEntry(
              at: entry.at,
              version: entry.version,
              error: entry.error,
              stack: entry.stack,
              count: same.count + 1),
        for (final e in _entries)
          if (!identical(e, same)) e,
      ].take(limit).toList();
      unawaited(_save());
      // Not in the middle of a build that failed.
      scheduleMicrotask(notifyListeners);
    } on Object {
      // The log must never be a reason to fail.
    }
  }

  Future<void> clear() async {
    _entries = const [];
    notifyListeners();
    await _save();
  }

  Future<void> _save() =>
      _prefs.writeJson(_key, [for (final e in _entries) e.toJson()]);

  /// The text to send: what, which version, how often, and where.
  String report() {
    final b = StringBuffer('Волгатех.Коллектив')
      ..write(version.isEmpty ? '' : ' $version')
      ..write(platform.isEmpty ? '' : ' · $platform')
      ..write('\nОшибок: ${_entries.length}\n');
    for (final e in _entries) {
      b
        ..write('\n— ${e.at.toIso8601String().substring(0, 19)}')
        ..write(e.version.isEmpty ? '' : ' · ${e.version}')
        ..write(e.count > 1 ? ' · ×${e.count}' : '')
        ..write('\n${e.error}\n')
        ..write(e.stack.isEmpty ? '' : '${e.stack}\n');
    }
    return b.toString();
  }

  static String _cut(String s, int n) =>
      s.length <= n ? s : '${s.substring(0, n)}…';
}
