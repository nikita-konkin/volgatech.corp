// Person profile.
// - /api/Person/GetProfiles -> array; element [0] gives `personId`.
// - /api/Person/GetInfo/{id} -> { personFIO, fileName, actualSalaries[],
//   personExperiences[] }  (field names verified from the original templates).

class SalaryEntry {
  final String? postName; // dictPost.postName
  final String? departmentName; // department.fullName
  const SalaryEntry({this.postName, this.departmentName});

  factory SalaryEntry.fromJson(Map<String, dynamic> j) => SalaryEntry(
        postName: (j['dictPost']?['postName'] ?? j['postName']) as String?,
        departmentName:
            (j['department']?['fullName'] ?? j['departmentName']) as String?,
      );

  Map<String, dynamic> toJson() =>
      {'postName': postName, 'departmentName': departmentName};

  factory SalaryEntry.fromCache(Map<String, dynamic> j) => SalaryEntry(
        postName: j['postName'] as String?,
        departmentName: j['departmentName'] as String?,
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
  final List<SalaryEntry> salaries;
  final List<ExperienceEntry> experiences;

  const PersonProfile({
    required this.personId,
    this.personFIO,
    this.fileName,
    this.salaries = const [],
    this.experiences = const [],
  });

  String? get fullName => personFIO;
  String? get photoName => fileName;

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
        'salaries': salaries.map((e) => e.toJson()).toList(),
        'experiences': experiences.map((e) => e.toJson()).toList(),
      };

  factory PersonProfile.fromCache(Map<String, dynamic> j) => PersonProfile(
        personId: (j['personId'] ?? 0) as int,
        personFIO: j['personFIO'] as String?,
        fileName: j['fileName'] as String?,
        salaries: ((j['salaries'] as List?) ?? const [])
            .map((e) => SalaryEntry.fromCache(Map<String, dynamic>.from(e)))
            .toList(),
        experiences: ((j['experiences'] as List?) ?? const [])
            .map((e) => ExperienceEntry.fromCache(Map<String, dynamic>.from(e)))
            .toList(),
      );
}
