import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/app_lock.dart';
import 'state/auth_controller.dart';
import 'state/theme_controller.dart';
import 'theme.dart';
import 'ui/lock_screen.dart';
import 'ui/login_page.dart';
import 'ui/schedule_page.dart';

class VolgatechApp extends StatelessWidget {
  const VolgatechApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeMode = context.watch<ThemeController>().mode;
    return MaterialApp(
      title: 'Волгатех.Коллектив',
      debugShowCheckedModeBanner: false,
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: themeMode,
      locale: const Locale('ru'),
      supportedLocales: const [Locale('ru'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // Wrap the whole Navigator so the lock covers pushed routes too
      // (Settings, Profile), not just the home screen.
      builder: (context, child) =>
          _LockGate(child: child ?? const SizedBox.shrink()),
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
        return const SchedulePage();
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
