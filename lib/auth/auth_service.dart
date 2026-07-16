import 'package:flutter_appauth/flutter_appauth.dart';

import '../config/oidc_config.dart';
import 'token_storage.dart';

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

class AuthService {
  final FlutterAppAuth _appAuth = const FlutterAppAuth();
  final TokenStorage _tokenStorage;

  AuthService(this._tokenStorage);

  TokenStorage get tokenStorage => _tokenStorage;

  Future<AuthTokens> login() async {
    final result = await _appAuth.authorizeAndExchangeCode(
      AuthorizationTokenRequest(
        OidcConfig.clientId,
        OidcConfig.mobileRedirectUrl,
        discoveryUrl: OidcConfig.discoveryUrl,
        scopes: OidcConfig.scopes,
      ),
    );

    if (result.accessToken == null) {
      throw Exception('Не удалось получить access token');
    }

    final now = DateTime.now();
    final scopes = result.scopes ?? OidcConfig.scopes;

    await _tokenStorage.saveTokens(
      accessToken: result.accessToken!,
      refreshToken: result.refreshToken,
      idToken: result.idToken,
      accessTokenExpiration: result.accessTokenExpirationDateTime,
      tokenType: result.tokenType,
      scopes: scopes,
      lastTokenRefreshTime: now,
    );

    return AuthTokens(
      accessToken: result.accessToken,
      idToken: result.idToken,
      refreshToken: result.refreshToken,
      accessTokenExpiration: result.accessTokenExpirationDateTime,
      tokenType: result.tokenType,
      scopes: scopes,
      lastTokenRefreshTime: now,
    );
  }

  Future<AuthTokens> refreshTokens() async {
    final savedRefreshToken = await _tokenStorage.getRefreshToken();

    if (savedRefreshToken == null || savedRefreshToken.isEmpty) {
      throw Exception('Refresh token отсутствует. Нужно войти заново.');
    }

    final result = await _appAuth.token(
      TokenRequest(
        OidcConfig.clientId,
        OidcConfig.mobileRedirectUrl,
        discoveryUrl: OidcConfig.discoveryUrl,
        refreshToken: savedRefreshToken,
        scopes: OidcConfig.scopes,
      ),
    );

    if (result.accessToken == null) {
      throw Exception('Не удалось обновить access token');
    }

    final now = DateTime.now();
    final newRefreshToken = result.refreshToken ?? savedRefreshToken;
    final scopes = result.scopes ?? OidcConfig.scopes;

    await _tokenStorage.saveTokens(
      accessToken: result.accessToken!,
      refreshToken: newRefreshToken,
      idToken: result.idToken,
      accessTokenExpiration: result.accessTokenExpirationDateTime,
      tokenType: result.tokenType,
      scopes: scopes,
      lastTokenRefreshTime: now,
    );

    return AuthTokens(
      accessToken: result.accessToken,
      idToken: result.idToken,
      refreshToken: newRefreshToken,
      accessTokenExpiration: result.accessTokenExpirationDateTime,
      tokenType: result.tokenType,
      scopes: scopes,
      lastTokenRefreshTime: now,
    );
  }

  Future<AuthTokens> getSavedTokens() async {
    return AuthTokens(
      accessToken: await _tokenStorage.getAccessToken(),
      idToken: await _tokenStorage.getIdToken(),
      refreshToken: await _tokenStorage.getRefreshToken(),
      accessTokenExpiration: await _tokenStorage.getAccessTokenExpiration(),
      tokenType: await _tokenStorage.getTokenType(),
      scopes: await _tokenStorage.getScopes(),
      lastTokenRefreshTime: await _tokenStorage.getLastTokenRefreshTime(),
    );
  }

  Future<void> logout() async {
    await _tokenStorage.clear();
  }

  bool isAccessTokenActual(DateTime? expiration) {
    if (expiration == null) {
      return true;
    }

    return expiration.isAfter(DateTime.now().add(const Duration(minutes: 5)));
  }
}