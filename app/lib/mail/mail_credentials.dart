import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'mail_config.dart';

class MailCredentials {
  const MailCredentials(this.login, this.password);

  /// Exactly what the server accepted (see [loginCandidates]).
  final String login;
  final String password;
}

/// How to sign in as the account the user typed: `MARSTU\name`, the form
/// Exchange always accepts. One candidate only — every rejected attempt
/// counts towards the domain's lockout limit.
List<String> loginCandidates(String typed) {
  final login = typed.trim();
  if (login.contains(r'\')) return [login];
  final name = login.split('@').first;
  return name.isEmpty ? const [] : ['$kAdDomain\\$name'];
}

/// The mail password, only in builds with [kNativeMail]: Exchange asks for it
/// on every connection. Kept in the platform keystore (like the API tokens in
/// `Session`), never in preferences, the cache or logs.
class MailCredentialStore {
  MailCredentialStore({FlutterSecureStorage? storage})
      : _s = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  final FlutterSecureStorage _s;

  static const _kLogin = 'mailLogin';
  static const _kPassword = 'mailPassword';

  Future<MailCredentials?> read() async {
    final login = await _s.read(key: _kLogin);
    final password = await _s.read(key: _kPassword);
    if (login == null || password == null) return null;
    return MailCredentials(login, password);
  }

  Future<void> save(MailCredentials c) async {
    await _s.write(key: _kLogin, value: c.login);
    await _s.write(key: _kPassword, value: c.password);
  }

  Future<void> clear() async {
    await _s.delete(key: _kLogin);
    await _s.delete(key: _kPassword);
  }
}
