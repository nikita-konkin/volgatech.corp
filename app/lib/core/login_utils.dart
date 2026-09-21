/// Normalise a login for the auth API.
///
/// Users sometimes type their full corporate e-mail as the login
/// (`KonkinNA@volgatech.net`), but the backend expects the bare account name
/// (`konkinna`). So we: trim whitespace, drop an `@domain` suffix when present,
/// and lowercase. The login is the AD account name (case-insensitive), so
/// lowercasing is safe and spares users the domain suffix and capitalisation.
/// Pure and unit-tested (see test/login_utils_test.dart).
String normalizeLogin(String input) {
  var s = input.trim();
  final at = s.indexOf('@');
  if (at > 0) s = s.substring(0, at); // keep the local part before "@domain"
  return s.toLowerCase();
}
