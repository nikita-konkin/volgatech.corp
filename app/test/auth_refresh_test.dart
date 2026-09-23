import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:volgatech_pro/core/api_client.dart';
import 'package:volgatech_pro/core/session.dart';
import 'package:volgatech_pro/state/auth_controller.dart';

import 'fakes.dart';

/// Routes every request through [handler] instead of the network.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.handler);
  final Future<ResponseBody> Function(RequestOptions o) handler;

  @override
  Future<ResponseBody> fetch(RequestOptions options,
          Stream<Uint8List>? requestStream, Future<void>? cancelFuture) =>
      handler(options);

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(int status, Object body) => ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

void main() {
  late Session session;
  late int refreshCalls;
  late int expirations;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues(
        {'accessToken': 'old', 'refreshToken': 'r1', 'personId': '7'});
    session = Session();
    refreshCalls = 0;
    expirations = 0;
    session.onExpired.listen((_) => expirations++);
  });

  /// Data endpoints accept only the new token; [refresh] answers the refresh.
  ApiClient client(Future<ResponseBody> Function() refresh) =>
      ApiClient(session, adapter: _FakeAdapter((o) async {
        if (o.path == Api.refresh) {
          refreshCalls++;
          return refresh();
        }
        return o.headers['Authorization'] == 'Bearer new'
            ? _json(200, ['ok'])
            : _json(401, {'error': 'invalid_token'});
      }));

  Future<ResponseBody> refreshOk() async =>
      _json(200, {'accessToken': 'new', 'refreshToken': 'r2'});

  test('requests failing together refresh the token once', () async {
    final dio = client(refreshOk).dio;

    final responses = await Future.wait([
      dio.get<dynamic>('/api/a'),
      dio.get<dynamic>('/api/b'),
      dio.get<dynamic>('/api/c'),
    ]);

    expect(responses.map((r) => r.statusCode), [200, 200, 200]);
    expect(refreshCalls, 1);
    expect(await session.accessToken, 'new');
    expect(await session.refreshToken, 'r2');
  });

  test('a refresh that fails on the network keeps the session', () async {
    final dio = client(() async => _json(503, {})).dio;

    final r = await dio.get<dynamic>('/api/a');

    expect(r.statusCode, 401);
    expect(await session.accessToken, 'old');
    expect(await session.refreshToken, 'r1');
    expect(expirations, 0);
  });

  test('a refresh the server rejects ends the session', () async {
    final dio = client(() async => _json(400, {'error': 'invalid_grant'})).dio;

    final r = await dio.get<dynamic>('/api/a');
    await pumpEventQueue();

    expect(r.statusCode, 401);
    expect(await session.accessToken, isNull);
    expect(await session.refreshToken, isNull);
    expect(expirations, 1);
  });

  test('an expired session sends the app back to login, with a notice',
      () async {
    final auth = AuthController(FakeApi(), session, FakeCache());
    await auth.bootstrap();
    expect(auth.status, AuthStatus.authenticated);

    await session.expire();
    await pumpEventQueue();

    expect(auth.status, AuthStatus.unauthenticated);
    expect(auth.personId, isNull);
    expect(auth.consumeSessionExpired(), isTrue);
    expect(auth.consumeSessionExpired(), isFalse, reason: 'shown once');
    auth.dispose();
  });
}
