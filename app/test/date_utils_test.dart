import 'package:flutter_test/flutter_test.dart';
import 'package:volgatech_pro/core/date_utils.dart';

void main() {
  group(
      'apiWallClock / apiCalendarDate (TZ-independent — guards day-shift bug)',
      () {
    test('keeps the calendar day regardless of the +03:00 offset', () {
      final d = apiCalendarDate('2026-09-21T00:00:00+03:00');
      expect(d.year, 2026);
      expect(d.month, 9);
      expect(d.day, 21); // must NOT roll back to the 20th
      expect(d.weekday, DateTime.monday); // 21 Sep 2026 is a Monday
    });

    test('keeps the wall-clock time (exam at 09:00 MSK stays 09:00)', () {
      final d = apiWallClock('2026-12-24T09:00:00+03:00');
      expect(d.day, 24);
      expect(d.hour, 9);
      expect(d.minute, 0);
    });

    test('handles a cached value with no offset', () {
      final d = apiWallClock('2026-09-21T00:00:00.000');
      expect(d.day, 21);
      expect(d.hour, 0);
    });

    test('handles a date-only string', () {
      final d = apiCalendarDate('2026-01-05');
      expect(d.month, 1);
      expect(d.day, 5);
    });
  });
}
