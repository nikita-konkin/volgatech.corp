import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/portal_workload_client.dart';
import '../mail/mail_credentials.dart';
import 'layout.dart';

const _loginKey = 'portal_workload_login';

/// The native sign-in form for the university portal.
final class PortalSignIn extends StatefulWidget {
  const PortalSignIn({
    super.key,
    required this.signIn,
    required this.onSignedIn,
    required this.onUnexpected,
    this.message,
  });

  final Future<PortalSignInResult> Function(String login, String password)
      signIn;
  final VoidCallback onSignedIn;
  final VoidCallback onUnexpected;
  final String? message;

  @override
  State<PortalSignIn> createState() => _PortalSignInState();
}

/// The credentials and status for the visible sign-in form.
final class _PortalSignInState extends State<PortalSignIn> {
  final _login = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  String? get _domainLogin => loginCandidates(_login.text).firstOrNull;

  bool get _canSubmit =>
      !_busy && _password.text.isNotEmpty && _domainLogin != null;

  @override
  void initState() {
    super.initState();
    unawaited(_prefill());
  }

  Future<void> _prefill() async {
    final preferences = await SharedPreferences.getInstance();
    if (!mounted || _login.text.isNotEmpty) return;
    setState(() => _login.text = preferences.getString(_loginKey) ?? '');
  }

  @override
  void dispose() {
    _login.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    final typed = _login.text;
    setState(() {
      _busy = true;
      _error = null;
    });
    FocusScope.of(context).unfocus();
    final result = await widget.signIn(_domainLogin!, _password.text);
    if (!mounted) return;
    _password.clear();
    if (result == PortalSignInResult.signedIn) {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(_loginKey, typed);
      if (!mounted) return;
    }
    setState(() {
      _busy = false;
      if (result == PortalSignInResult.rejected) {
        _error = 'Неверный логин или пароль';
      }
    });
    if (result == PortalSignInResult.signedIn) widget.onSignedIn();
    if (result == PortalSignInResult.unexpected) widget.onUnexpected();
  }

  @override
  Widget build(BuildContext context) {
    final message = _error ?? widget.message;
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ReadableWidth(
          max: 400,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Вход на портал', style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              const Text(
                  'Логин и пароль — те же, что для университетской почты'),
              const SizedBox(height: 16),
              TextField(
                controller: _login,
                enabled: !_busy,
                autocorrect: false,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Логин'),
                onChanged: (_) => setState(() => _error = null),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _password,
                enabled: !_busy,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Пароль'),
                onChanged: (_) => setState(() => _error = null),
                onSubmitted: (_) => unawaited(_submit()),
              ),
              if (message != null) ...[
                const SizedBox(height: 12),
                Semantics(
                  liveRegion: true,
                  child: Text(message,
                      style: TextStyle(color: theme.colorScheme.error)),
                ),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _canSubmit ? _submit : null,
                child: _busy
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Войти'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
