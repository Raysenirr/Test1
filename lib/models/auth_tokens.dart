class AuthTokens {
  final String? accessToken;
  final String? idToken;
  final String? refreshToken;
  final DateTime? accessTokenExpiration;
  final String? tokenType;
  final List<String>? scopes;
  final DateTime? lastTokenRefreshTime;

  const AuthTokens({
    required this.accessToken,
    required this.idToken,
    required this.refreshToken,
    required this.accessTokenExpiration,
    required this.tokenType,
    required this.scopes,
    required this.lastTokenRefreshTime,
  });

  int? get expiresIn {
    final expiration = accessTokenExpiration;

    if (expiration == null) {
      return null;
    }

    final seconds = expiration.difference(DateTime.now()).inSeconds;

    if (seconds < 0) {
      return 0;
    }

    return seconds;
  }
}