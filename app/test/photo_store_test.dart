import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:volgatech_pro/core/photo_store.dart';
import 'package:volgatech_pro/data/volgatech_api.dart';

import 'fakes.dart';

void main() {
  late FakeApi api;
  late FakeCache cache;
  late PhotoStore store;
  final jpeg = Uint8List.fromList([0xFF, 0xD8, 0xFF]);

  setUp(() {
    api = FakeApi();
    cache = FakeCache();
    store = PhotoStore(api, cache);
  });

  test('a saved photo is used without touching the network', () async {
    cache.bytes['photo_a.jpg'] = jpeg;

    expect(await store.load('a.jpg'), jpeg);
    expect(api.photoCalls, 0);
  });

  test('a downloaded photo is saved and shared by later lookups', () async {
    api.onPhoto = (_) async => jpeg;

    final both = await Future.wait([store.load('a.jpg'), store.load('a.jpg')]);
    expect(both, [jpeg, jpeg]);
    expect(await store.load('a.jpg'), jpeg);
    expect(api.photoCalls, 1);
    expect(cache.bytes['photo_a.jpg'], jpeg);
  });

  test('a failed download is retried next time', () async {
    api.onPhoto = (_) async => throw const ApiException('offline');
    expect(await store.load('a.jpg'), isNull);

    api.onPhoto = (_) async => jpeg;
    expect(await store.load('a.jpg'), jpeg);
    expect(api.photoCalls, 2);
  });
}
