import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:volgatech_pro/data/portal_workload_client.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

/// The WebView platform for the gateway redirect sequence.
final class _GatewayPlatform extends WebViewPlatform {
  _GatewayPlatform(this.login, this.username);

  final Uri login;
  final String username;

  @override
  PlatformWebViewController createPlatformWebViewController(
    PlatformWebViewControllerCreationParams params,
  ) =>
      _GatewayController(params, login, username);

  @override
  PlatformNavigationDelegate createPlatformNavigationDelegate(
    PlatformNavigationDelegateCreationParams params,
  ) =>
      _GatewayDelegate(params);
}

/// The WebView whose cancelled redirects finish on the document still shown.
final class _GatewayController extends PlatformWebViewController {
  _GatewayController(super.params, this.login, this.username)
      : _url = login,
        super.implementation();

  final Uri login;
  final String username;
  late final Uri _profile;
  late final _GatewayDelegate _delegate;
  Uri _url;
  bool _loginReplayed = false;
  bool _stale = false;

  @override
  Future<void> setJavaScriptMode(JavaScriptMode mode) async {}

  @override
  Future<void> setPlatformNavigationDelegate(
    covariant _GatewayDelegate delegate,
  ) async {
    _delegate = delegate;
  }

  @override
  Future<void> loadRequest(LoadRequestParams params) async {
    _profile = params.uri;
    await _redirect(login, () {
      _loginReplayed = true;
      _document(login);
    });
  }

  Future<void> _redirect(Uri uri, void Function() replay) async {
    final decision = await _delegate.request(
      NavigationRequest(url: uri.toString(), isMainFrame: true),
    );
    if (decision != NavigationDecision.navigate) return;
    _delegate.finished(_url.toString());
    unawaited(Future<void>.delayed(const Duration(milliseconds: 173), replay));
  }

  void _document(Uri uri) {
    _url = uri;
    _stale = false;
    _delegate.finished(_url.toString());
  }

  @override
  Future<void> runJavaScript(String script) async {
    _stale = script.contains('window.volgatechStale = true');
  }

  @override
  Future<Object> runJavaScriptReturningResult(String script) async {
    if (script.contains('window.volgatechStale')) {
      return _stale ? false : jsonEncode(_url.toString());
    }
    if (!script.contains('#SubmitCreds')) return false;
    if (_loginReplayed) {
      await _redirect(_profile, () {
        _delegate.authenticate(HttpAuthRequest(
          host: _profile.host,
          onProceed: (credential) {
            if (credential.user == username && credential.password.isNotEmpty) {
              _document(_profile);
            }
          },
          onCancel: () {},
        ));
      });
    }
    return true;
  }
}

/// The navigation callbacks captured by the fake gateway WebView.
final class _GatewayDelegate extends PlatformNavigationDelegate {
  _GatewayDelegate(super.params) : super.implementation();

  late NavigationRequestCallback request;
  late PageEventCallback finished;
  late HttpAuthRequestCallback authenticate;

  @override
  Future<void> setOnNavigationRequest(
    NavigationRequestCallback callback,
  ) async {
    request = callback;
  }

  @override
  Future<void> setOnPageFinished(PageEventCallback callback) async {
    finished = callback;
  }

  @override
  Future<void> setOnHttpAuthRequest(HttpAuthRequestCallback callback) async {
    authenticate = callback;
  }

  @override
  Future<void> setOnWebResourceError(WebResourceErrorCallback callback) async {}
}

/// A workload WebView platform with an in-memory server and document.
final class _WorkloadPlatform extends WebViewPlatform {
  _WorkloadPlatform(this.months, this.amount);

  final List<String> months;
  final int amount;
  late final _WorkloadController view;

  @override
  PlatformWebViewController createPlatformWebViewController(
    PlatformWebViewControllerCreationParams params,
  ) =>
      view = _WorkloadController(params, months, amount);

  @override
  PlatformNavigationDelegate createPlatformNavigationDelegate(
    PlatformNavigationDelegateCreationParams params,
  ) =>
      _GatewayDelegate(params);
}

/// The displayed workload grid and its server-backed navigations.
final class _WorkloadController extends PlatformWebViewController {
  _WorkloadController(super.params, this.months, this.serverAmount)
      : _month = months.first,
        _amount = serverAmount,
        super.implementation();

  final List<String> months;
  final _url = _page('Нагрузка на первую половину дня.aspx');
  late final _GatewayDelegate _delegate;
  String _month;
  int _amount;
  int serverAmount;
  int gets = 0;
  int verificationGets = 0;
  int _revision = 0;
  bool _editing = true;
  bool _receiptRead = false;
  Object? _submission;

  @override
  Future<void> setJavaScriptMode(JavaScriptMode mode) async {}

  @override
  Future<void> setPlatformNavigationDelegate(
    covariant _GatewayDelegate delegate,
  ) async {
    _delegate = delegate;
  }

  @override
  Future<String> currentUrl() async => _url;

  @override
  Future<void> loadRequest(LoadRequestParams params) async {
    gets++;
    if (_receiptRead) verificationGets++;
    _document(editing: false);
  }

  void _document({required bool editing}) {
    _editing = editing;
    _amount = serverAmount;
    _revision++;
    _submission = null;
    _delegate.finished(_url);
  }

  Map<String, Object> _filter(String selected, List<String> options) => {
        'selected': {'label': selected, 'value': selected},
        'options': [
          for (final value in options) {'label': value, 'value': value},
        ],
      };

  @override
  Future<Object> runJavaScriptReturningResult(String script) async {
    final call = RegExp(r'\("(\w+)", (.*)\)$').firstMatch(script);
    if (call == null) return false;
    final request = jsonDecode(call[2]!) as Map<String, dynamic>?;
    switch (call[1]) {
      case 'info':
        return jsonEncode({
          'mode': _editing ? 'edit' : 'view',
          'revision': _revision,
          'filters': _filters,
        });
      case 'select':
        final value = request!['value'] as String;
        if (request['filter'] != 'month' || !months.contains(value)) {
          return jsonEncode({'error': 'changed'});
        }
        _month = value;
        _document(editing: false);
        return jsonEncode({'started': true});
      case 'edit':
        _document(editing: true);
        return jsonEncode({'started': true});
      case 'inspect':
        return jsonEncode({
          'scope': _month,
          'filters': _filters,
          'cells': [
            {
              'key': '$_month/lecture',
              'rowKey': _month,
              'column': 'HoursAuditLec',
              'discipline': 'Гидрология',
              'specialty': 'Природообустройство',
              'appointment': 'Основная',
              'semester': 'Осенний',
              'amount': _amount,
            },
          ],
        });
      case 'submit':
        final changes = request!['changes'] as Map<String, Object?>;
        final cell = changes['$_month/lecture'] as Map<String, Object?>;
        _amount = serverAmount = cell['after'] as int;
        _submission = request['id'];
        return jsonEncode({'started': true});
      case 'receipt':
        _receiptRead = true;
        return jsonEncode({'id': _submission, 'state': 'received'});
      default:
        throw StateError('Unexpected workload action ${call[1]}');
    }
  }

  Map<String, Object> get _filters => {
        'department': _filter('7183', ['7183']),
        'year': _filter('2028', ['2028']),
        'month': _filter(_month, months),
      };
}

Future<T> _withWorkload<T>(
  _WorkloadPlatform platform,
  Future<T> Function(PortalWorkloadClient) operation,
) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final previous = WebViewPlatform.instance;
  try {
    WebViewPlatform.instance = platform;
    return await operation(PortalWorkloadClient(
      onSignedIn: () {},
      onAuthRequest: (request) => request.onCancel(),
      onLoginFailure: (_) {},
    ));
  } finally {
    if (previous != null) WebViewPlatform.instance = previous;
  }
}

String _marker(Random random) =>
    '&AuthResend${List.generate(32, (_) => random.nextInt(16).toRadixString(16).toUpperCase()).join()}';

String _page(String name) =>
    'https://portal.volgatech.net/my/personal/u${Random().nextInt(9999)}/SitePages/'
    '${Uri.encodeComponent(name)}';

PortalWorkloadReport _report({
  String department = '1726',
  List<(String, String)> departments = const [
    ('ЕСиОД', '2095'),
    ('ИТРС', '1726'),
  ],
  List<(String, String)> years = const [
    ('2026/2027', '2026'),
    ('2025/2026', '2025'),
  ],
  List<(String, String)> months = const [
    ('Сентябрь 2026', '1'),
    ('Октябрь 2026', '2'),
    ('Ноябрь 2026', '3'),
  ],
}) {
  Map<String, Object> filter(List<(String, String)> options, String value) => {
        'selected': {
          'label': options.firstWhere((o) => o.$2 == value).$1,
          'value': value,
        },
        'options': [
          for (final (label, value) in options) {'label': label, 'value': value}
        ],
      };
  return PortalWorkloadReport({
    'scope': 'scope',
    'filters': {
      'person': filter(const [('Преподаватель', '1')], '1'),
      'department': filter(departments, department),
      'year': filter(years, years.first.$2),
      'month': filter(months, months.first.$2),
    },
    'cells': <Object>[],
  });
}

void main() {
  test('A fresh load of another month uses the selection postback', () async {
    final random = Random();
    final month = '${random.nextInt(5) + 8}';
    final platform =
        _WorkloadPlatform(['${random.nextInt(7) + 1}', month], 173);
    final result = await _withWorkload(platform, (client) async {
      final before = await client.load();
      final report = await client.load(
        selection: {...before.selection, 'month': month},
        fresh: true,
      );
      return (report.selection['month'], platform.view.gets);
    });
    expect(result, (month, 0),
        reason: 'the requested month was not loaded without a full GET');
  });

  test('A fresh load of the displayed month makes a full GET', () async {
    final platform = _WorkloadPlatform(['${Random().nextInt(12) + 1}'], 391);
    final gets = await _withWorkload(platform, (client) async {
      final before = await client.load();
      await client.load(selection: before.selection, fresh: true);
      return platform.view.gets;
    });
    expect(gets, 1, reason: 'refreshing the displayed month did not GET once');
  });

  test('Verifying a save makes a full GET after the receipt', () async {
    final random = Random();
    final platform = _WorkloadPlatform(['${random.nextInt(12) + 1}'], 217);
    final gets = await _withWorkload(platform, (client) async {
      final before = await client.load();
      await client.submit(
        before,
        {before.cells.single.key: random.nextInt(317) + 439},
        onProgress: (_) {},
      );
      return platform.view.verificationGets;
    });
    expect(gets, 1, reason: 'verification did not GET once after the receipt');
  });

  test('A cell changed on the server prevents the save', () async {
    final random = Random();
    final platform = _WorkloadPlatform(
        ['${random.nextInt(12) + 1}'], random.nextInt(139) + 21);
    final failure = await _withWorkload(platform, (client) async {
      final before = await client.load();
      platform.view.serverAmount = random.nextInt(249) + 251;
      try {
        await client.submit(
          before,
          {before.cells.single.key: random.nextInt(413) + 527},
          onProgress: (_) {},
        );
      } on PortalWorkloadFailure catch (error) {
        return error.message;
      }
      return null;
    });
    expect(
      failure,
      'Данные на портале изменились. Обновите месяц и проверьте часы.',
      reason: 'the concurrent cell change did not stop the save',
    );
  });

  test('Native sign-in survives both replayed gateway redirects', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final random = Random();
    final username = 'MARSTU\\v.lei-${random.nextInt(76301)}';
    final login = Uri.parse('https://portal.volgatech.net/'
        'CookieAuth.dll?GetLogon?curl=Z2FmyZ2Fperson.aspx&reason=0&formdir=${random.nextInt(57) + 11}');
    final platform = WebViewPlatform.instance;
    await rootBundle.loadString('assets/portal/logon.js');
    final PortalSignInResult result;
    try {
      WebViewPlatform.instance = _GatewayPlatform(login, username);
      final client = PortalWorkloadClient(
        onSignedIn: () {},
        onAuthRequest: (request) => request.onCancel(),
        onLoginFailure: (_) {},
      );
      result = await client.signIn(username, 'X?m-${random.nextInt(83617)}');
    } finally {
      if (platform != null) WebViewPlatform.instance = platform;
    }
    expect(
      result,
      PortalSignInResult.signedIn,
      reason: 'the replayed gateway redirects prevented a valid sign-in',
    );
  });

  test('A profile with the gateway marker means the sign-in succeeded', () {
    final page = Uri.parse(
        'https://portal.volgatech.net/my/person.aspx${_marker(Random())}');
    expect(
      portalSignInLanding(page),
      PortalSignInResult.signedIn,
      reason: 'the marked profile was not recognised as a successful sign-in',
    );
  });

  test('A workload page means the sign-in succeeded', () {
    final page = Uri.parse(_page('Нагрузка на первую половину дня.aspx'));
    expect(
      portalSignInLanding(page),
      PortalSignInResult.signedIn,
      reason: 'the workload page was not recognised as a successful sign-in',
    );
  });

  test('Only gateway reason 2 means the credentials were rejected', () {
    final random = Random();
    final otherReason = random.nextInt(887) + 5;
    final landings = [
      for (final reason in [0, 2, 3, 4, otherReason, null])
        portalSignInLanding(Uri.parse('https://portal.volgatech.net/'
            'CookieAuth.dll?GetLogon?curl=Z2FmyZ2Fperson.aspx'
            '${reason == null ? '' : '&reason=$reason'}'
            '&formdir=${random.nextInt(63) + 11}')),
    ];
    expect(
      landings,
      [
        PortalSignInResult.unexpected,
        PortalSignInResult.rejected,
        PortalSignInResult.unexpected,
        PortalSignInResult.unexpected,
        PortalSignInResult.unexpected,
        PortalSignInResult.unexpected,
      ],
      reason: 'a gateway landing was mistaken for a different sign-in result',
    );
  });

  test('A password change page is an unexpected landing', () {
    final page = Uri.parse(_page('Смена пароля.aspx'));
    expect(
      portalSignInLanding(page),
      PortalSignInResult.unexpected,
      reason: 'the password change page was mistaken for a sign-in result',
    );
  });

  test(
      'a workload page the gateway marked after sign-in is still the workload page',
      () {
    expect(
      isWorkloadPage(Uri.parse(
          '${_page('Нагрузка на первую половину дня.aspx')}${_marker(Random())}')),
      isTrue,
      reason: 'the marked workload page was not recognised',
    );
  });

  test('another page marked by the gateway is not the workload page', () {
    expect(
      isWorkloadPage(
          Uri.parse('${_page('Расписание.aspx')}${_marker(Random())}')),
      isFalse,
      reason: 'a foreign page was taken for the workload page',
    );
  });

  test('the remembered workload address drops the gateway marker', () {
    final page = _page('Нагрузка на первую половину дня.aspx');
    expect(
      portalAddress(Uri.parse('$page${_marker(Random())}')),
      equals(Uri.parse(page)),
      reason: 'the gateway marker stayed in the remembered address',
    );
  });

  test('the form opens on the remembered department', () {
    expect(
      workloadSelection(_report(department: '2095'), DateTime(2026, 11),
          department: '1726')['department'],
      equals('1726'),
      reason: 'the remembered department was not chosen',
    );
  });

  test('a remembered department the portal no longer offers is ignored', () {
    expect(
      workloadSelection(_report(department: '2095'), DateTime(2026, 11),
          department: '${Random().nextInt(900) + 3000}')['department'],
      equals('2095'),
      reason: 'a department missing on the portal was requested',
    );
  });

  test('the form opens on the study year of the month', () {
    expect(
      workloadSelection(_report(), DateTime(2026, 11))['year'],
      equals('2026'),
      reason: 'the study year of November 2026 was not chosen',
    );
  });

  test('the form opens on the month found by its label', () {
    expect(
      workloadSelection(_report(), DateTime(2026, 11))['month'],
      equals('3'),
      reason: 'November 2026 was not chosen by its label',
    );
  });

  test('a month the portal does not list leaves the month unchanged', () {
    expect(
      workloadSelection(_report(), DateTime(2027, 3))['month'],
      equals('1'),
      reason: 'a month missing on the portal was requested',
    );
  });
}
