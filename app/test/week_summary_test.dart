import 'package:flutter_test/flutter_test.dart';
import 'package:volgatech_pro/core/week_summary.dart';
import 'package:volgatech_pro/models/schedule.dart';

ScheduleEvent _e(String begin, String end) =>
    ScheduleEvent(timeBegin: begin, timeEnd: end);

void main() {
  group('russianPairs pluralises correctly', () {
    test('1, 21 → пара', () {
      expect(russianPairs(1), '1 пара');
      expect(russianPairs(21), '21 пара');
    });
    test('2,3,4,22 → пары', () {
      expect(russianPairs(2), '2 пары');
      expect(russianPairs(3), '3 пары');
      expect(russianPairs(4), '4 пары');
      expect(russianPairs(22), '22 пары');
    });
    test('0,5,11..14 → пар', () {
      expect(russianPairs(0), '0 пар');
      expect(russianPairs(5), '5 пар');
      expect(russianPairs(11), '11 пар');
      expect(russianPairs(12), '12 пар');
      expect(russianPairs(14), '14 пар');
    });
  });

  group('minutesOfDay / humanDuration / hhmm', () {
    test('parses HH:MM[:SS]', () {
      expect(minutesOfDay('08:00:00'), 8 * 60);
      expect(minutesOfDay('09:35'), 9 * 60 + 35);
      expect(minutesOfDay(null), isNull);
      expect(minutesOfDay('bad'), isNull);
    });
    test('humanDuration formats', () {
      expect(humanDuration(45), '45 мин');
      expect(humanDuration(120), '2 ч');
      expect(humanDuration(90), '1 ч 30 мин');
    });
    test('hhmm zero-pads', () {
      expect(hhmm(8 * 60 + 5), '08:05');
      expect(hhmm(15 * 60), '15:00');
    });
  });

  group('DayStats.from aggregates a sorted day', () {
    test('empty day', () {
      const s = DayStats(count: 0);
      expect(DayStats.from(const []).isEmpty, isTrue);
      expect(s.span, '');
    });

    test('span + gap between two lessons', () {
      // 08:00–09:35, then 11:20–12:55 → 105-minute gap («окно»).
      final s = DayStats.from([
        _e('08:00:00', '09:35:00'),
        _e('11:20:00', '12:55:00'),
      ]);
      expect(s.count, 2);
      expect(s.firstBegin, 8 * 60);
      expect(s.lastEnd, 12 * 60 + 55);
      expect(s.span, '08:00–12:55');
      expect(s.gapMinutes, (11 * 60 + 20) - (9 * 60 + 35)); // 105
      expect(humanDuration(s.gapMinutes), '1 ч 45 мин');
    });

    test('back-to-back lessons have no gap', () {
      final s = DayStats.from([
        _e('08:00:00', '09:35:00'),
        _e('09:35:00', '11:10:00'),
      ]);
      expect(s.gapMinutes, 0);
      expect(s.span, '08:00–11:10');
    });
  });
}
