import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:volgatech_pro/data/volgatech_api.dart';
import 'package:volgatech_pro/models/schedule.dart';
import 'package:volgatech_pro/state/schedule_controller.dart';

import 'fakes.dart';

void main() {
  const personId = 7;
  final monA = DateTime(2026, 9, 21); // week 1
  final wedA = DateTime(2026, 9, 23);
  final sunA = DateTime(2026, 9, 27);
  final monB = DateTime(2026, 9, 28); // week 2
  final sunB = DateTime(2026, 10, 4);
  const keyA = 'schedule_7_2026-09-21';

  late FakeApi api;
  late FakeCache cache;
  late ScheduleController c;

  setUp(() {
    api = FakeApi();
    cache = FakeCache();
    c = ScheduleController(api, personId, cache);
  });

  List<String?> subjects(DateTime d) =>
      [for (final e in c.eventsOn(d)) e.description];

  test('shows the saved week at once, then replaces it with the fresh one',
      () async {
    cache.seed(
        keyA,
        [
          day(wedA, [lesson('10:00', subject: 'Старое')]).toJson()
        ],
        DateTime(2026, 9, 20));
    final network = Completer<List<ScheduleDay>>();
    api.onSchedule = (m) => m == monA ? network.future : Future.value([]);

    final loading = c.goToDay(wedA);
    await pumpEventQueue();
    expect(subjects(wedA), ['Старое']);
    expect(c.loading, isTrue);
    expect(c.fromCache, isFalse, reason: 'still loading, not offline');

    network.complete([
      day(wedA, [lesson('10:00', subject: 'Новое')])
    ]);
    await loading;
    expect(subjects(wedA), ['Новое']);
    expect(c.loading, isFalse);
    expect(c.fromCache, isFalse);
    expect(jsonEncode(cache.json[keyA]!.data), contains('Новое'),
        reason: 'the fresh week is saved for next time');
  });

  test('a network failure falls back to the saved week and flags it offline',
      () async {
    final savedAt = DateTime(2026, 9, 20, 18, 30);
    cache.seed(
        keyA,
        [
          day(wedA, [lesson('10:00')]).toJson()
        ],
        savedAt);
    api.onSchedule = (_) async => throw const ApiException('Нет соединения');

    await c.goToDay(wedA);
    expect(subjects(wedA), ['Физика']);
    expect(c.fromCache, isTrue);
    expect(c.cacheSavedAt, savedAt);
    expect(c.error, isNull);
  });

  test('a failure with nothing saved surfaces the error', () async {
    api.onSchedule = (_) async => throw const ApiException('Нет соединения');

    await c.goToDay(wedA);
    expect(c.error, 'Нет соединения');
    expect(c.loading, isFalse);
    expect(c.eventsForSelected, isEmpty);
  });

  test('prefetches one week ahead and never refetches a loaded week', () async {
    await c.goToDay(wedA);
    await pumpEventQueue(); // let the background fetch of week B finish
    expect(api.scheduleCalls, [monA, monB]);

    await c.goToDay(monB);
    await c.goToDay(sunA);
    await c.goToDay(sunB);
    expect(api.scheduleCalls, [monA, monB],
        reason: 'both weeks are loaded; the prefetch does not chain on');
  });

  test('concurrent refreshes of one week share a single request', () async {
    final network = Completer<List<ScheduleDay>>();
    api.onSchedule = (m) => m == monA ? network.future : Future.value([]);
    c.selectedDay = wedA;

    final a = c.refresh();
    final b = c.refresh();
    network.complete([]);
    await Future.wait([a, b]);
    expect(api.scheduleCalls.where((m) => m == monA), hasLength(1));
  });

  test('a slow response for one week does not overwrite another', () async {
    final weekA = Completer<List<ScheduleDay>>();
    final weekB = Completer<List<ScheduleDay>>();
    api.onSchedule = (m) => m == monA ? weekA.future : weekB.future;

    unawaited(c.goToDay(wedA));
    final toB = c.goToDay(sunB); // swiped on before week A answered
    await pumpEventQueue();

    weekB.complete([
      day(monB, [lesson('08:00', week: 2)])
    ]);
    await toB;
    expect(c.loading, isFalse, reason: 'week B is done; A is not shown');
    // Sunday has no lessons: the accent comes from week B's Monday.
    expect(c.weekNumberForSelected, 2);

    weekA.complete([
      day(wedA, [lesson('08:00', week: 1)])
    ]);
    await pumpEventQueue();
    expect(c.weekNumberForSelected, 2);
    expect(c.loading, isFalse);
    expect(subjects(wedA), ['Физика'], reason: 'week A is still kept');
  });

  test('a newer response drops lessons that are gone and sorts by time',
      () async {
    cache.seed(
        keyA,
        [
          day(wedA, [lesson('10:00', subject: 'Отменена')]).toJson(),
        ],
        DateTime(2026, 9, 20));
    api.onSchedule = (m) async => m == monA
        ? [
            day(monA, [
              lesson('12:00', subject: 'Вторая'),
              lesson('08:00', subject: 'Первая'),
            ]),
          ]
        : [];

    await c.goToDay(wedA);
    expect(subjects(wedA), isEmpty);
    expect(subjects(monA), ['Первая', 'Вторая']);
  });
}
