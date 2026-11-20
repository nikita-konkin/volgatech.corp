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
