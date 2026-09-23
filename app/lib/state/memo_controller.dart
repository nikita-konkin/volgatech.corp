import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../core/foreign_memo.dart';
import '../core/memo_docx.dart';
import '../core/prefs.dart';
import '../data/volgatech_api.dart';
import '../models/profile.dart';

/// One class as shown in the preview: the schedule row plus the user's edits.
class MemoEntry {
  const MemoEntry(this.row, {required this.included, required this.discipline});

  /// As found in the schedule (or added by hand) — its [MemoRow.key] is what
  /// exclusions are remembered by.
  final MemoRow row;
  final bool included;

  /// Subject name as the memo will print it (the user may shorten it).
  final String discipline;

  MemoRow get forMemo => row.copyWith(discipline: discipline);
}

/// The monthly foreign-language memo: which classes go in, the header fields,
/// and the finished .docx. Edits are remembered per user and month.
class MemoController extends ChangeNotifier {
  MemoController({
    required VolgatechApi api,
    required int personId,
    required Prefs prefs,
    required Future<Uint8List> Function() loadTemplate,
    PersonProfile? profile,
    DateTime? today,
  })  : _api = api,
        _personId = personId,
        _prefs = prefs,
        _loadTemplate = loadTemplate,
        month = defaultMonth(today ?? DateTime.now()) {
    header = _savedHeader() ?? _headerFromProfile(profile);
    final aliases = _prefs.readJson(_aliasesKey);
    if (aliases is Map) {
      aliases.forEach((k, v) => _aliases['$k'] = '$v');
    }
    _readDraft();
  }

  final VolgatechApi _api;
  final int _personId;
  final Prefs _prefs;
  final Future<Uint8List> Function() _loadTemplate;

  /// First day of the month being reported.
  DateTime month;
  late MemoHeader header;
  bool loading = false;
  String? error;

  List<MemoRow> _fromSchedule = [];
  final List<MemoRow> _manual = [];
  final Set<String> _excluded = {};
  final Map<String, String> _aliases = {}; // schedule name -> memo name
  int _request = 0;
  bool _disposed = false;

  /// The memo is written after the month ends: during the first days of a
  /// month the previous one is the likely target.
  static DateTime defaultMonth(DateTime today) => today.day <= 10
      ? DateTime(today.year, today.month - 1)
      : DateTime(today.year, today.month);

  String get _prefix => 'memo_$_personId';
  String get _headerKey => '${_prefix}_header';
  String get _aliasesKey => '${_prefix}_aliases';
  String get _draftKey =>
      '${_prefix}_draft_${DateFormat('yyyy-MM').format(month)}';

  /// «сентябрь 2026»
  String get monthLabel => DateFormat('LLLL y', 'ru_RU').format(month);

  String get fileName => 'Иностр студенты $monthLabel.docx';

  /// Every class of the month, in date/time order.
  List<MemoEntry> get entries {
    final rows = [..._fromSchedule, ..._manual]..sort((a, b) {
        final d = a.date.compareTo(b.date);
        return d != 0 ? d : a.time.compareTo(b.time);
      });
    return [
      for (final r in rows)
        MemoEntry(r,
            included: !_excluded.contains(r.key),
            discipline: _aliases[r.discipline] ?? r.discipline),
    ];
  }

  List<MemoRow> get memoRows => [
        for (final e in entries)
          if (e.included) e.forMemo
      ];

  int get totalHours => memoRows.fold(0, (s, r) => s + r.hours);

  /// Subject names seen this month (for the "add class" form).
  List<String> get disciplines =>
      {for (final e in entries) e.discipline}.toList()..sort();

  Future<void> load() async {
    final req = ++_request;
    final first = month;
    final last = DateTime(month.year, month.month + 1, 0);
    loading = true;
    error = null;
    _notify();
    try {
      final days = await _api.getSchedule(_personId, first, last);
      if (req != _request) return; // the user moved to another month
      _fromSchedule = memoRowsFrom(days);
    } catch (e) {
      if (req != _request) return;
      _fromSchedule = [];
      error = e.toString();
    } finally {
      if (req == _request) {
        loading = false;
        _notify();
      }
    }
  }

  Future<void> nextMonth() => _goTo(DateTime(month.year, month.month + 1));
  Future<void> prevMonth() => _goTo(DateTime(month.year, month.month - 1));

  Future<void> _goTo(DateTime m) {
    month = m;
    _fromSchedule = [];
    _readDraft();
    return load();
  }

  Future<void> setIncluded(MemoEntry e, bool included) async {
    if (included) {
      _excluded.remove(e.row.key);
    } else {
      _excluded.add(e.row.key);
    }
    _notify();
    await _saveDraft();
  }

  Future<void> addManual(MemoRow row) async {
    _manual.add(row);
    _notify();
    await _saveDraft();
  }

  Future<void> removeManual(MemoRow row) async {
    _manual.removeWhere((r) => r.key == row.key);
    _excluded.remove(row.key);
    _notify();
    await _saveDraft();
  }

  /// Prints [scheduleName] as [memoName] in this and later memos.
  Future<void> renameDiscipline(String scheduleName, String memoName) async {
    final name = memoName.trim();
    if (name.isEmpty || name == scheduleName) {
      _aliases.remove(scheduleName);
    } else {
      _aliases[scheduleName] = name;
    }
    _notify();
    await _prefs.writeJson(_aliasesKey, _aliases);
  }

  Future<void> saveHeader(MemoHeader h) async {
    header = h;
    _notify();
    await _prefs.writeJson(_headerKey, h.toJson());
  }

  /// The finished memo for the included classes.
  Future<Uint8List> buildDocx() async =>
      buildMemoDocx(await _loadTemplate(), header, memoRows);

  MemoHeader? _savedHeader() {
    final j = _prefs.readJson(_headerKey);
    return j is Map ? MemoHeader.fromJson(Map<String, dynamic>.from(j)) : null;
  }

  static MemoHeader _headerFromProfile(PersonProfile? p) {
    final main = p?.salariesMainFirst.firstOrNull;
    final department = main?.departmentName ?? '';
    return MemoHeader(
      teacherName: p?.personFIO ?? '',
      teacherPost: shortPost(main?.postName ?? ''),
      department: department,
      departmentDative: departmentDative(department),
    );
  }

  void _readDraft() {
    _manual.clear();
    _excluded.clear();
    final j = _prefs.readJson(_draftKey);
    if (j is! Map) return;
    for (final k in (j['excluded'] as List? ?? const [])) {
      _excluded.add('$k');
    }
    for (final r in (j['manual'] as List? ?? const [])) {
      if (r is Map) _manual.add(MemoRow.fromJson(Map<String, dynamic>.from(r)));
    }
  }

  Future<void> _saveDraft() => _prefs.writeJson(_draftKey, {
        'excluded': _excluded.toList(),
        'manual': [for (final r in _manual) r.toJson()],
      });

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
