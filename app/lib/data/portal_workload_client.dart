import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../core/portal_workload.dart';

const _portal = 'https://portal.volgatech.net';
const _profilePath = '/my/person.aspx';
const _profile = '$_portal$_profilePath';
const _loginPath = '/cookieauth.dll';

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
  if (_isLogin(uri)) return PortalSignInResult.rejected;
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
  final String message;
  final bool signIn;
}

const _signIn = PortalWorkloadFailure('Войдите на портал', signIn: true);
const _changed = PortalWorkloadFailure(
    'Данные на портале изменились. Обновите месяц и проверьте часы.');
const _unavailable =
    PortalWorkloadFailure('Не удалось загрузить форму нагрузки с портала.');

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
  Completer<String?>? _navigation;
  void Function(HttpAuthRequest)? _nativeAuth;
  Uri? _workload;
  bool _login = false;
  bool _authRequired = false;
  int _submission = 0;

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
        final navigation = _navigation;
        final uri = Uri.tryParse(url);
        if (uri != null && _onPortal(uri)) {
          // The gateway can return a plain 401 at either the login or profile URL.
          final denied = await controller.runJavaScriptReturningResult(
              r'/^401\s+unauthorized$/i.test(document.body?.innerText.trim() || "")');
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
      final navigation = _navigation;
      if (navigation != null && !navigation.isCompleted) {
        navigation.complete(null);
      }
    };
    try {
      await _ready;
      final initialUrl = await _awaitNavigation(
          () => controller.loadRequest(Uri.parse(_profile)));
      if (_authRequired) return PortalSignInResult.rejected;
      final initial = portalSignInLanding(Uri.tryParse(initialUrl ?? ''));
      if (initial != PortalSignInResult.rejected || challenged) return initial;
      final script = await _logonScript;
      if (_authRequired || challenged) return PortalSignInResult.rejected;
      final args = [jsonEncode(domainLogin), jsonEncode(password)].join(', ');
      final landing = await _awaitNavigation(() async {
        final started = await controller.runJavaScriptReturningResult(
            'location.origin === ${jsonEncode(_portal)} && '
            'location.pathname.toLowerCase() === ${jsonEncode(_loginPath)} && '
            '$script($args).started');
        if (started != true) throw _unavailable;
      });
      if (_authRequired) return PortalSignInResult.rejected;
      return portalSignInLanding(Uri.tryParse(landing ?? ''));
    } on Exception {
      return _authRequired
          ? PortalSignInResult.rejected
          : PortalSignInResult.unexpected;
    } finally {
      _nativeAuth = null;
    }
  }

  Future<String?> _awaitNavigation(Future<void> Function() start) async {
    final navigation = _navigation = Completer<String?>();
    try {
      return await start()
          .then((_) => navigation.future)
          .timeout(const Duration(seconds: 22));
    } finally {
      _navigation = null;
    }
  }

  Future<void> _navigate(Uri uri) async {
    _authRequired = false;
    try {
      final url = await _awaitNavigation(() => controller.loadRequest(uri));
      if (_authRequired) throw _signIn;
      if (url == null) throw _unavailable;
      final loaded = Uri.parse(url);
      if (_isLogin(loaded)) {
        throw _signIn;
      }
      if (!_onPortal(loaded)) throw _unavailable;
    } on TimeoutException {
      throw _unavailable;
    }
  }

  Future<Map<String, dynamic>> _run(String action,
      [Map<String, Object>? request]) async {
    final script = await _script;
    final url = await controller.currentUrl();
    final uri = url == null ? null : Uri.tryParse(url);
    if (uri != null && _isLogin(uri)) {
      throw _signIn;
    }
    if (uri == null ||
        (action == 'link' ? !_isProfile(uri) : !isWorkloadPage(uri))) {
      return {'error': 'loading'};
    }
    final args = [jsonEncode(action), jsonEncode(request)].join(', ');
    final result =
        await controller.runJavaScriptReturningResult('$script($args)');
    final data = jsonDecode(result as String);
    return _fields(data is String ? jsonDecode(data) : data);
  }

  Future<Map<String, dynamic>> _wait(
      String action, bool Function(Map<String, dynamic>) accept) async {
    final elapsed = Stopwatch()..start();
    while (elapsed.elapsed < const Duration(seconds: 22)) {
      try {
        final result = await _run(action);
        if (accept(result)) return result;
      } on PlatformException {
        // A postback can replace the document before the script returns.
      } on FormatException {
        // A WebView in the middle of navigation can return an empty result.
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    throw _unavailable;
  }

  Future<PortalWorkloadReport> load({
    Map<String, String> selection = const {},
    bool fresh = false,
  }) async {
    await _ready;
    final current = Uri.tryParse(await controller.currentUrl() ?? '');
    if (_workload == null) {
      if (current == null || !isWorkloadPage(current)) {
        if (current == null || !_isProfile(current)) {
          await _navigate(Uri.parse(_profile));
        }
        final link = (await _run('link'))['url'] as String?;
        final url = link == null ? null : Uri.tryParse(link);
        if (url == null || !isWorkloadPage(url)) throw _unavailable;
        _workload = url;
        await _navigate(url);
      } else {
        _workload = portalAddress(current);
      }
    } else if (fresh || current == null || !isWorkloadPage(current)) {
      await _navigate(_workload!);
    }

    var info = await _wait('info', (result) {
      final mode = result['mode'];
      return mode == 'view' || mode == 'edit';
    });
    for (final name in ['department', 'year', 'month']) {
      final value = selection[name];
      if (value == null || _selected(info, name) == value) continue;
      final started = await _run('select', {'filter': name, 'value': value});
      if (started['started'] != true) throw _changed;
      final revision = info['revision'];
      info = await _wait(
          'info',
          (result) =>
              result['revision'] != null &&
              result['revision'] != revision &&
              _selected(result, name) == value);
    }
    if (info['mode'] != 'edit') {
      final started = await _run('edit');
      if (started['started'] != true) throw _unavailable;
      final revision = info['revision'];
      await _wait(
          'info',
          (result) =>
              result['mode'] == 'edit' && result['revision'] != revision);
    }
    final report = await _run('inspect');
    if (report['error'] != null) throw _unavailable;
    return PortalWorkloadReport(report);
  }

  String _selected(Map<String, dynamic> info, String name) =>
      PortalWorkloadFilter(_fields(info['filters'])[name]).selected.value;

  Future<PortalWorkloadReport> submit(
      PortalWorkloadReport before, Map<String, int> changes) async {
    final fresh = await load(selection: before.selection, fresh: true);
    final previous = {for (final cell in before.cells) cell.key: cell.amount};
    final current = {for (final cell in fresh.cells) cell.key: cell.amount};
    if (fresh.scope != before.scope ||
        changes.keys.any((key) =>
            !previous.containsKey(key) || previous[key] != current[key])) {
      throw _changed;
    }
    final id = ++_submission;
    final result = await _run('submit', {
      'scope': fresh.scope,
      'id': id,
      'changes': {
        for (final entry in changes.entries)
          entry.key: {'before': current[entry.key], 'after': entry.value},
      },
    });
    if (result['error'] == 'value') {
      throw const PortalWorkloadFailure(
          'Портал отклонил одно из значений. Проверьте часы.');
    }
    if (result['started'] != true) throw _changed;
    try {
      await _wait('receipt',
          (result) => result['id'] == id && result['state'] != 'pending');
      return await load(selection: before.selection, fresh: true);
    } on Exception {
      throw const PortalWorkloadFailure(
          'Не удалось проверить сохранение. Обновите месяц перед повторной отправкой.');
    }
  }
}
