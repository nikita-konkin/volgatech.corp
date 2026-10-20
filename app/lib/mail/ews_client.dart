import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:xml/xml.dart';

import 'mail_config.dart';
import 'mail_credentials.dart';
import 'mail_models.dart';
import 'ntlm.dart';

const ewsTypes = 'http://schemas.microsoft.com/exchange/services/2006/types';
const ewsMessages =
    'http://schemas.microsoft.com/exchange/services/2006/messages';

/// A signed-in session with Exchange Web Services — the interface Outlook
/// uses; IMAP is switched off for Volgatech mailboxes and SMTP is filtered.
///
/// NTLM authenticates the TCP connection rather than each request, so the
/// session keeps one connection and repeats the handshake only when the
/// server asks again (new connection, idle timeout).
///
/// Requests go one at a time, so one stuck on a dead connection would hold
/// up every later one for good: the server's silence ([timeout]) drops the
/// connection, and the next request starts on a new one.
class EwsSession {
  EwsSession(this.credentials,
      {Uri? endpoint, this.retryRefused = true, this.timeout = defaultTimeout})
      : _endpoint = endpoint ?? Uri.parse(kEwsUrl);

  final MailCredentials credentials;
  final Uri _endpoint;

  /// A refused sign-in is tried once more on a new connection: NTLM signs
  /// in the connection, not the request, so one dropped or swapped halfway
  /// is refused though the password is right. Not for a password just
  /// typed: each refusal counts towards the domain account's lockout.
  final bool retryRefused;

  /// How long the server may keep silent, before answering or halfway
  /// through an answer, before the connection counts as dead.
  final Duration timeout;
  static const defaultTimeout = Duration(seconds: 30);

  HttpClient _http = _client();
  bool _authenticated = false;

  /// When the server last answered in full.
  DateTime? _heardAt;

  static const _idle = Duration(seconds: 50);
  static HttpClient _client() => HttpClient()
    ..maxConnectionsPerHost = 1
    ..connectionTimeout = const Duration(seconds: 15)
    ..idleTimeout = _idle;

  /// A new connection, to be signed in afresh; the old one goes, with
  /// anything still stuck on it.
  void _renew() {
    _http.close(force: true);
    _http = _client();
    _authenticated = false;
  }

  Future<void> _queue = Future.value();

  /// Posts a SOAP [body]; returns the response document or throws
  /// [MailAuthException], [MailNetworkException] or [EwsException].
  Future<XmlDocument> call(String body, {String version = ewsVersion}) {
    // One request at a time: they share the authenticated connection.
    final result = _queue
        .then((_) => _call(utf8.encode(soapEnvelope(body, version: version))));
    _queue = result.then((_) {}, onError: (_) {});
    return result;
  }

  Future<XmlDocument> _call(List<int> bytes) async {
    // Quiet for longer than a connection is kept: the app was most likely
    // frozen in the background, the idle timer with it, and the network
    // may have dropped the connection without a word.
    if (_heardAt case final at? when DateTime.now().difference(at) > _idle) {
      _renew();
    }
    try {
      HttpClientResponse res;
      try {
        res = await _send(bytes);
      } on MailAuthException {
        if (!retryRefused) rethrow;
        _renew();
        res = await _handshake(bytes);
      }
      final text = await utf8.decodeStream(res.timeout(timeout));
      _heardAt = DateTime.now();
      if (res.statusCode != HttpStatus.ok) {
        throw EwsException(ewsError(text) ?? 'HTTP ${res.statusCode}');
      }
      final error = ewsError(text);
      if (error != null) throw EwsException(error);
      return XmlDocument.parse(text);
    } on MailAuthException {
      _renew();
      rethrow;
    } on SocketException catch (e) {
      _renew();
      throw MailNetworkException(e);
    } on HandshakeException catch (e) {
      _renew();
      throw MailNetworkException(e);
    } on TimeoutException catch (e) {
      _renew();
      throw MailNetworkException(e);
    } on HttpException catch (e) {
      _renew();
      throw MailNetworkException(e);
    }
  }

  Future<HttpClientResponse> _send(List<int> bytes) async {
    if (!_authenticated) return _handshake(bytes);
    final res = await _post(null, bytes);
    if (res.statusCode != HttpStatus.unauthorized) return res;
    await res.timeout(timeout).drain<void>();
    return _handshake(bytes);
  }

  /// NEGOTIATE on an empty request, then AUTHENTICATE carrying [bytes].
  Future<HttpClientResponse> _handshake(List<int> bytes) async {
    _authenticated = false;
    final first = await _post('NTLM ${ntlmNegotiate()}', const []);
    // Frees the connection for the second leg.
    await first.timeout(timeout).drain<void>();
    final header = first.headers[HttpHeaders.wwwAuthenticateHeader]
        ?.map((h) => h.trim())
        .where((h) => h.startsWith('NTLM '))
        .firstOrNull;
    if (first.statusCode != HttpStatus.unauthorized || header == null) {
      throw EwsException('нет NTLM (HTTP ${first.statusCode})');
    }
    final challenge = NtlmChallenge.parse(header.substring(5));
    final id = ntlmIdentity(credentials.login);
    // A bare account name gets the server's domain.
    final domain = id.domain.isNotEmpty || id.user.contains('@')
        ? id.domain
        : challenge.targetName;
    final res = await _post(
        'NTLM ${ntlmAuthenticate(
          challenge: challenge,
          user: id.user,
          domain: domain,
          password: credentials.password,
        )}',
        bytes);
    if (res.statusCode == HttpStatus.unauthorized) {
      throw MailAuthException(await refusalDetails(res, timeout: timeout));
    }
    _authenticated = true;
    return res;
  }

  Future<HttpClientResponse> _post(
      String? authorization, List<int> body) async {
    final req = await _http.postUrl(_endpoint).timeout(timeout);
    req.persistentConnection = true;
    req.headers.set(HttpHeaders.contentTypeHeader, 'text/xml; charset=utf-8');
    if (authorization != null) {
      req.headers.set(HttpHeaders.authorizationHeader, authorization);
    }
    req.headers.contentLength = body.length;
    req.add(body);
    // Room to upload a big message too, at 50 KB/s.
    return req
        .close()
        .timeout(timeout + Duration(milliseconds: body.length ~/ 50));
  }

  void close() => _http.close(force: true);
}

/// What a refused sign-in [res] says beyond its status, for «Отчёты об
/// ошибках»: Exchange's diagnostics header, or the error page's title.
Future<String> refusalDetails(HttpClientResponse res,
    {Duration timeout = EwsSession.defaultTimeout}) async {
  final diagnostics = res.headers.value('x-ms-diagnostics');
  String page;
  try {
    page = await res
        .timeout(timeout)
        .transform(const Utf8Decoder(allowMalformed: true))
        .join();
  } on Object {
    page = '';
  }
  final title = RegExp(r'<title>([^<]*)</title>', caseSensitive: false)
      .firstMatch(page)?[1]
      ?.trim();
  final said = [
    'HTTP ${res.statusCode}',
    if (diagnostics != null && diagnostics.isNotEmpty) diagnostics,
    if (title != null && title.isNotEmpty) title,
  ].join(' · ');
  return said.length > 300 ? said.substring(0, 300) : said;
}

/// The schema every request is written against, unless it needs a newer one.
const ewsVersion = 'Exchange2013';

String soapEnvelope(String body, {String version = ewsVersion}) =>
    '<?xml version="1.0" encoding="utf-8"?>'
    '<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" '
    'xmlns:t="$ewsTypes" xmlns:m="$ewsMessages">'
    '<soap:Header><t:RequestServerVersion Version="$version"/></soap:Header>'
    '<soap:Body>$body</soap:Body></soap:Envelope>';

/// Escapes text for XML content and attribute values.
String xmlText(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

final _errorClass = RegExp(r'ResponseClass="Error"');
final _messageText = RegExp(r'<(?:\w+:)?MessageText>([^<]*)<');
final _faultString = RegExp(r'<faultstring[^>]*>([^<]*)<');

/// The server's complaint in an EWS response, or null when it succeeded.
String? ewsError(String response) {
  final fault = _faultString.firstMatch(response);
  if (fault != null) return fault[1];
  // A batch where something succeeded is fine (e.g. no Junk folder).
  if (!_errorClass.hasMatch(response) ||
      response.contains('ResponseClass="Success"')) {
    return null;
  }
  return _messageText.firstMatch(response)?[1] ?? 'ошибка Exchange';
}

class EwsException implements Exception {
  const EwsException(this.detail);
  final String detail;
  @override
  String toString() => 'Ошибка почтового сервера: $detail';
}
