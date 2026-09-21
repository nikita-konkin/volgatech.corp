/// Tokens returned by /api/Auth/GetToken and /api/Auth/RefreshToken.
class AuthTokens {
  final String accessToken;
  final String refreshToken;

  const AuthTokens({required this.accessToken, required this.refreshToken});

  factory AuthTokens.fromJson(Map<String, dynamic> j) => AuthTokens(
        accessToken: (j['accessToken'] ?? j['access_token'] ?? '') as String,
        refreshToken: (j['refreshToken'] ?? j['refresh_token'] ?? '') as String,
      );

  bool get isValid => accessToken.isNotEmpty;
}
