import 'dart:convert';
import 'package:dio/dio.dart';
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
  ApiClient(this.session, {String baseUrl = Api.prod})
      : dio = Dio(BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 40),
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
    dio.interceptors.add(_AuthInterceptor(session, _bare));
  }

  final Session session;
  final Dio dio;
  late final Dio _bare;
}

class _AuthInterceptor extends QueuedInterceptor {
  _AuthInterceptor(this._session, this._bare);
  final Session _session;
  final Dio _bare;

  bool _isAuthPath(String path) => path.contains('/api/Auth/');

  @override
  void onRequest(
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
  void onResponse(
      Response response, ResponseInterceptorHandler handler) async {
    // Some backends signal an expired token as a non-2xx with body
    // {"Error":"invalid_token"} (see original univuz.service errorh).
    final needsRefresh = (response.statusCode == 401) ||
        _bodyHasInvalidToken(response.data);
    final req = response.requestOptions;
    if (needsRefresh && !_isAuthPath(req.path) && req.extra['retried'] != true) {
      final ok = await _refresh();
      if (ok) {
        try {
          return handler.resolve(await _retry(req));
        } catch (_) {/* fall through */}
      } else {
        await _session.clear();
      }
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final req = err.requestOptions;
    if ((err.response?.statusCode == 401) &&
        !_isAuthPath(req.path) &&
        req.extra['retried'] != true) {
      final ok = await _refresh();
      if (ok) {
        try {
          return handler.resolve(await _retry(req));
        } catch (_) {/* fall through */}
      } else {
        await _session.clear();
      }
    }
    handler.next(err);
  }

  bool _bodyHasInvalidToken(dynamic data) {
    try {
      final map = data is String ? jsonDecode(data) : data;
      if (map is Map) {
        final v = (map['Error'] ?? map['error'] ?? '').toString().toLowerCase();
        return v.contains('invalid_token');
      }
    } catch (_) {}
    return false;
  }

  Future<Response<dynamic>> _retry(RequestOptions req) async {
    req.extra['retried'] = true;
    final t = await _session.accessToken;
    if (t != null) req.headers['Authorization'] = 'Bearer $t';
    return _bare.fetch(req);
  }

  Future<bool> _refresh() async {
    final rt = await _session.refreshToken;
    final at = await _session.accessToken;
    if (rt == null || at == null) return false;
    try {
      final r = await _bare.post(
        Api.refresh,
        data: jsonEncode({'refreshToken': rt}),
        options: Options(headers: {'Authorization': 'Bearer $at'}),
      );
      final data = r.data is String ? jsonDecode(r.data) : r.data;
      final tokens = AuthTokens.fromJson(Map<String, dynamic>.from(data));
      if (!tokens.isValid) return false;
      await _session.saveTokens(tokens);
      return true;
    } catch (_) {
      return false;
    }
  }
}
