import 'package:flutter_test/flutter_test.dart';
import 'package:volgatech_pro/models/exams.dart';
import 'package:volgatech_pro/models/profile.dart';
import 'package:volgatech_pro/models/schedule.dart';

void main() {
  test('ScheduleDay/ScheduleEvent parse and format', () {
    final day = ScheduleDay.fromJson({
      'date': '2026-09-21T00:00:00+03:00',
      'events': [
        {
          'building': 'III',
          'category': 'TimeTable',
          'date': '2026-09-21T00:00:00+03:00',
          'description': 'Машинное обучение',
          'fio': 'Иванов И.И.',
          'fullDescription': 'ИСТ-410',
          'subGroup': null,
          'room': '414',
          'timeBegin': '09:45:00',
          'timeEnd': '11:20:00',
          'typeWorkName': 'Лекции',
          'weekNumber': 1,
          'weekTypeName': 'Красная неделя',
        }
      ],
    });
    expect(day.date.day, 21);
    expect(day.events.length, 1);
    final e = day.events.first;
    expect(e.timeRange, '09:45 - 11:20');
    expect(e.roomLabel, '414 (III)');
    expect(e.description, 'Машинное обучение');

    // round-trips through cache JSON
    final again = ScheduleDay.fromJson(day.toJson());
    expect(again.date.day, 21);
    expect(again.events.first.roomLabel, '414 (III)');
  });

  test('Exam / StudyYear parse', () {
    final y = StudyYear.fromJson({'studyYearValue': 2025, 'studyYearName': '2025 / 2026'});
    expect(y.value, 2025);
    expect(y.name, '2025 / 2026');

    final ex = Exam.fromJson({
      'buildingName': 'III',
      'examDate': '2025-12-24T09:00:00+03:00',
      'roomName': '333б',
      'subjectName': 'МОиАД',
      'groupName': 'ИСТ-41',
    });
    expect(ex.examDate!.day, 24);
    expect(ex.examDate!.hour, 9);
    expect(ex.roomLabel, '333б (III)');
  });

  test('PersonProfile.fromInfo extracts name, photo, position, experience', () {
    final p = PersonProfile.fromInfo({
      'personFIO': 'Конкин Никита Александрович',
      'fileName': 'abc.jpg',
      'actualSalaries': [
        {
          'dictPost': {'postName': 'Доцент'},
          'department': {'fullName': 'Кафедра ИСТ'}
        }
      ],
      'personExperiences': [
        {
          'dictExperienceType': {'experienceTypeName': 'Общий'},
          'year': 5,
          'month': 3
        }
      ],
    }, personId: 9184);
    expect(p.personId, 9184);
    expect(p.fullName, 'Конкин Никита Александрович');
    expect(p.photoName, 'abc.jpg');
    expect(p.salaries.single.postName, 'Доцент');
    expect(p.salaries.single.departmentName, 'Кафедра ИСТ');
    expect(p.experiences.single.typeName, 'Общий');
    expect(p.experiences.single.year, 5);

    // cache round-trip
    final c = PersonProfile.fromCache(p.toJson());
    expect(c.fullName, p.fullName);
    expect(c.salaries.single.postName, 'Доцент');
  });
}
