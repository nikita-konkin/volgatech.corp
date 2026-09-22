import '../models/schedule.dart';

/// A physical class session: one time + place + subject slot that may serve
/// several groups at once — e.g. ИТС-21 and ИТС-22 taught together in 333г at
/// 15:15. The API returns one event per group, so the UI would otherwise show
/// visual duplicates; grouping collapses them into a single slot.
class LessonSlot {
  LessonSlot(this.events);

  /// All events sharing this slot (≥1); [lead] carries the shared fields.
  final List<ScheduleEvent> events;

  ScheduleEvent get lead => events.first;

  /// True when more than one distinct group meets in this slot.
  bool get isShared => groups.length > 1;

  /// Distinct group labels in order, e.g. ["ИТС-21", "ИТС-22 (подгруппа 1)"].
  List<String> get groups {
    final seen = <String>{};
    final out = <String>[];
    for (final e in events) {
      final g = (e.fullDescription ?? '').trim();
      if (g.isEmpty) continue;
      final sub = (e.subGroup ?? '').trim();
      final label = sub.isEmpty ? g : '$g ($sub)';
      if (seen.add(label)) out.add(label);
    }
    return out;
  }
}

/// Key identifying one physical session: same time, same place, same subject and
/// work type. Different subjects (or rooms/times) never merge.
String _slotKey(ScheduleEvent e) =>
    '${e.timeBegin}|${e.timeEnd}|${e.building}|${e.room}|${e.description}|${e.typeWorkName}';

/// Collapse events that share the same time + place + subject into one
/// [LessonSlot], preserving the input order (already sorted by start time).
List<LessonSlot> groupParallelLessons(List<ScheduleEvent> events) {
  final order = <String>[];
  final byKey = <String, List<ScheduleEvent>>{};
  for (final e in events) {
    final k = _slotKey(e);
    final list = byKey.putIfAbsent(k, () {
      order.add(k);
      return <ScheduleEvent>[];
    });
    list.add(e);
  }
  return [for (final k in order) LessonSlot(byKey[k]!)];
}
