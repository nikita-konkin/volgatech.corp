// Person profile.
// - /api/Person/GetProfiles -> array; element [0] gives `personId`.
// - /api/Person/GetInfo/{id} -> { personFIO, fileName, birthday, isMale,
//   postName, actualSalaries[]{ isMainJob, dictPost{postName}, department{fullName} },
//   personExperiences[]{ year, month, dictExperienceType{experienceTypeName} } }
//   (shape verified against a live capture, 2026-09-21).

import '../core/date_utils.dart';

class SalaryEntry {
  final String? postName; // dictPost.postName
  final String? departmentName; // department.fullName
  final bool isMainJob; // actualSalaries[].isMainJob — the primary appointment
  final double? salary; // actualSalaries[].salary — ставка share (%) OR hours
  final DateTime? dateBegin; // actualSalaries[].dateBegin (date only)
  final int? postOrder; // dictPost.postOrder — post rank (higher = more senior)
  final int? salaryType; // 1 & 3 = ставка (rate), 2 = почасовая (hourly)
  const SalaryEntry({
    this.postName,
    this.departmentName,
    this.isMainJob = false,
    this.salary,
    this.dateBegin,
    this.postOrder,
    this.salaryType,
  });

  /// salaryType 2 = почасовая; the [salary] number is then NOT a ставка share,
  /// so it must not be rendered as a percentage. (Confirmed with the user; in
  /// the live data types 1 & 3 sum to exactly the 1.5-ставки/150% ceiling.)
  bool get isHourly => salaryType == 2;

  static DateTime? _date(dynamic v) =>
      (v is String && v.isNotEmpty) ? apiCalendarDate(v) : null;

  factory SalaryEntry.fromJson(Map<String, dynamic> j) => SalaryEntry(
        postName: (j['dictPost']?['postName'] ?? j['postName']) as String?,
        departmentName:
            (j['department']?['fullName'] ?? j['departmentName']) as String?,
        isMainJob: j['isMainJob'] == true,
        salary: (j['salary'] as num?)?.toDouble(),
        dateBegin: _date(j['dateBegin']),
        postOrder: (j['dictPost']?['postOrder'] ?? j['postOrder']) as int?,
        salaryType: j['salaryType'] as int?,
      );

  Map<String, dynamic> toJson() => {
        'postName': postName,
        'departmentName': departmentName,
        'isMainJob': isMainJob,
        'salary': salary,
        'dateBegin': dateBegin?.toIso8601String(),
        'postOrder': postOrder,
        'salaryType': salaryType,
      };

  factory SalaryEntry.fromCache(Map<String, dynamic> j) => SalaryEntry(
        postName: j['postName'] as String?,
        departmentName: j['departmentName'] as String?,
        isMainJob: j['isMainJob'] == true,
        salary: (j['salary'] as num?)?.toDouble(),
        dateBegin: _date(j['dateBegin']),
        postOrder: j['postOrder'] as int?,
        salaryType: j['salaryType'] as int?,
      );
}

class ExperienceEntry {
  final String? typeName; // dictExperienceType.experienceTypeName
  final int? year;
  final int? month;
  const ExperienceEntry({this.typeName, this.year, this.month});

  factory ExperienceEntry.fromJson(Map<String, dynamic> j) => ExperienceEntry(
        typeName: (j['dictExperienceType']?['experienceTypeName'] ??
            j['typeName']) as String?,
        year: j['year'] as int?,
        month: j['month'] as int?,
      );

  Map<String, dynamic> toJson() =>
      {'typeName': typeName, 'year': year, 'month': month};

  factory ExperienceEntry.fromCache(Map<String, dynamic> j) => ExperienceEntry(
        typeName: j['typeName'] as String?,
        year: j['year'] as int?,
        month: j['month'] as int?,
      );
}

class PersonProfile {
  final int personId;
  final String? personFIO; // full name
  final String? fileName; // photo file name ("<guid>.jpg")
  final DateTime? birthday; // birthday (date only)
  final List<SalaryEntry> salaries;
  final List<ExperienceEntry> experiences;

  const PersonProfile({
    required this.personId,
    this.personFIO,
    this.fileName,
    this.birthday,
    this.salaries = const [],
    this.experiences = const [],
  });

  String? get fullName => personFIO;
  String? get photoName => fileName;

  /// Combined ставка load (percent) — sum of the rate-based appointments only
  /// (hourly ones aren't ставки). E.g. 100 + 20 + 10 + 20 = 150 (= 1.5 ставки).
  double get rateTotalPercent => salaries
      .where((s) => !s.isHourly && s.salary != null)
      .fold(0.0, (sum, s) => sum + s.salary!);

  bool get hasHourly => salaries.any((s) => s.isHourly);

  /// Appointments ranked: the primary one (isMainJob) first, then by post rank
  /// (dictPost.postOrder, higher = more senior). Stable for equal keys.
  List<SalaryEntry> get salariesMainFirst {
    final indexed = salaries.asMap().entries.toList();
    indexed.sort((a, b) {
      final byMain = (b.value.isMainJob ? 1 : 0) - (a.value.isMainJob ? 1 : 0);
      if (byMain != 0) return byMain;
      final byOrder = (b.value.postOrder ?? 0) - (a.value.postOrder ?? 0);
      if (byOrder != 0) return byOrder;
      return a.key - b.key; // keep original order otherwise
    });
    return indexed.map((e) => e.value).toList();
  }

  static DateTime? _date(dynamic v) =>
      (v is String && v.isNotEmpty) ? apiCalendarDate(v) : null;

  /// From /api/Person/GetProfiles element (only personId guaranteed).
  factory PersonProfile.fromProfiles(Map<String, dynamic> j) => PersonProfile(
        personId: (j['personId'] ?? j['id'] ?? 0) as int,
        personFIO: j['personFIO'] as String?,
        fileName: j['fileName'] as String?,
      );

  /// From /api/Person/GetInfo/{id}.
  factory PersonProfile.fromInfo(Map<String, dynamic> j, {required int personId}) =>
      PersonProfile(
        personId: (j['personId'] ?? personId) as int,
        personFIO: j['personFIO'] as String?,
        fileName: j['fileName'] as String?,
        birthday: _date(j['birthday']),
        salaries: ((j['actualSalaries'] as List?) ?? const [])
            .map((e) => SalaryEntry.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        experiences: ((j['personExperiences'] as List?) ?? const [])
            .map((e) => ExperienceEntry.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'personId': personId,
        'personFIO': personFIO,
        'fileName': fileName,
        'birthday': birthday?.toIso8601String(),
        'salaries': salaries.map((e) => e.toJson()).toList(),
        'experiences': experiences.map((e) => e.toJson()).toList(),
      };

  factory PersonProfile.fromCache(Map<String, dynamic> j) => PersonProfile(
        personId: (j['personId'] ?? 0) as int,
        personFIO: j['personFIO'] as String?,
        fileName: j['fileName'] as String?,
        birthday: _date(j['birthday']),
        salaries: ((j['salaries'] as List?) ?? const [])
            .map((e) => SalaryEntry.fromCache(Map<String, dynamic>.from(e)))
            .toList(),
        experiences: ((j['experiences'] as List?) ?? const [])
            .map((e) => ExperienceEntry.fromCache(Map<String, dynamic>.from(e)))
            .toList(),
      );
}
