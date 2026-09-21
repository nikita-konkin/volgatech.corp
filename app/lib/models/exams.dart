// Models for /api/Exams/* (fields verified against live capture).
import '../core/date_utils.dart';

class StudyYear {
  final int value; // studyYearValue, e.g. 2025
  final String name; // "2025 / 2026"
  const StudyYear({required this.value, required this.name});

  factory StudyYear.fromJson(Map<String, dynamic> j) => StudyYear(
        value: (j['studyYearValue'] ?? j['value'] ?? 0) as int,
        name: (j['studyYearName'] ?? j['name'] ?? '') as String,
      );

  Map<String, dynamic> toJson() =>
      {'studyYearValue': value, 'studyYearName': name};
}

class Exam {
  final String? buildingName;
  final DateTime? examDate;
  final String? roomName;
  final String? subjectName;
  final String? groupName;

  const Exam({
    this.buildingName,
    this.examDate,
    this.roomName,
    this.subjectName,
    this.groupName,
  });

  factory Exam.fromJson(Map<String, dynamic> j) => Exam(
        buildingName: j['buildingName'] as String?,
        examDate: j['examDate'] != null
            ? apiWallClock(j['examDate'] as String)
            : null,
        roomName: j['roomName'] as String?,
        subjectName: j['subjectName'] as String?,
        groupName: j['groupName'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'buildingName': buildingName,
        'examDate': examDate?.toIso8601String(),
        'roomName': roomName,
        'subjectName': subjectName,
        'groupName': groupName,
      };

  /// "307 (III)"
  String get roomLabel {
    if ((roomName ?? '').isEmpty) return buildingName ?? '';
    return (buildingName ?? '').isNotEmpty
        ? '$roomName ($buildingName)'
        : roomName!;
  }
}
