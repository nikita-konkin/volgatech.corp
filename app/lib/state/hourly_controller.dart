import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../core/foreign_memo.dart' show shortPost;
import '../core/hourly_docx.dart';
import '../core/hourly_load.dart';
import '../core/prefs.dart';
import '../data/volgatech_api.dart';
import '../models/profile.dart';
import 'memo_controller.dart' show MemoController;

/// One class as the preview shows it.
class HourlyEntry {
  const HourlyEntry(this.lesson,
      {required this.groups,
      required this.included,
      required this.topic,
      this.planItem,
      this.edited = false});

  final HourlyClass lesson;

  /// The groups printed: the picked ones among those taught together.
  final List<String> groups;
  final bool included;

  /// What the topic column says; empty past the end of the plan.
  final String topic;

  /// Which item of its plan the topic came from, unless [edited].
  final int? planItem;

  /// Typed in for this class alone.
  final bool edited;

  HourlyRow get row => HourlyRow(
        date: lesson.date,
        hours: lesson.hours,
        groups: groups,
        type: lesson.type,
        discipline: lesson.discipline,
        topic: topic,
      );
}

/// «Почасовая нагрузка»: which disciplines go in, their topic plans, the
/// months reported and the finished «Приложение к форме 28». Everything the
/// user sets is remembered per user.
class HourlyController extends ChangeNotifier {
  HourlyController({
    required VolgatechApi api,
    required int personId,
    required Prefs prefs,
    required Future<Uint8List> Function() loadTemplate,
    PersonProfile? profile,
    DateTime? today,
  })  : _api = api,
        _personId = personId,
        _prefs = prefs,
        _loadTemplate = loadTemplate {
    months = [MemoController.defaultMonth(today ?? DateTime.now())];
    header = _savedHeader() ?? _headerFromProfile(profile);
    _readSettings();
  }

  final VolgatechApi _api;
  final int _personId;
  final Prefs _prefs;
  final Future<Uint8List> Function() _loadTemplate;

  /// The months reported (first days), in order; never empty.
  late List<DateTime> months;
  late HourlyHeader header;
  bool loading = false;
  String? error;

  /// Whether the topic column is filled from the plans; off leaves it
  /// empty, for the teacher to fill in by hand.
  bool fillTopics = true;

  final Map<DateTime, List<HourlyClass>> _byMonth = {};
  final Set<String> _picked = {};
  final Map<String, List<PlanTopic>> _plans = {};
  final Map<String, String> _topics = {}; // class key -> typed-in topic
  final Set<String> _excluded = {};
  int _request = 0;
  bool _disposed = false;

  String get _prefix => 'hourly_$_personId';

  /// «Февраль — март 2026», «Сентябрь 2026», «Февраль, апрель 2026».
  String get periodLabel {
    final oneYear = months.every((m) => m.year == months.first.year);
    String named(DateTime m) {
      final n = DateFormat('LLLL', 'ru_RU').format(m);
      return oneYear ? n : '$n ${m.year}';
    }

    final text = months.length > 1 && monthsInARow(months)
        ? '${named(months.first)} — ${named(months.last)}'
        : months.map(named).join(', ');
    return text[0].toUpperCase() +
        text.substring(1) +
        (oneYear ? ' ${months.first.year}' : '');
  }

  String get fileName => 'Приложение к форме 28 ${periodTag(months)}.docx';

  /// The semester of the first month reported.
  String get semester => semesterLabel(months.first);

  /// That semester's disciplines, to pick from.
  List<HourlyCourse> get courses => coursesFrom([
        for (final m in semesterMonths(months.first)) ...?_byMonth[m],
      ]);

  bool isPicked(String discipline, String group) =>
      _picked.contains(pickKey(discipline, group));

  bool get anyPicked => _picked.isNotEmpty;

  /// The plans of the picked disciplines: discipline|type -> its classes in
  /// the semester (the most any picked group has).
  Map<String, int> get planSlots {
    final out = <String, int>{};
    for (final c in courses) {
      for (final MapEntry(key: group, value: types) in c.groups.entries) {
        if (!isPicked(c.discipline, group)) continue;
        types.forEach((t, n) {
          final k = '${c.discipline}|$t';
          if (n > (out[k] ?? 0)) out[k] = n;
        });
      }
    }
    return out;
  }

  List<PlanTopic> plan(String planKey) => _plans[planKey] ?? const [];

  /// Every class of the picked disciplines in the months reported, in date
  /// and time order, with its topic.
  List<HourlyEntry> get entries {
    final reported = {for (final m in months) m};
    final out = <HourlyEntry>[];
    // Topics run from the start of each semester, so a later report goes on
    // where the one before it stopped.
    final seen = <String, int>{};
    for (final c in _allClasses()) {
      final groups = pickedGroups(c, _picked);
      if (groups.isEmpty) continue;
      final included = !_excluded.contains(c.key);
      final track = '${semesterStart(c.date)}|${c.track}';
      final index = seen[track] ?? 0;
      if (included) seen[track] = index + 1;
      if (!reported.contains(DateTime(c.date.year, c.date.month))) continue;
      final typed = _topics[c.key];
      final fromPlan = topicAt(plan(c.planKey), index);
      out.add(HourlyEntry(
        c,
        groups: groups,
        included: included,
        topic: !fillTopics ? '' : typed ?? fromPlan?.title ?? '',
        planItem: typed == null ? fromPlan?.item : null,
        edited: typed != null,
      ));
    }
    return out;
  }

  List<HourlyRow> get rows => [
        for (final e in entries)
          if (e.included) e.row
      ];

  int get totalHours => rows.fold(0, (s, r) => s + r.hours);

  /// Loads the schedule of the months reported and of their semesters (for
  /// the disciplines and to count topics from the semester's start).
  Future<void> load({bool force = false}) async {
    final req = ++_request;
    final wanted = {
      for (final m in months) ...semesterMonths(m),
      ...months,
    }.where((m) => force || !_byMonth.containsKey(m)).toList();
    if (wanted.isEmpty) return;
    loading = true;
    error = null;
    _notify();
    try {
      final got = await Future.wait([
        for (final m in wanted)
          _api.getSchedule(_personId, m, DateTime(m.year, m.month + 1, 0)),
      ]);
      if (req != _request) return;
      for (var i = 0; i < wanted.length; i++) {
        _byMonth[wanted[i]] = hourlyClassesFrom(got[i]);
      }
    } catch (e) {
      if (req != _request) return;
      error = e.toString();
    } finally {
      if (req == _request) {
        loading = false;
        _notify();
      }
    }
  }

  Future<void> setMonths(Iterable<DateTime> picked) async {
    final ms = {for (final m in picked) DateTime(m.year, m.month)}.toList()
      ..sort();
    if (ms.isEmpty) return;
    months = ms;
    _notify();
    await load();
  }

  /// Moves the whole period a month on or back.
  Future<void> shift(int by) =>
      setMonths([for (final m in months) DateTime(m.year, m.month + by)]);

  /// Puts [discipline] in the report for [groups] (all of its groups when
  /// null), or takes it out.
  Future<void> setPicked(String discipline, bool on,
      {Iterable<String>? groups}) async {
    final all = groups ??
        [
          for (final c in courses)
            if (c.discipline == discipline) ...c.groups.keys,
        ];
    for (final g in all) {
      final k = pickKey(discipline, g);
      on ? _picked.add(k) : _picked.remove(k);
    }
    _notify();
    await _prefs.writeJson('${_prefix}_picked', _picked.toList());
  }

  Future<void> savePlan(String planKey, List<PlanTopic> topics) async {
    final clean = [
      for (final t in topics)
        if (t.title.trim().isNotEmpty)
          PlanTopic(t.title.trim(), t.count.clamp(1, 99)),
    ];
    clean.isEmpty ? _plans.remove(planKey) : _plans[planKey] = clean;
    _notify();
    await _savePlans();
  }

  /// Plans read from an earlier report; returns how many disciplines and
  /// types got one. Only those taught this semester are taken.
  Future<int> importPlans(Map<String, List<PlanTopic>> plans) async {
    final known = {
      for (final c in courses)
        for (final t in c.types) '${c.discipline}|$t',
    };
    var n = 0;
    for (final MapEntry(:key, :value) in plans.entries) {
      if (!known.contains(key) || value.isEmpty) continue;
      _plans[key] = value;
      n++;
    }
    _notify();
    await _savePlans();
    return n;
  }

  Future<void> setIncluded(HourlyEntry e, bool included) async {
    included ? _excluded.remove(e.lesson.key) : _excluded.add(e.lesson.key);
    _notify();
    await _prefs.writeJson('${_prefix}_excluded', _excluded.toList());
  }

  /// [topic] for [e] alone; empty or null goes back to the plan's.
  Future<void> setTopic(HourlyEntry e, String? topic) async {
    final t = topic?.trim() ?? '';
    t.isEmpty ? _topics.remove(e.lesson.key) : _topics[e.lesson.key] = t;
    _notify();
    await _prefs.writeJson('${_prefix}_topics', _topics);
  }

  /// Renames the plan item [e]'s topic came from: every class of that topic.
  Future<void> renamePlanTopic(HourlyEntry e, String title) async {
    final i = e.planItem;
    final t = title.trim();
    if (i == null || t.isEmpty) return;
    final p = [...plan(e.lesson.planKey)];
    p[i] = p[i].copyWith(title: t);
    await savePlan(e.lesson.planKey, p);
  }

  Future<void> setFillTopics(bool on) async {
    fillTopics = on;
    _notify();
    await _prefs.writeJson('${_prefix}_fill', on);
  }

  Future<void> saveHeader(HourlyHeader h) async {
    header = h;
    _notify();
    await _prefs.writeJson('${_prefix}_header', h.toJson());
  }

  /// The finished report for the classes that go in.
  Future<Uint8List> buildDocx() async =>
      buildHourlyDocx(await _loadTemplate(), header, rows);

  Iterable<HourlyClass> _allClasses() sync* {
    final ms = _byMonth.keys.toList()..sort();
    for (final m in ms) {
      yield* _byMonth[m]!;
    }
  }

  HourlyHeader? _savedHeader() {
    final j = _prefs.readJson('${_prefix}_header');
    return j is Map
        ? HourlyHeader.fromJson(Map<String, dynamic>.from(j))
        : null;
  }

  static HourlyHeader _headerFromProfile(PersonProfile? p) {
    final main = p?.salariesMainFirst.firstOrNull;
    return HourlyHeader(
      teacherName: p?.personFIO ?? '',
      teacherPost: shortPost(main?.postName ?? ''),
    );
  }

  void _readSettings() {
    if (_prefs.readJson('${_prefix}_picked') case final List<Object?> l) {
      _picked.addAll(l.map((e) => '$e'));
    }
    if (_prefs.readJson('${_prefix}_excluded') case final List<Object?> l) {
      _excluded.addAll(l.map((e) => '$e'));
    }
    if (_prefs.readJson('${_prefix}_topics')
        case final Map<String, Object?> m) {
      m.forEach((k, v) => _topics[k] = '$v');
    }
    if (_prefs.readJson('${_prefix}_fill') case final bool on) fillTopics = on;
    if (_prefs.readJson('${_prefix}_plans') case final Map<String, Object?> m) {
      m.forEach((k, v) {
        if (v is! List) return;
        _plans[k] = [
          for (final t in v)
            if (t is Map) PlanTopic.fromJson(Map<String, dynamic>.from(t)),
        ];
      });
    }
  }

  Future<void> _savePlans() => _prefs.writeJson('${_prefix}_plans', {
        for (final MapEntry(:key, :value) in _plans.entries)
          key: [for (final t in value) t.toJson()],
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
