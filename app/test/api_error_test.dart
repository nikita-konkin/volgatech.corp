import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:volgatech_pro/data/volgatech_api.dart';

void main() {
  test('Dio timeout maps to a Russian message', () {
    final e = ApiException.fromDio(
      DioException(
        requestOptions: RequestOptions(path: '/x'),
        type: DioExceptionType.connectionTimeout,
      ),
      fallback: 'fallback',
    );
    expect(e.message, contains('Превышено время'));
  });

  test('Connection error maps to a Russian message', () {
    final e = ApiException.fromDio(
      DioException(
        requestOptions: RequestOptions(path: '/x'),
        type: DioExceptionType.connectionError,
      ),
      fallback: 'fallback',
    );
    expect(e.message, contains('Нет соединения'));
  });

  test('Known backend auth message is localized', () {
    final r = Response(
      requestOptions: RequestOptions(path: '/api/Auth/GetToken'),
      statusCode: 400,
      data: {'Message': 'Invalid login or password.'},
    );
    final e = ApiException.fromResponse(r, fallback: 'Ошибка входа');
    expect(e.message, 'Введённые логин или пароль неверны.');
  });
}
