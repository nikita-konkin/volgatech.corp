import '../core/prefs.dart';
import 'mail_models.dart';

/// The mail server's refusals of the saved password, in a row. A refusal
/// isn't always a wrong password — the account locked for a while, a
/// connection dropped halfway through signing in, the server restarting —
/// so the password stays until its owner signs out or types a new one.
/// Instead, nothing tries it again unasked for a while ([pause]), longer
/// each time: a password that really is wrong then makes only a few failed
/// sign-ins a day, far from what locks the domain account. Kept in
/// preferences, which the background check and the app share.
class MailRefusals {
  MailRefusals(this._prefs, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  final Prefs _prefs;
  final DateTime Function() _clock;

  /// Refusals in a row, as last read.
  int get count => _prefs.mailRefusals;

  /// How long after the [count]th refusal in a row to try again unasked.
  static Duration pause(int count) => switch (count) {
        <= 0 => Duration.zero,
        1 => const Duration(hours: 1),
        2 => const Duration(hours: 3),
        _ => const Duration(hours: 12),
      };

  /// Whether the saved password may be tried unasked now: the background
  /// check, the badge, the mail screen opening.
  Future<bool> mayTry() async {
    await _prefs.reload();
    final at = _prefs.mailRefusedAt;
    return count == 0 || at == null || !_clock().isBefore(at.add(pause(count)));
  }

  /// One more refusal; how many in a row now.
  Future<int> refused() async {
    await _prefs.reload();
    final n = count + 1;
    await _prefs.setMailRefused(n, _clock().toUtc());
    return n;
  }

  /// The server took the password (or there's none to try any more);
  /// whether it had been refusing it.
  Future<bool> accepted() async {
    await _prefs.reload();
    if (count == 0) return false;
    await _prefs.clearMailRefused();
    return true;
  }
}

/// What «Отчёты об ошибках» keeps of a refusal: what the server said, never
/// the login or the password.
String refusalReport(MailAuthException e) =>
    'Почта: сервер не принял пароль (${e.serverReply ?? 'HTTP 401'})';
