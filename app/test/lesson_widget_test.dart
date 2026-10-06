import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:volgatech_pro/core/lesson_widget.dart';
import 'package:volgatech_pro/models/schedule.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => initializeDateFormatting('ru_RU'));

  final tue = DateTime(2026, 10, 6);
  final thu = DateTime(2026, 10, 8);
  // 10:00 in Yoshkar-Ola on Tuesday: the 09:45 lesson is on.
  final now = DateTime.utc(2026, 10, 6, 7);

  ScheduleEvent at(String begin, String end, String subject) => ScheduleEvent(
        timeBegin: begin,
        timeEnd: end,
        description: subject,
        room: '305',
        building: 'I',
        typeWorkName: 'Лекции',
      );

  test('the lessons not over yet, with what the widget shows of them', () {
    final data = widgetData({
      tue: [
        at('08:00', '09:35', 'Прошедшее'),
        at('09:45', '11:20', 'Сети'),
      ],
      DateTime(2026, 10, 7): const [],
      thu: [at('11:40', '13:15', 'Физика')],
      DateTime(2026, 10, 11): const [],
    }, now: now);
    final lessons = data['lessons']! as List;
    expect(lessons, hasLength(2));
    expect(lessons.first, {
      'start': DateTime.utc(2026, 10, 6, 6, 45).millisecondsSinceEpoch,
      'end': DateTime.utc(2026, 10, 6, 8, 20).millisecondsSinceEpoch,
      'day': '2026-10-06',
      'dayLabel': 'Вт, 6 октября',
      'from': '09:45',
      'to': '11:20',
      'title': 'Сети (лекция)',
      'room': 'ауд. 305 (I)',
    });
    expect((lessons.last as Map)['dayLabel'], 'Чт, 8 октября');
    // The loaded days end with Sunday the 11th: midnight after it, Moscow.
    expect(
        data['until'], DateTime.utc(2026, 10, 11, 21).millisecondsSinceEpoch);
  });

  test('nothing loaded: no lessons and no end', () {
    expect(widgetData({}, now: now), {'lessons': <Object>[]});
  });

  test('sends the weeks it is given, and nothing after sign-out', () async {
    const channel = MethodChannel('test/lesson_widget');
    final sent = <Map<String, dynamic>>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'update');
      sent.add(jsonDecode(call.arguments as String) as Map<String, dynamic>);
      return null;
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));

    final widget = LessonWidget(channel: channel, clock: () => now);
    widget.addWeek({
      tue: [at('09:45', '11:20', 'Сети')]
    });
    widget.addWeek({
      thu: [at('11:40', '13:15', 'Физика')]
    });
    await widget.flush();
    expect([for (final l in sent.last['lessons'] as List) (l as Map)['title']],
        ['Сети (лекция)', 'Физика (лекция)']);

    await widget.forget();
    expect(sent.last, {'lessons': <Object>[]});
  });
}
