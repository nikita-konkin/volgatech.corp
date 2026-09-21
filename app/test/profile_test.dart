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
        'salary': 84.35,
        'salaryType': 2, // почасовая
        'dateBegin': '2026-09-02T22:31:25.17+03:00',
        'department': {'fullName': 'Кафедра А'},
        'dictPost': {'postName': 'преподаватель', 'postOrder': 0},
      },
      {
        'isMainJob': true,
        'salary': 100.0,
        'salaryType': 1, // ставка
        'dateBegin': '2026-03-05T14:27:00.003+03:00',
        'department': {'fullName': 'Кафедра Б'},
        'dictPost': {'postName': 'старший преподаватель', 'postOrder': 1},
      },
      {
        'isMainJob': false,
        'salary': 20.0,
        'salaryType': 3, // ставка (research)
        'dateBegin': '2026-06-19T22:31:29.65+03:00',
        'department': {'fullName': 'Сектор'},
        'dictPost': {'postName': 'научный сотрудник', 'postOrder': 0},
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
    expect(p.salaries.length, 3);

    // main job floats to the front, with its rate + start date parsed
    final first = p.salariesMainFirst.first;
    expect(first.isMainJob, isTrue);
    expect(first.postName, 'старший преподаватель');
    expect(first.departmentName, 'Кафедра Б');
    expect(first.salary, 100.0);
    expect(first.postOrder, 1);
    expect(first.dateBegin, DateTime(2026, 3, 5));
    expect(first.isHourly, isFalse); // salaryType 1

    // salaryType 2 appointment is flagged hourly (не показываем %)
    final hourly = p.salaries.firstWhere((s) => s.salaryType == 2);
    expect(hourly.isHourly, isTrue);
    // hours ≈ salary% × norm (84.35% × 300 = 253.05)
    expect(hourly.hourlyHours, closeTo(253.05, 0.001));

    // combined load counts only the ставка rows (100 + 20), not the hourly one
    expect(p.rateTotalPercent, 120.0);
    expect(p.hasHourly, isTrue);
    expect(p.hourlyHoursTotal, closeTo(253.05, 0.001));

    // experience renders like the portal
    final e = p.experiences.single;
    expect(e.typeName, 'Общий стаж');
    expect(humanYearsMonths(e.year, e.month), '7 лет 2 месяца');
  });

  test('cache round-trip keeps birthday + main-job flag', () {
    final p = PersonProfile.fromInfo(Map<String, dynamic>.from(info), personId: 1);
    final c = PersonProfile.fromCache(p.toJson());
    expect(c.birthday, DateTime(1990, 3, 15));
    final first = c.salariesMainFirst.first;
    expect(first.isMainJob, isTrue);
    expect(first.postName, 'старший преподаватель');
    expect(first.salary, 100.0);
    expect(first.postOrder, 1);
    expect(first.dateBegin, DateTime(2026, 3, 5));
  });
}
