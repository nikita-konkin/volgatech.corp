import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:volgatech_pro/core/cache.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({'theme': 'dark'}));

  test('in a browser, JSON and bytes round-trip through local storage',
      () async {
    final cache = JsonCache(inBrowser: true);
    expect(await cache.get('schedule_7_2026-09-28'), isNull);

    await cache.put('schedule_7_2026-09-28', {
      'days': [1, 2]
    });
    final entry = await cache.get('schedule_7_2026-09-28');
    expect(entry!.data, {
      'days': [1, 2]
    });
    expect(DateTime.now().difference(entry.savedAt).inMinutes, 0);

    final photo = Uint8List.fromList(List.generate(1000, (i) => i % 256));
    await cache.putBytes('photo_7', photo);
    expect(await cache.getBytes('photo_7'), photo);
  });

  test('a photo too big for local storage is not kept', () async {
    final cache = JsonCache(inBrowser: true);
    await cache.putBytes('photo_7', Uint8List(300 * 1024));
    expect(await cache.getBytes('photo_7'), isNull);
  });

  test('removing a prefix or clearing leaves the app’s settings alone',
      () async {
    final cache = JsonCache(inBrowser: true);
    await cache.put('schedule_7_a', 1);
    await cache.put('schedule_7_b', 2);
    await cache.put('exams_7', 3);
    await cache.putBytes('photo_7', Uint8List(4));

    await cache.removePrefix('schedule_7');
    expect(await cache.get('schedule_7_a'), isNull);
    expect(await cache.get('schedule_7_b'), isNull);
    expect((await cache.get('exams_7'))!.data, 3);

    await cache.clear();
    expect(await cache.get('exams_7'), isNull);
    expect(await cache.getBytes('photo_7'), isNull);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('theme'), 'dark');
  });
}
