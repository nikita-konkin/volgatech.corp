import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../models/auth.dart';
import 'session.dart';

/// Base URLs from the reverse-engineered contract.
class Api {
  static const prod = 'https://api.volgatech.net';
  static const test = 'https://test-api.volgatech.net';

  // Endpoints (see reverse_engineering/API_CONTRACT.md).
  static const login = '/api/Auth/GetToken';
  static const refresh = '/api/Auth/RefreshToken';
  static const profiles = '/api/Person/GetProfiles';
  static const personInfo = '/api/Person/GetInfo';
  static const calendar = '/api/Calendar/GetPersonCalendar';
  static const studyYears = '/api/Exams/GetPersonStudyYears';
  static const exams = '/api/Exams/GetPersonExams';
  static const photo = '/api/files/GetPersonPhotoByName';
}

/// Builds the shared Dio instance with the auth interceptor.
class ApiClient {
  ApiClient(
    this.session, {
    String baseUrl = Api.prod,
    @visibleForTesting HttpClientAdapter? adapter,
  }) : dio = Dio(BaseOptions(
          baseUrl: baseUrl,
          // Short connect timeout: screens show their cached copy while
          // loading, so a dead network should fail fast rather than hang.
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 60),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'text/plain',
          },
          // Accept any status so we can inspect bodies in interceptors.
          validateStatus: (s) => s != null && s < 500,
        )) {
    // Separate Dio (no auth interceptor) used for refresh + retry to avoid loops.
    _bare = Dio(dio.options);
    if (adapter != null) {
      dio.httpClientAdapter = adapter;
      _bare.httpClientAdapter = adapter;
    }
    dio.interceptors.add(_AuthInterceptor(session, _bare));
  }

  final Session session;
  final Dio dio;
  late final Dio _bare;
}

enum _Refresh {
  /// New tokens saved.
  ok,

  /// The server refused the refresh token — the session is over.
  rejected,

  /// Network error, timeout or 5xx — worth trying again later; keep the session.
  failed,
}

class _AuthInterceptor extends QueuedInterceptor {
  _AuthInterceptor(this._session, this._bare);
  final Session _session;
  final Dio _bare;

  bool _isAuthPath(String path) => path.contains('/api/Auth/');

  @override
  Future<void> onRequest(
      RequestOptions options, RequestInterceptorHandler handler) async {
    if (!_isAuthPath(options.path)) {
      final t = await _session.accessToken;
      if (t != null && t.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $t';
      }
    }
    handler.next(options);
  }

  @override
  Future<void> onResponse(
      Response<dynamic> response, ResponseInterceptorHandler handler) async {
    // Some backends signal an expired token as a non-2xx with body
    // {"Error":"invalid_token"} (see original univuz.service errorh).
    final needsRefresh = (response.statusCode == 401) ||
        _bodyHasInvalidToken(response.data);
    if (needsRefresh && _canRecover(response.requestOptions)) {
      final replayed = await _recover(response.requestOptions);
      if (replayed != null) return handler.resolve(replayed);
    }
    handler.next(response);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401 && _canRecover(err.requestOptions)) {
      final replayed = await _recover(err.requestOptions);
      if (replayed != null) return handler.resolve(replayed);
    }
    handler.next(err);
  }

  bool _canRecover(RequestOptions req) =>
      !_isAuthPath(req.path) && req.extra['retried'] != true;

  bool _bodyHasInvalidToken(dynamic data) {
    // Cheap substring test first so normal responses (a whole week of
    // schedule) are not JSON-decoded twice.
    if (data is String && !data.contains('invalid_token')) return false;
    try {
      final map = data is String ? jsonDecode(data) : data;
      if (map is Map) {
        final v = (map['Error'] ?? map['error'] ?? '').toString().toLowerCase();
        return v.contains('invalid_token');
      }
    } catch (_) {}
    return false;
  }

  /// Refreshes the token and replays [req]; null when it can't be recovered.
  ///
  /// Responses are queued, so when several requests fail together (profile +
  /// schedule at startup) the first one refreshes and the rest see a token
  /// newer than the one they were sent with — those are just replayed.
  Future<Response<dynamic>?> _recover(RequestOptions req) async {
    final current = await _session.accessToken;
    final sentWith = req.headers['Authorization'];
    final refreshedMeanwhile = current != null &&
        current.isNotEmpty &&
        sentWith != 'Bearer $current';
    if (!refreshedMeanwhile) {
      switch (await _refresh()) {
        case _Refresh.ok:
          break;
        case _Refresh.rejected:
          await _session.expire();
          return null;
        case _Refresh.failed:
          return null;
      }
    }
    try {
      return await _retry(req);
    } catch (_) {
      return null;
    }
  }

  Future<Response<dynamic>> _retry(RequestOptions req) async {
    req.extra['retried'] = true;
    final t = await _session.accessToken;
    if (t != null) req.headers['Authorization'] = 'Bearer $t';
    return _bare.fetch<dynamic>(req);
  }

  Future<_Refresh> _refresh() async {
    final rt = await _session.refreshToken;
    final at = await _session.accessToken;
    if (rt == null || at == null) return _Refresh.rejected;
    final Response<dynamic> r;
    try {
      r = await _bare.post<dynamic>(
        Api.refresh,
        data: jsonEncode({'refreshToken': rt}),
        options: Options(headers: {'Authorization': 'Bearer $at'}),
      );
    } catch (_) {
      return _Refresh.failed; // offline, timeout or 5xx
    }
    if (r.statusCode != 200) return _Refresh.rejected;
    final AuthTokens tokens;
    try {
      final data = r.data is String ? jsonDecode(r.data as String) : r.data;
      tokens = AuthTokens.fromJson(Map<String, dynamic>.from(data as Map));
    } catch (_) {
      return _Refresh.failed; // not JSON — e.g. a captive portal page
    }
    if (!tokens.isValid) return _Refresh.rejected;
    await _session.saveTokens(tokens);
    return _Refresh.ok;
  }
}
