import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:volgatech_pro/core/lesson_reminders.dart';
import 'package:volgatech_pro/core/prefs.dart';
import 'package:volgatech_pro/models/schedule.dart';
import 'package:volgatech_pro/state/schedule_controller.dart';

import 'fakes.dart';

void main() {
  final mon = DateTime(2026, 10, 5);
  final tue = DateTime(2026, 10, 6);
  // 07:30 in Yoshkar-Ola on Tuesday.
  final morning = DateTime.utc(2026, 10, 6, 4, 30);

  ScheduleEvent at(String begin, String end, String subject,
          {String? group, String type = 'Лекции'}) =>
      ScheduleEvent(
        timeBegin: begin,
        timeEnd: end,
        description: subject,
        room: '305',
        typeWorkName: type,
        fullDescription: group,
      );

  group('plannedReminders', () {
    test('ahead of each later lesson, in UTC, with time and room', () {
      final list = plannedReminders({
        mon: [at('08:00', '09:35', 'Вчерашнее')],
        tue: [
          at('11:40', '13:15', 'Физика', type: 'Практические'),
          at('08:00', '09:35', 'Сети'),
          // Too close: its reminder time has gone.
          at('07:40', '07:55', 'Ранняя'),
        ],
      }, lead: const Duration(minutes: 15), now: morning);
      expect([
        for (final r in list) r.at
      ], [
        DateTime.utc(2026, 10, 6, 4, 45),
        DateTime.utc(2026, 10, 6, 8, 25),
      ]);
      expect(list.first.title, 'Через 15 мин: Сети (лекция)');
      expect(list.first.body, '08:00–09:35 · ауд. 305');
      expect(list.last.title, 'Через 15 мин: Физика (практика)');
      expect([for (final r in list) r.id], [10000, 10001]);
    });

    test('a lesson shared by groups once; none past the horizon or limit', () {
      final days = {
        tue: [
          at('09:45', '11:20', 'Сети', group: 'ИСТ-41'),
          at('09:45', '11:20', 'Сети', group: 'ИСТ-42'),
        ],
        DateTime(2026, 10, 30): [at('09:45', '11:20', 'Далёкое')],
      };
      final list = plannedReminders(days,
          lead: const Duration(minutes: 10), now: morning);
      expect([for (final r in list) r.title], ['Через 10 мин: Сети (лекция)']);
      expect(
          plannedReminders({
            for (var i = 0; i < 5; i++)
              DateTime(2026, 10, 7 + i): [at('09:45', '11:20', 'Сети')],
          }, lead: const Duration(minutes: 10), now: morning, limit: 3),
          hasLength(3));
    });
  });

  group('LessonReminders', () {
    late Prefs prefs;
    late FakeReminders platform;
    late LessonReminders reminders;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await Prefs.load();
      platform = FakeReminders();
      reminders = LessonReminders(prefs, platform, clock: () => morning);
    });

    test('off at first; on plans the weeks seen so far; off clears them',
        () async {
      reminders.addWeek({
        tue: [at('09:45', '11:20', 'Сети')]
      });
      await reminders.flush();
      expect(reminders.minutes, 0);
      expect(platform.planned, isEmpty);

      expect(await reminders.setMinutes(15), isTrue);
      expect(prefs.lessonReminderMinutes, 15);
      expect([for (final r in platform.planned) r.title],
          ['Через 15 мин: Сети (лекция)']);

      // A fresh copy of the week replaces what was there.
      reminders.addWeek({tue: const []});
      await reminders.flush();
      expect(platform.planned, isEmpty);

      reminders.addWeek({
        tue: [at('13:35', '15:10', 'Базы данных')]
      });
      await reminders.flush();
      expect(platform.planned, hasLength(1));
      await reminders.setMinutes(0);
      expect(platform.planned, isEmpty);
    });

    test('stays off when notifications are refused', () async {
      platform.allow = false;
      expect(await reminders.setMinutes(10), isFalse);
      expect(reminders.minutes, 0);
      expect(platform.replaced, 0);
    });

    test('the schedule tells it each week as it loads', () async {
      final api = FakeApi()
        ..onSchedule = (m) async => m == mon
            ? [
                ScheduleDay(date: tue, events: [at('09:45', '11:20', 'Сети')])
              ]
            : [];
      await reminders.setMinutes(10);
      final c =
          ScheduleController(api, 7, FakeCache(), onWeek: reminders.addWeek);
      await c.goToDay(tue);
      await reminders.flush();
      expect([for (final r in platform.planned) r.title],
          ['Через 10 мин: Сети (лекция)']);
      c.dispose();
    });
  });
}
