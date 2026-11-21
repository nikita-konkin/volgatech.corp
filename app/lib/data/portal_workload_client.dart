import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../core/portal_workload.dart';

const _portal = 'https://portal.volgatech.net';
const _profilePath = '/my/person.aspx';
const _profile = '$_portal$_profilePath';
const _loginPath = '/cookieauth.dll';
const _callLimit = Duration(seconds: 3);
const _waitLimit = Duration(seconds: 22);
const _timetableLimit = Duration(seconds: 45);
const _unauthorizedDocument =
    r'/^401\s+unauthorized$/i.test(document.body?.innerText.trim() || "")';

Map<String, dynamic> _fields(Object? data) =>
    Map<String, dynamic>.from(data as Map<Object?, Object?>);

bool _onPortal(Uri uri) =>
    uri.scheme == 'https' &&
    uri.host == 'portal.volgatech.net' &&
    uri.port == 443 &&
    uri.userInfo.isEmpty;

final _authResend = RegExp(r'&AuthResend[0-9a-f]+$', caseSensitive: false);

/// The address without the marker the gateway appends to a page it
/// re-authenticated after a sign-in.
Uri portalAddress(Uri uri) =>
    uri.replace(path: uri.path.replaceFirst(_authResend, ''));

bool isWorkloadPage(Uri uri) {
  if (!_onPortal(uri)) return false;
  final parts = portalAddress(uri)
      .pathSegments
      .map((part) => part.toLowerCase())
      .toList();
  return parts.length == 5 &&
      parts[0] == 'my' &&
      parts[1] == 'personal' &&
      parts[3] == 'sitepages' &&
      parts[4] == 'нагрузка на первую половину дня.aspx';
}

bool _isLogin(Uri uri) =>
    _onPortal(uri) && uri.path.toLowerCase() == _loginPath;

bool _isProfile(Uri uri) =>
    _onPortal(uri) && portalAddress(uri).path.toLowerCase() == _profilePath;

/// The outcome of an attempted portal sign-in.
enum PortalSignInResult { signedIn, rejected, unexpected }

PortalSignInResult portalSignInLanding(Uri? uri) {
  if (uri == null) return PortalSignInResult.unexpected;
  if (_isProfile(uri) || isWorkloadPage(uri)) {
    return PortalSignInResult.signedIn;
  }
  if (_isLogin(uri)) {
    final query = uri.query.replaceFirst(
      RegExp(r'^GetLogon\?', caseSensitive: false),
      '',
    );
    if (Uri.splitQueryString(query)['reason'] == '2') {
      return PortalSignInResult.rejected;
    }
  }
  return PortalSignInResult.unexpected;
}

typedef PortalWorkloadOption = ({String label, String value});

class PortalWorkloadFilter {
  PortalWorkloadFilter(Object? json)
      : selected = _option(_fields(json)['selected']),
        options =
            (_fields(json)['options'] as List<Object?>).map(_option).toList();

  final PortalWorkloadOption selected;
  final List<PortalWorkloadOption> options;

  static PortalWorkloadOption _option(Object? data) {
    final fields = _fields(data);
    return (label: fields['label'] as String, value: fields['value'] as String);
  }
}

class PortalWorkloadReport {
  PortalWorkloadReport(Map<String, dynamic> data)
      : scope = data['scope'] as String,
        filters = _fields(data['filters'])
            .map((key, value) => MapEntry(key, PortalWorkloadFilter(value))),
        cells = (data['cells'] as List<Object?>)
            .map((cell) => PortalWorkloadCell.fromJson(_fields(cell)))
            .toList();

  final String scope;
  final Map<String, PortalWorkloadFilter> filters;
  final List<PortalWorkloadCell> cells;

  Map<String, String> get selection => {
        for (final name in ['department', 'year', 'month'])
          name: filters[name]!.selected.value,
      };

  DateTime? get month => portalWorkloadMonth(filters['month']!.selected.label);
}

/// The filters to open the form on: [month] in its study year, and the
/// remembered [department] while the portal still offers it.
Map<String, String> workloadSelection(
    PortalWorkloadReport report, DateTime month,
    {String? department}) {
  final start = month.month >= 9 ? month.year : month.year - 1;
  String pick(String name, bool Function(PortalWorkloadOption) wanted) {
    final filter = report.filters[name]!;
    return filter.options
        .where(wanted)
        .map((option) => option.value)
        .followedBy([filter.selected.value]).first;
  }

  return {
    'department': pick('department', (option) => option.value == department),
    'year': pick('year', (option) => option.label == '$start/${start + 1}'),
    'month':
        pick('month', (option) => portalWorkloadMonth(option.label) == month),
  };
}

class PortalWorkloadFailure implements Exception {
  const PortalWorkloadFailure(this.message, {this.signIn = false});

  static const signInRequired =
      PortalWorkloadFailure('Войдите на портал', signIn: true);

  final String message;
  final bool signIn;
}

const _changed = PortalWorkloadFailure(
    'Данные на портале изменились. Обновите месяц и проверьте часы.');
const _unavailable =
    PortalWorkloadFailure('Не удалось загрузить форму нагрузки с портала.');
const _timetableUnavailable =
    PortalWorkloadFailure('Не удалось загрузить расписание с портала');

class PortalWorkloadClient {
  PortalWorkloadClient({
    required this.onSignedIn,
    required this.onAuthRequest,
    required this.onLoginFailure,
  }) {
    _ready = _initialize();
  }

  final VoidCallback onSignedIn;
  final void Function(HttpAuthRequest) onAuthRequest;
  final void Function(PortalWorkloadFailure) onLoginFailure;
  final controller = WebViewController();
  late final Future<void> _ready;
  late final Future<String> _script =
      rootBundle.loadString('assets/portal/workload.js');
  late final Future<String> _logonScript =
      rootBundle.loadString('assets/portal/logon.js');
  late final Future<String> _timetableScript =
      rootBundle.loadString('assets/portal/timetable.js');
  Completer<String?>? _navigation;
  void Function(HttpAuthRequest)? _nativeAuth;
  Uri? _workload;
  bool _login = false;
  bool _authRequired = false;
  int _submission = 0;
  int _timetableRead = 0;

  Future<void> _initialize() async {
    await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
    await controller.setNavigationDelegate(NavigationDelegate(
      onNavigationRequest: (request) {
        final uri = Uri.tryParse(request.url);
        return request.isMainFrame && (uri == null || !_onPortal(uri))
            ? NavigationDecision.prevent
            : NavigationDecision.navigate;
      },
      onHttpAuthRequest: (request) {
        if (request.host == Uri.parse(_portal).host) {
          final nativeAuth = _nativeAuth;
          if (nativeAuth != null) {
            nativeAuth(request);
            return;
          }
          if (_login) {
            onAuthRequest(request);
            return;
          }
          _authRequired = true;
        }
        request.onCancel();
      },
      onPageFinished: (url) async {
        if (_nativeAuth != null) return;
        final navigation = _navigation;
        final uri = Uri.tryParse(url);
        if (uri != null && _onPortal(uri)) {
          final denied = await controller
              .runJavaScriptReturningResult(_unauthorizedDocument)
              .timeout(_callLimit, onTimeout: () => false);
          if (denied.toString() == 'true') {
            _authRequired = true;
            if (_login) {
              _login = false;
              onLoginFailure(const PortalWorkloadFailure(
                  'Портал не подтвердил вход. Попробуйте войти ещё раз.',
                  signIn: true));
            }
          }
        }
        if (navigation != null && !navigation.isCompleted) {
          navigation.complete(url);
        }
        if (_login &&
            !_authRequired &&
            portalSignInLanding(uri) == PortalSignInResult.signedIn) {
          _login = false;
          onSignedIn();
        }
      },
      onWebResourceError: (error) {
        if (error.isForMainFrame == true && _login) {
          _login = false;
          onLoginFailure(const PortalWorkloadFailure(
              'Не удалось открыть страницу входа. Попробуйте ещё раз.',
              signIn: true));
        }
        final navigation = _navigation;
        if (error.isForMainFrame == true &&
            navigation != null &&
            !navigation.isCompleted) {
          navigation.complete(null);
        }
      },
    ));
  }

  Future<void> openLogin({bool resume = false}) async {
    await _ready;
    _authRequired = false;
    _login = true;
    if (resume) {
      final current = Uri.tryParse(await controller.currentUrl() ?? '');
      if (!_login) return;
      if (current != null &&
          _onPortal(current) &&
          portalSignInLanding(current) != PortalSignInResult.signedIn) {
        return;
      }
    }
    await controller.loadRequest(Uri.parse(_profile));
  }

  void cancelLogin() => _login = false;

  /// Signs in once with a login in the portal's domain format.
  Future<PortalSignInResult> signIn(String domainLogin, String password) async {
    if (_nativeAuth != null) return PortalSignInResult.unexpected;
    var challenged = false;
    _authRequired = false;
    _nativeAuth = (request) {
      if (!challenged) {
        challenged = true;
        request.onProceed(
            WebViewCredential(user: domainLogin, password: password));
        return;
      }
      _authRequired = true;
      request.onCancel();
    };
    try {
      await _ready;
      final initial = await _settledSignInLanding(
          () => controller.loadRequest(Uri.parse(_profile)));
      if (initial == null || !_isLogin(initial) || challenged) {
        return portalSignInLanding(initial);
      }
      final script = await _logonScript;
      if (_authRequired || challenged) return PortalSignInResult.unexpected;
      final args = [jsonEncode(domainLogin), jsonEncode(password)].join(', ');
      final landing = await _settledSignInLanding(() async {
        final started = await controller.runJavaScriptReturningResult(
            'location.origin === ${jsonEncode(_portal)} && '
            'location.pathname.toLowerCase() === ${jsonEncode(_loginPath)} && '
            '$script($args).started');
        if (started != true) throw _unavailable;
      });
      return portalSignInLanding(landing);
    } on Exception {
      return PortalSignInResult.unexpected;
    } finally {
      _nativeAuth = null;
    }
  }

  Future<Uri?> _settledSignInLanding(Future<void> Function() start) async {
    const budget = Duration(seconds: 22);
    final elapsed = Stopwatch()..start();
    await controller
        .runJavaScript('window.volgatechStale = true')
        .timeout(budget);
    await start().timeout(budget - elapsed.elapsed);
    while (!_authRequired) {
      final result = await controller
          .runJavaScriptReturningResult(
            'window.volgatechStale || document.readyState !== "complete" '
            '? false : $_unauthorizedDocument ? true : location.href',
          )
          .onError<PlatformException>((_, __) => false)
          .timeout(budget - elapsed.elapsed);
      if (result == true || _authRequired) return null;
      if (result is String && result.isNotEmpty) {
        final url =
            result.startsWith('"') ? jsonDecode(result) as String : result;
        final uri = Uri.tryParse(url);
        if (uri?.hasScheme == true && url != 'about:blank') return uri;
      }
      await Future<void>.delayed(const Duration(milliseconds: 250))
          .timeout(budget - elapsed.elapsed);
    }
    return null;
  }

  Future<String?> _awaitNavigation(Future<void> Function() start) async {
    final navigation = _navigation = Completer<String?>();
    try {
      return await start().then((_) => navigation.future).timeout(_waitLimit);
    } finally {
      _navigation = null;
    }
  }

  Future<void> _navigate(Uri uri) async {
    _authRequired = false;
    try {
      final url = await _awaitNavigation(
          () => controller.loadRequest(uri).timeout(_callLimit));
      if (_authRequired) throw PortalWorkloadFailure.signInRequired;
      if (url == null) throw _unavailable;
      final loaded = Uri.parse(url);
      if (_isLogin(loaded)) {
        throw PortalWorkloadFailure.signInRequired;
      }
      if (!_onPortal(loaded)) throw _unavailable;
    } on TimeoutException {
      throw _unavailable;
    }
  }

  Future<Map<String, dynamic>> _run(String action,
      [Map<String, Object>? request]) async {
    final timetable =
        action == 'timetableStart' || action == 'timetableReceipt';
    final script =
        await (timetable ? _timetableScript : _script).timeout(_callLimit);
    final url = await controller.currentUrl().timeout(_callLimit);
    final uri = url == null ? null : Uri.tryParse(url);
    if (uri != null && _isLogin(uri)) {
      throw PortalWorkloadFailure.signInRequired;
    }
    if (uri == null ||
        (action == 'link' ? !_isProfile(uri) : !isWorkloadPage(uri))) {
      return {'error': 'loading'};
    }
    final args = [jsonEncode(action), jsonEncode(request)].join(', ');
    final invocation = timetable ? '$script.run($args)' : '$script($args)';
    final result = await controller
        .runJavaScriptReturningResult(invocation)
        .timeout(_callLimit);
    final data = jsonDecode(result as String);
    return _fields(data is String ? jsonDecode(data) : data);
  }

  Future<Map<String, dynamic>> _read(String action) =>
      _wait(action, (_) => true);

  Future<List<Object?>> readTimetable() async {
    await _ready.timeout(_callLimit);
    final id = ++_timetableRead;
    final start = await _start('timetableStart', {'id': id});
    if (start != null && start['started'] != true) throw _timetableUnavailable;
    final result = await _wait(
        'timetableReceipt',
        (receipt) =>
            id != _timetableRead ||
            (receipt['id'] == id && receipt['state'] != 'pending'),
        limit: _timetableLimit);
    if (id != _timetableRead) throw _timetableUnavailable;
    if (result case {'state': 'ready', 'rows': final List<Object?> rows}) {
      return rows;
    }
    throw _timetableUnavailable;
  }

  Future<Map<String, dynamic>?> _start(String action,
      [Map<String, Object>? request]) async {
    try {
      return await _run(action, request);
    } on TimeoutException {
      return null;
    }
  }

  Future<Map<String, dynamic>> _wait(
      String action, bool Function(Map<String, dynamic>) accept,
      {Duration limit = _waitLimit}) {
    var expired = false;
    return _poll(action, accept, () => expired).timeout(limit, onTimeout: () {
      expired = true;
      throw _unavailable;
    });
  }

  Future<Map<String, dynamic>> _poll(
      String action,
      bool Function(Map<String, dynamic>) accept,
      bool Function() expired) async {
    while (!expired()) {
      try {
        final result = await _run(action);
        if (accept(result)) return result;
      } on Exception catch (error) {
        if (error is! PlatformException &&
            error is! FormatException &&
            error is! TimeoutException) {
          rethrow;
        }
      }
      if (!expired()) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
    }
    throw _unavailable;
  }

  Future<PortalWorkloadReport> load({
    Map<String, String> selection = const {},
    bool fresh = false,
  }) async {
    await _ready.timeout(_callLimit, onTimeout: () => throw _unavailable);
    final currentUrl = await controller
        .currentUrl()
        .timeout(_callLimit, onTimeout: () => throw _unavailable);
    final current = Uri.tryParse(currentUrl ?? '');
    final onWorkload = current != null && isWorkloadPage(current);
    if (_workload == null) {
      if (onWorkload) {
        _workload = portalAddress(current);
      } else {
        if (current == null || !_isProfile(current)) {
          await _navigate(Uri.parse(_profile));
        }
        final link = (await _read('link'))['url'] as String?;
        final url = link == null ? null : Uri.tryParse(link);
        if (url == null || !isWorkloadPage(url)) throw _unavailable;
        _workload = url;
        await _navigate(url);
      }
    } else if (!onWorkload) {
      await _navigate(_workload!);
    }
    final filters = ['department', 'year', 'month'];
    Map<String, dynamic>? initial;
    if (fresh && onWorkload) {
      final displayed = await _run('info')
          .onError<PlatformException>((_, __) => {})
          .onError<FormatException>((_, __) => {})
          .onError<TimeoutException>((_, __) => {});
      if (_readyInfo(displayed) &&
          filters.any((name) {
            final value = selection[name];
            return value != null && _selected(displayed, name) != value;
          })) {
        initial = displayed;
      } else {
        await _navigate(_workload!);
      }
    }
    var info = initial ?? await _wait('info', _readyInfo);
    for (final name in filters) {
      final value = selection[name];
      if (value == null || _selected(info, name) == value) continue;
      final started = await _start('select', {'filter': name, 'value': value});
      if (started != null && started['started'] != true) throw _changed;
      final revision = info['revision'];
      info = await _wait(
          'info',
          (result) =>
              result['revision'] != null &&
              result['revision'] != revision &&
              _selected(result, name) == value);
    }
    if (info['mode'] != 'edit') {
      final started = await _start('edit');
      if (started != null && started['started'] != true) throw _unavailable;
      final revision = info['revision'];
      await _wait(
          'info',
          (result) =>
              result['mode'] == 'edit' && result['revision'] != revision);
    }
    final report = await _read('inspect');
    if (report['error'] != null) throw _unavailable;
    return PortalWorkloadReport(report);
  }

  bool _readyInfo(Map<String, dynamic> info) {
    final mode = info['mode'];
    return mode == 'view' || mode == 'edit';
  }

  String _selected(Map<String, dynamic> info, String name) =>
      PortalWorkloadFilter(_fields(info['filters'])[name]).selected.value;

  Future<PortalWorkloadReport> submit(
    PortalWorkloadReport before,
    Map<String, int> changes, {
    required void Function(int completedStages) onProgress,
  }) async {
    final fresh = await load(selection: before.selection, fresh: true);
    final previous = {for (final cell in before.cells) cell.key: cell.amount};
    final current = {for (final cell in fresh.cells) cell.key: cell.amount};
    if (fresh.scope != before.scope ||
        changes.keys.any((key) =>
            !previous.containsKey(key) || previous[key] != current[key])) {
      throw _changed;
    }
    onProgress(1);
    final id = ++_submission;
    final result = await _start('submit', {
      'scope': fresh.scope,
      'id': id,
      'changes': {
        for (final entry in changes.entries)
          entry.key: {'before': current[entry.key], 'after': entry.value},
      },
    });
    if (result?['error'] == 'value') {
      throw const PortalWorkloadFailure(
          'Портал отклонил одно из значений. Проверьте часы.');
    }
    if (result != null && result['started'] != true) throw _changed;
    onProgress(2);
    try {
      await _wait('receipt',
          (result) => result['id'] == id && result['state'] != 'pending');
      onProgress(3);
      final report = await load(selection: before.selection, fresh: true);
      onProgress(4);
      return report;
    } on Exception {
      throw const PortalWorkloadFailure(
          'Не удалось проверить сохранение. Обновите месяц перед повторной отправкой.');
    }
  }
}
