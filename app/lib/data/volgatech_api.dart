import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import '../core/api_client.dart';
import '../models/auth.dart';
import '../models/exams.dart';
import '../models/profile.dart';
import '../models/schedule.dart';

final _ymd = DateFormat('yyyy-MM-dd');

/// Typed wrapper over the Volgatech REST API (see API_CONTRACT.md).
class VolgatechApi {
  VolgatechApi(this._client);
  final ApiClient _client;
  Dio get _dio => _client.dio;

  static dynamic _decode(dynamic data) =>
      data is String && data.isNotEmpty ? jsonDecode(data) : data;

  // Run a request, translating Dio network errors into a Russian ApiException.
  Future<Response<dynamic>> _run(Future<Response<dynamic>> Function() call,
      String fallback) async {
    try {
      return await call();
    } on DioException catch (e) {
      throw ApiException.fromDio(e, fallback: fallback);
    }
  }

  /// POST /api/Auth/GetToken  {login, password} -> {accessToken, refreshToken}
  Future<AuthTokens> getToken(String login, String password) async {
    final r = await _run(
        () => _dio.post(Api.login,
            data: jsonEncode({'login': login, 'password': password})),
        'Ошибка входа');
    if (r.statusCode == 200) {
      return AuthTokens.fromJson(Map<String, dynamic>.from(_decode(r.data) as Map));
    }
    throw ApiException.fromResponse(r, fallback: 'Ошибка входа');
  }

  /// GET /api/Person/GetProfiles -> [ { personId, ... } ]  (identifies the user)
  Future<PersonProfile> getProfile() async {
    final r = await _run(() => _dio.get(Api.profiles), 'Не удалось получить профиль');
    if (r.statusCode == 200) {
      final data = _decode(r.data);
      final list = data is List ? data : [data];
      if (list.isEmpty) throw const ApiException('Профиль не найден');
      return PersonProfile.fromProfiles(Map<String, dynamic>.from(list.first as Map));
    }
    throw ApiException.fromResponse(r, fallback: 'Не удалось получить профиль');
  }

  /// GET /api/Person/GetInfo/{id} -> { personFIO, fileName, actualSalaries[], personExperiences[] }
  Future<PersonProfile> getPersonInfo(int personId) async {
    final r = await _run(() => _dio.get('${Api.personInfo}/$personId'),
        'Не удалось получить профиль');
    if (r.statusCode == 200) {
      final data = _decode(r.data);
      final map = data is List ? (data.isNotEmpty ? data.first : <String, dynamic>{}) : data;
      return PersonProfile.fromInfo(Map<String, dynamic>.from(map as Map),
          personId: personId);
    }
    throw ApiException.fromResponse(r, fallback: 'Не удалось получить профиль');
  }

  /// GET /api/Calendar/GetPersonCalendar/{id}/{start}/{end}/TimeTable,Event,Private
  Future<List<ScheduleDay>> getSchedule(
      int personId, DateTime start, DateTime end) async {
    final path =
        '${Api.calendar}/$personId/${_ymd.format(start)}/${_ymd.format(end)}/TimeTable,Event,Private';
    final r = await _run(() => _dio.get(path), 'Не удалось загрузить расписание');
    if (r.statusCode == 200) {
      final data = _decode(r.data);
      final list = data is List ? data : const <dynamic>[];
      return list
          .map((e) => ScheduleDay.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }
    throw ApiException.fromResponse(r, fallback: 'Не удалось загрузить расписание');
  }

  /// GET /api/Exams/GetPersonStudyYears//{id}
  /// NOTE: the double slash is intentional — it matches the backend route the
  /// original app used (verified in capture). A single slash may 404.
  Future<List<StudyYear>> getStudyYears(int personId) async {
    final r = await _run(() => _dio.get('${Api.studyYears}//$personId'),
        'Не удалось загрузить учебные годы');
    if (r.statusCode == 200) {
      final data = _decode(r.data);
      final list = data is List ? data : const <dynamic>[];
      return list
          .map((e) => StudyYear.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }
    throw ApiException.fromResponse(r, fallback: 'Не удалось загрузить учебные годы');
  }

  /// GET /api/Exams/GetPersonExams/{id}/{year}
  Future<List<Exam>> getExams(int personId, int year) async {
    final r = await _run(() => _dio.get('${Api.exams}/$personId/$year'),
        'Не удалось загрузить экзамены');
    if (r.statusCode == 200) {
      final data = _decode(r.data);
      final list = data is List ? data : const <dynamic>[];
      return list
          .map((e) => Exam.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }
    throw ApiException.fromResponse(r, fallback: 'Не удалось загрузить экзамены');
  }

  /// GET /api/files/GetPersonPhotoByName/{name} -> image bytes.
  Future<Uint8List> getPhotoBytes(String photoName) async {
    final r = await _run(
        () => _dio.get<List<int>>('${Api.photo}/$photoName',
            options: Options(responseType: ResponseType.bytes)),
        'Не удалось загрузить фото');
    final data = r.data;
    if (r.statusCode == 200 && data is List<int> && data.isNotEmpty) {
      return data is Uint8List ? data : Uint8List.fromList(data);
    }
    throw const ApiException('Не удалось загрузить фото');
  }
}

class ApiException implements Exception {
  final String message;
  const ApiException(this.message);

  factory ApiException.fromResponse(Response<dynamic> r, {required String fallback}) {
    try {
      final data = r.data is String && (r.data as String).isNotEmpty
          ? jsonDecode(r.data as String)
          : r.data;
      if (data is Map) {
        final m = data['Message'] ?? data['message'] ?? data['error_description'];
        if (m is String && m.isNotEmpty) return ApiException(_ru(m));
      }
    } catch (_) {}
    return ApiException(fallback);
  }

  factory ApiException.fromDio(DioException e, {required String fallback}) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const ApiException(
            'Превышено время ожидания. Проверьте подключение к сети.');
      case DioExceptionType.connectionError:
        return const ApiException('Нет соединения с сервером.');
      case DioExceptionType.badCertificate:
        return const ApiException('Ошибка сертификата сервера.');
      case DioExceptionType.badResponse:
        if (e.response != null) {
          return ApiException.fromResponse(e.response!, fallback: fallback);
        }
        return ApiException(fallback);
      case DioExceptionType.cancel:
        return const ApiException('Запрос отменён.');
      case DioExceptionType.unknown:
        return const ApiException('Нет соединения с сервером.');
      default:
        return const ApiException('Нет соединения с сервером.');
    }
  }

  // Map known backend auth messages to Russian (matches original app UX).
  static String _ru(String m) {
    switch (m) {
      case 'Invalid login or password.':
        return 'Введённые логин или пароль неверны.';
      case 'Not enough data. Provide login and password.':
        return 'Необходимо указать логин и пароль.';
      default:
        return m;
    }
  }

  @override
  String toString() => message;
}
