import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/api_client.dart';
import 'core/app_lock.dart';
import 'core/notifications.dart';
import 'mail/mail_config.dart';
import 'mail/ui/mail_page.dart';
import 'state/auth_controller.dart';
import 'state/theme_controller.dart';
import 'theme.dart';
import 'ui/home_shell.dart';
import 'ui/lock_screen.dart';
import 'ui/login_page.dart';
import 'ui/update_banner.dart';
import 'web/a11y.dart';
import 'web/insets.dart';

class VolgatechApp extends StatefulWidget {
  const VolgatechApp({super.key});

  @override
  State<VolgatechApp> createState() => _VolgatechAppState();
}

class _VolgatechAppState extends State<VolgatechApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // High contrast switched on or off meanwhile.
  @override
  void didChangeAccessibilityFeatures() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeController>();
    // Glass gives way to solid surfaces for whoever asked the system for
    // them.
    final glass = theme.glass &&
        !WidgetsBinding
            .instance.platformDispatcher.accessibilityFeatures.highContrast &&
        !prefersSolidSurfaces();
    return MaterialApp(
      title: 'Волгатех.Коллектив',
      debugShowCheckedModeBanner: false,
      theme: buildLightTheme(
          glass: glass, scuffed: theme.scuffed, strength: theme.strength),
      darkTheme: buildDarkTheme(
          glass: glass, scuffed: theme.scuffed, strength: theme.strength),
      themeMode: theme.mode,
      locale: const Locale('ru'),
      supportedLocales: const [Locale('ru'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // Wrap the whole Navigator so the lock covers pushed routes too
      // (Settings, Profile), not just the home screen.
      builder: (context, child) => _TestServerMark(
          child: BrowserInsets(
              child: _LockGate(
                  child:
                      UpdateWatcher(child: child ?? const SizedBox.shrink())))),
      home: const _AuthGate(),
    );
  }
}

/// Wraps the app in the optional biometric/PIN lock and re-locks whenever the
/// app is sent to the background.
class _LockGate extends StatefulWidget {
  const _LockGate({required this.child});
  final Widget child;

  @override
  State<_LockGate> createState() => _LockGateState();
}

class _LockGateState extends State<_LockGate> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Re-lock as soon as the app leaves the foreground.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      context.read<AppLock>().lock();
    }
  }

  @override
  Widget build(BuildContext context) {
    final locked = context.watch<AppLock>().isLocked;
    return Stack(
      children: [
        widget.child,
        if (locked) const LockScreen(),
      ],
    );
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    final status = context.watch<AuthController>().status;
    switch (status) {
      case AuthStatus.authenticated:
        return const _NotificationTaps(child: HomeShell());
      case AuthStatus.unauthenticated:
      case AuthStatus.authenticating:
        return const LoginPage();
      case AuthStatus.unknown:
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
    }
  }
}

/// A tapped notification of new mail opens «Почта» (a lesson's just opens
/// the app, on the schedule).
class _NotificationTaps extends StatefulWidget {
  const _NotificationTaps({required this.child});
  final Widget child;

  @override
  State<_NotificationTaps> createState() => _NotificationTapsState();
}

class _NotificationTapsState extends State<_NotificationTaps> {
  @override
  void initState() {
    super.initState();
    Notifications.tapped.addListener(_open);
    // One that started the app came before this screen.
    WidgetsBinding.instance.addPostFrameCallback((_) => _open());
  }

  @override
  void dispose() {
    Notifications.tapped.removeListener(_open);
    super.dispose();
  }

  void _open() {
    final what = Notifications.tapped.value;
    if (what == null || !mounted) return;
    Notifications.tapped.value = null;
    if (what == 'mail' && kNativeMail) {
      final nav = Navigator.of(context);
      // Not a second «Почта» on top of an open one.
      nav.popUntil((r) => r.isFirst);
      nav.push(MaterialPageRoute<void>(builder: (_) => const MailPage()));
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// On a build for the test server (`--dart-define=API=test`), «ТЕСТ» across
/// the corner, so it is never taken for the real thing.
class _TestServerMark extends StatelessWidget {
  const _TestServerMark({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => kTestServer
      ? Banner(
          message: 'ТЕСТ',
          location: BannerLocation.topEnd,
          color: Colors.deepOrange,
          child: child,
        )
      : child;
}
