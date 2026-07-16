import 'package:flutter_appauth/flutter_appauth.dart';

import '../config/oidc_config.dart';
import '../models/auth_tokens.dart';
import 'token_storage.dart';

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

    return _saveAndBuildTokens(
      accessToken: result.accessToken!,
      idToken: result.idToken,
      refreshToken: result.refreshToken,
      accessTokenExpiration: result.accessTokenExpirationDateTime,
      tokenType: result.tokenType,
      scopes: result.scopes,
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

    return _saveAndBuildTokens(
      accessToken: result.accessToken!,
      idToken: result.idToken,
      refreshToken: result.refreshToken ?? savedRefreshToken,
      accessTokenExpiration: result.accessTokenExpirationDateTime,
      tokenType: result.tokenType,
      scopes: result.scopes,
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

  Future<AuthTokens> _saveAndBuildTokens({
    required String accessToken,
    required String? idToken,
    required String? refreshToken,
    required DateTime? accessTokenExpiration,
    required String? tokenType,
    required List<String>? scopes,
  }) async {
    final now = DateTime.now();
    final actualScopes = scopes ?? OidcConfig.scopes;

    await _tokenStorage.saveTokens(
      accessToken: accessToken,
      refreshToken: refreshToken,
      idToken: idToken,
      accessTokenExpiration: accessTokenExpiration,
      tokenType: tokenType,
      scopes: actualScopes,
      lastTokenRefreshTime: now,
    );

    return AuthTokens(
      accessToken: accessToken,
      idToken: idToken,
      refreshToken: refreshToken,
      accessTokenExpiration: accessTokenExpiration,
      tokenType: tokenType,
      scopes: actualScopes,
      lastTokenRefreshTime: now,
    );
  }
}