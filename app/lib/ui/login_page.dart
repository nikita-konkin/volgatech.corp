import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/login_utils.dart';
import '../core/prefs.dart';
import '../state/auth_controller.dart';
import '../theme.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _login = TextEditingController();
  final _password = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscure = true;
  bool _remember = true;

  @override
  void initState() {
    super.initState();
    final prefs = context.read<Prefs>();
    _remember = prefs.rememberLogin;
    if (_remember && prefs.rememberedLogin != null) {
      _login.text = prefs.rememberedLogin!;
    }
  }

  @override
  void dispose() {
    _login.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final auth = context.read<AuthController>();
    final prefs = context.read<Prefs>();

    // Accept a full e-mail as the login and reduce it to the bare account name
    // (KonkinNA@volgatech.net -> konkinna); show the cleaned value in the field.
    final login = normalizeLogin(_login.text);
    if (login != _login.text) _login.text = login;

    // Remember (or forget) the username per the checkbox.
    await prefs.setRememberLogin(_remember);
    await prefs.setRememberedLogin(_remember ? login : null);

    final ok = await auth.login(login, _password.text);
    if (ok) {
      // Let the OS password manager offer to save the credentials.
      TextInput.finishAutofillContext();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.error ?? 'Ошибка входа')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authenticating = context.select<AuthController, bool>(
        (a) => a.status == AuthStatus.authenticating);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Brand banner
            Container(
              width: double.infinity,
              color: Brand.blue,
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
              child: const Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: Colors.white,
                    child: Text('ПГТУ',
                        style: TextStyle(
                            color: Brand.blue,
                            fontWeight: FontWeight.bold,
                            fontSize: 12)),
                  ),
                  SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'ЛИЧНЫЙ КАБИНЕТ\nРАБОТНИКА ПГТУ',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          height: 1.2),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: AutofillGroup(
                    child: Column(
                      children: [
                        const SizedBox(height: 20),
                        const Text('Авторизация',
                            style: TextStyle(
                                fontSize: 26, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 24),
                        TextFormField(
                          controller: _login,
                          textInputAction: TextInputAction.next,
                          autocorrect: false,
                          enableSuggestions: false,
                          autofillHints: const [AutofillHints.username],
                          decoration: const InputDecoration(hintText: 'Логин'),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Введите логин'
                              : null,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _password,
                          obscureText: _obscure,
                          autofillHints: const [AutofillHints.password],
                          onFieldSubmitted: (_) => _submit(),
                          decoration: InputDecoration(
                            hintText: 'Пароль',
                            suffixIcon: IconButton(
                              icon: Icon(_obscure
                                  ? Icons.visibility_off
                                  : Icons.visibility),
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure),
                            ),
                          ),
                          validator: (v) => (v == null || v.isEmpty)
                              ? 'Введите пароль'
                              : null,
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Checkbox(
                              value: _remember,
                              onChanged: (v) =>
                                  setState(() => _remember = v ?? true),
                            ),
                            const Text('Запомнить логин'),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: 220,
                          child: ElevatedButton(
                            onPressed: authenticating ? null : _submit,
                            child: authenticating
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white),
                                  )
                                : const Text('ВОЙТИ'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
