import 'package:flutter_test/flutter_test.dart';
import 'package:volgatech_pro/core/ru_plural.dart';
import 'package:volgatech_pro/models/profile.dart';

void main() {
  // Synthetic payload with the SAME shape as a live GetInfo response
  // (no real personal data committed).
  final info = {
    'personId': 1,
    'isMale': true,
    'birthday': '1990-03-15T00:00:00+03:00',
    'fileName': 'photo.jpg',
    'personFIO': 'Тестов Тест Тестович',
    'postName': 'преподаватель',
    'actualSalaries': [
      {
        'isMainJob': false,
        'department': {'fullName': 'Кафедра А'},
        'dictPost': {'postName': 'преподаватель'},
      },
      {
        'isMainJob': true,
        'department': {'fullName': 'Кафедра Б'},
        'dictPost': {'postName': 'старший преподаватель'},
      },
    ],
    'personExperiences': [
      {
        'year': 7,
        'month': 2,
        'dictExperienceType': {'experienceTypeName': 'Общий стаж'},
      },
    ],
  };

  test('PersonProfile.fromInfo parses the real GetInfo shape', () {
    final p = PersonProfile.fromInfo(Map<String, dynamic>.from(info), personId: 1);
    expect(p.fullName, 'Тестов Тест Тестович');
    expect(p.photoName, 'photo.jpg');
    // birthday parsed as a wall-clock date (tz offset ignored)
    expect(p.birthday, DateTime(1990, 3, 15));
    expect(p.salaries.length, 2);

    // main job floats to the front
    final first = p.salariesMainFirst.first;
    expect(first.isMainJob, isTrue);
    expect(first.postName, 'старший преподаватель');
    expect(first.departmentName, 'Кафедра Б');

    // experience renders like the portal
    final e = p.experiences.single;
    expect(e.typeName, 'Общий стаж');
    expect(humanYearsMonths(e.year, e.month), '7 лет 2 месяца');
  });

  test('cache round-trip keeps birthday + main-job flag', () {
    final p = PersonProfile.fromInfo(Map<String, dynamic>.from(info), personId: 1);
    final c = PersonProfile.fromCache(p.toJson());
    expect(c.birthday, DateTime(1990, 3, 15));
    expect(c.salariesMainFirst.first.isMainJob, isTrue);
    expect(c.salariesMainFirst.first.postName, 'старший преподаватель');
  });
}
