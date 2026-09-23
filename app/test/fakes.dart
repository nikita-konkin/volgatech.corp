import 'dart:convert';
import 'dart:typed_data';

import 'package:volgatech_pro/core/cache.dart';
import 'package:volgatech_pro/data/volgatech_api.dart';
import 'package:volgatech_pro/models/profile.dart';
import 'package:volgatech_pro/models/schedule.dart';

/// In-memory [JsonCache]; JSON goes through encode/decode like the disk copy.
class FakeCache implements JsonCache {
  final Map<String, CachedEntry> json = {};
  final Map<String, Uint8List> bytes = {};

  void seed(String key, Object data, DateTime savedAt) =>
      json[key] = CachedEntry(savedAt, jsonDecode(jsonEncode(data)));

  @override
  Future<void> put(String key, Object data) async =>
      seed(key, data, DateTime.now());

  @override
  Future<CachedEntry?> get(String key) async => json[key];

  @override
  Future<void> putBytes(String key, Uint8List data) async => bytes[key] = data;

  @override
  Future<Uint8List?> getBytes(String key) async => bytes[key];

  @override
  Future<void> clear() async {
    json.clear();
    bytes.clear();
  }
}

/// [VolgatechApi] with scriptable schedule / photo responses.
class FakeApi implements VolgatechApi {
  /// Monday of every schedule request, in order.
  final List<DateTime> scheduleCalls = [];
  Future<List<ScheduleDay>> Function(DateTime monday) onSchedule =
      (_) async => const [];

  int photoCalls = 0;
  Future<Uint8List> Function(String name) onPhoto =
      (_) async => throw const ApiException('offline');

  @override
  Future<List<ScheduleDay>> getSchedule(
      int personId, DateTime start, DateTime end) {
    scheduleCalls.add(start);
    return onSchedule(start);
  }

  @override
  Future<Uint8List> getPhotoBytes(String photoName) {
    photoCalls++;
    return onPhoto(photoName);
  }

  @override
  Future<PersonProfile> getPersonInfo(int personId) async =>
      throw const ApiException('offline');

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

ScheduleEvent lesson(String begin, {String subject = 'Физика', int? week}) =>
    ScheduleEvent(
      timeBegin: begin,
      timeEnd: begin,
      description: subject,
      room: '101',
      weekNumber: week,
    );

ScheduleDay day(DateTime date, List<ScheduleEvent> events) =>
    ScheduleDay(date: date, events: events);
