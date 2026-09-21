import '../core/date_utils.dart';

/// Response model for /api/Calendar/GetPersonCalendar/... — an array of days,
/// each with a list of events. Fields verified against live capture.
class ScheduleDay {
  final DateTime date;
  final List<ScheduleEvent> events;

  const ScheduleDay({required this.date, required this.events});

  factory ScheduleDay.fromJson(Map<String, dynamic> j) => ScheduleDay(
        // TZ-independent: key the day by its calendar date, not a converted instant.
        date: apiCalendarDate(j['date'] as String),
        events: ((j['events'] as List?) ?? const [])
            .map((e) => ScheduleEvent.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'events': events.map((e) => e.toJson()).toList(),
      };
}

class ScheduleEvent {
  final String? building; // "III"
  final String? category; // TimeTable | Event | Private
  final DateTime? date;
  final String? description; // subject name
  final String? fio; // teacher
  final String? fullDescription; // group, e.g. "ИСТ-110"
  final String? subGroup;
  final String? room; // "438а"
  final String? timeBegin; // "08:00:00"
  final String? timeEnd; // "09:35:00"
  final String? typeWorkName; // Лекции | Практические ...
  final int? weekNumber;
  final String? weekTypeName; // "Красная неделя"
  final String? htmlColorCode;
  final String? url;

  const ScheduleEvent({
    this.building,
    this.category,
    this.date,
    this.description,
    this.fio,
    this.fullDescription,
    this.subGroup,
    this.room,
    this.timeBegin,
    this.timeEnd,
    this.typeWorkName,
    this.weekNumber,
    this.weekTypeName,
    this.htmlColorCode,
    this.url,
  });

  factory ScheduleEvent.fromJson(Map<String, dynamic> j) => ScheduleEvent(
        building: j['building'] as String?,
        category: j['category'] as String?,
        date: j['date'] != null ? apiWallClock(j['date'] as String) : null,
        description: j['description'] as String?,
        fio: j['fio'] as String?,
        fullDescription: j['fullDescription'] as String?,
        subGroup: j['subGroup'] as String?,
        room: j['room'] as String?,
        timeBegin: j['timeBegin'] as String?,
        timeEnd: j['timeEnd'] as String?,
        typeWorkName: j['typeWorkName'] as String?,
        weekNumber: j['weekNumber'] as int?,
        weekTypeName: j['weekTypeName'] as String?,
        htmlColorCode: j['htmlColorCode'] as String?,
        url: j['url'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'building': building,
        'category': category,
        'date': date?.toIso8601String(),
        'description': description,
        'fio': fio,
        'fullDescription': fullDescription,
        'subGroup': subGroup,
        'room': room,
        'timeBegin': timeBegin,
        'timeEnd': timeEnd,
        'typeWorkName': typeWorkName,
        'weekNumber': weekNumber,
        'weekTypeName': weekTypeName,
        'htmlColorCode': htmlColorCode,
        'url': url,
      };

  /// "08:00 - 09:35"
  String get timeRange {
    String hhmm(String? t) =>
        (t != null && t.length >= 5) ? t.substring(0, 5) : (t ?? '');
    final a = hhmm(timeBegin);
    final b = hhmm(timeEnd);
    return b.isEmpty ? a : '$a - $b';
  }

  /// "438а (III)"
  String get roomLabel {
    if ((room ?? '').isEmpty) return building ?? '';
    return building != null && building!.isNotEmpty
        ? '$room ($building)'
        : room!;
  }
}
