import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../models/exams.dart';
import '../models/schedule.dart';
import 'lesson_grouping.dart';

/// One entry of a calendar file: times as the university's clocks show them.
class IcsEvent {
  const IcsEvent({
    required this.uid,
    required this.start,
    required this.end,
    required this.summary,
    this.location = '',
    this.description = '',
  });

  final String uid;
  final DateTime start;
  final DateTime end;
  final String summary;
  final String location;
  final String description;
}

/// Yoshkar-Ola keeps Moscow time, UTC+3 all year (since 2014).
const _moscow = Duration(hours: 3);

/// A wall-clock time in Yoshkar-Ola as the UTC instant it is.
DateTime moscowToUtc(DateTime wall) => DateTime.utc(
        wall.year, wall.month, wall.day, wall.hour, wall.minute, wall.second)
    .subtract(_moscow);

/// An iCalendar file (RFC 5545) a phone's or computer's calendar imports.
/// Times go in UTC, so the calendar shows them right in any time zone; each
/// event keeps its [IcsEvent.uid], so importing again updates, not doubles.
String buildIcs(List<IcsEvent> events, {required String name, DateTime? now}) {
  final stamp = _utc((now ?? DateTime.now()).toUtc());
  final lines = [
    'BEGIN:VCALENDAR',
    'VERSION:2.0',
    'PRODID:-//Volgatech.Kollektiv//RU',
    'CALSCALE:GREGORIAN',
    'METHOD:PUBLISH',
    'X-WR-CALNAME:${_text(name)}',
    for (final e in events) ...[
      'BEGIN:VEVENT',
      'UID:${e.uid}',
      'DTSTAMP:$stamp',
      'DTSTART:${_utc(moscowToUtc(e.start))}',
      'DTEND:${_utc(moscowToUtc(e.end))}',
      'SUMMARY:${_text(e.summary)}',
      if (e.location.isNotEmpty) 'LOCATION:${_text(e.location)}',
      if (e.description.isNotEmpty) 'DESCRIPTION:${_text(e.description)}',
      'END:VEVENT',
    ],
    'END:VCALENDAR',
  ];
  return '${lines.map(_fold).join('\r\n')}\r\n';
}

/// 20261006T050000Z
String _utc(DateTime t) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${t.year.toString().padLeft(4, '0')}${two(t.month)}${two(t.day)}'
      'T${two(t.hour)}${two(t.minute)}${two(t.second)}Z';
}

/// TEXT as RFC 5545 escapes it.
String _text(String s) => s
    .replaceAll(r'\', r'\\')
    .replaceAll(';', r'\;')
    .replaceAll(',', r'\,')
    .replaceAll(RegExp(r'\r?\n'), r'\n');

/// A line cut into pieces of at most 75 bytes, never inside a letter; the
/// pieces after the first start with a space.
String _fold(String line) {
  final bytes = utf8.encode(line);
  if (bytes.length <= 75) return line;
  final out = StringBuffer();
  var size = 0;
  var limit = 75;
  for (final rune in line.runes) {
    final char = String.fromCharCode(rune);
    final n = utf8.encode(char).length;
    if (size + n > limit) {
      out.write('\r\n ');
      size = 0;
      limit = 74; // the space counts
    }
    out.write(char);
    size += n;
  }
  return out.toString();
}

/// «08:00:00» on [day] as a wall-clock time; null if unreadable.
DateTime? _at(DateTime day, String? time) {
  final m = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(time ?? '');
  if (m == null) return null;
  return DateTime(
      day.year, day.month, day.day, int.parse(m[1]!), int.parse(m[2]!));
}

String _uid(String kind, DateTime start, List<String?> parts) {
  final digest = sha1.convert(utf8.encode(parts.join('|'))).toString();
  return '$kind-${_utc(start).substring(0, 13)}-${digest.substring(0, 12)}'
      '@volgatech.kollektiv';
}

const _shortType = {
  'Лекции': 'лекция',
  'Практические': 'практика',
  'Лабораторные': 'лаб.',
};

/// The lessons of [days] (date → that day's events), a shared slot of
/// several groups once.
List<IcsEvent> lessonEvents(Map<DateTime, List<ScheduleEvent>> days) => [
      for (final MapEntry(key: day, value: events) in days.entries)
        for (final slot in groupParallelLessons(events))
          if ((_at(day, slot.lead.timeBegin), _at(day, slot.lead.timeEnd))
              case (final start?, final end?))
            _lesson(slot, start, end),
    ];

IcsEvent _lesson(LessonSlot slot, DateTime start, DateTime end) {
  final e = slot.lead;
  final subject = (e.description ?? '').trim();
  final type = _shortType[e.typeWorkName];
  final groups = slot.groups.join(', ');
  return IcsEvent(
    uid: _uid('lesson', start, [subject, e.roomLabel, groups]),
    start: start,
    end: end.isAfter(start) ? end : start.add(const Duration(minutes: 95)),
    summary: type == null ? subject : '$subject ($type)',
    location: e.roomLabel,
    description: [
      if ((e.typeWorkName ?? '').isNotEmpty) e.typeWorkName!,
      if (groups.isNotEmpty) 'Группы: $groups',
      if ((e.fio ?? '').isNotEmpty) 'Преподаватель: ${e.fio}',
    ].join('\n'),
  );
}

/// The exams that have a date; three hours each, as their end isn't known.
List<IcsEvent> examEvents(List<Exam> exams) => [
      for (final x in exams)
        if (x.examDate case final start?)
          IcsEvent(
            uid: _uid('exam', start, [x.subjectName, x.groupName]),
            start: start,
            end: start.add(const Duration(hours: 3)),
            summary: 'Экзамен: ${(x.subjectName ?? '').trim()}',
            location: [
              if ((x.roomName ?? '').isNotEmpty) x.roomName!,
              if ((x.buildingName ?? '').isNotEmpty) '(${x.buildingName})',
            ].join(' '),
            description:
                (x.groupName ?? '').isEmpty ? '' : 'Группа: ${x.groupName}',
          ),
    ];
