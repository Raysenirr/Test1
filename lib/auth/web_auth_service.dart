// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:convert';
import 'dart:html' as html;
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import '../config/oidc_config.dart';
import 'auth_service.dart';
import 'token_storage.dart';

class WebAuthService {
  static const String _codeVerifierKey = 'oidc_code_verifier';
  static const String _stateKey = 'oidc_state';

  final TokenStorage _tokenStorage;

  WebAuthService(this._tokenStorage);

  Future<void> login() async {
    final discovery = await _loadDiscovery();

    final authorizationEndpoint = discovery['authorization_endpoint'];
    if (authorizationEndpoint is! String) {
      throw Exception('Discovery не вернул authorization_endpoint');
    }

    final codeVerifier = _generateCodeVerifier();
    final codeChallenge = _createCodeChallenge(codeVerifier);
    final state = _generateRandomString(32);

    html.window.localStorage[_codeVerifierKey] = codeVerifier;
    html.window.localStorage[_stateKey] = state;

    final authorizationUri = Uri.parse(authorizationEndpoint).replace(
      queryParameters: {
        'response_type': 'code',
        'client_id': OidcConfig.clientId,
        'redirect_uri': OidcConfig.webRedirectUrl,
        'scope': OidcConfig.scopes.join(' '),
        'state': state,
        'code_challenge': codeChallenge,
        'code_challenge_method': 'S256',
      },
    );

    html.window.location.assign(authorizationUri.toString());
  }

  Future<AuthTokens?> handleRedirectIfNeeded() async {
    final currentUri = Uri.parse(html.window.location.href);
    final code = currentUri.queryParameters['code'];
    final returnedState = currentUri.queryParameters['state'];
    final error = currentUri.queryParameters['error'];

    if (error != null) {
      throw Exception(
        'Ошибка авторизации: $error '
        '${currentUri.queryParameters['error_description'] ?? ''}',
      );
    }

    if (code == null) {
      return null;
    }

    final savedState = html.window.localStorage[_stateKey];
    final codeVerifier = html.window.localStorage[_codeVerifierKey];

    if (savedState == null || savedState != returnedState) {
      throw Exception('Некорректный state. Авторизация отклонена.');
    }

    if (codeVerifier == null || codeVerifier.isEmpty) {
      throw Exception('Не найден code_verifier для PKCE');
    }

    final tokens = await _exchangeCodeForTokens(
      code: code,
      codeVerifier: codeVerifier,
    );

    html.window.localStorage.remove(_codeVerifierKey);
    html.window.localStorage.remove(_stateKey);

    html.window.history.replaceState(null, '', OidcConfig.webRedirectUrl);

    return tokens;
  }

  Future<AuthTokens> refreshTokens() async {
    final refreshToken = await _tokenStorage.getRefreshToken();

    if (refreshToken == null || refreshToken.isEmpty) {
      throw Exception('Refresh token отсутствует. Нужно войти заново.');
    }

    final discovery = await _loadDiscovery();

    final tokenEndpoint = discovery['token_endpoint'];
    if (tokenEndpoint is! String) {
      throw Exception('Discovery не вернул token_endpoint');
    }

    final response = await http.post(
      Uri.parse(tokenEndpoint),
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: {
        'grant_type': 'refresh_token',
        'client_id': OidcConfig.clientId,
        'refresh_token': refreshToken,
        'scope': OidcConfig.scopes.join(' '),
      },
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Ошибка refresh token: ${response.statusCode} ${response.body}',
      );
    }

    return _saveTokenResponse(response.body, oldRefreshToken: refreshToken);
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

    html.window.localStorage.remove(_codeVerifierKey);
    html.window.localStorage.remove(_stateKey);
  }

  Future<AuthTokens> _exchangeCodeForTokens({
    required String code,
    required String codeVerifier,
  }) async {
    final discovery = await _loadDiscovery();

    final tokenEndpoint = discovery['token_endpoint'];
    if (tokenEndpoint is! String) {
      throw Exception('Discovery не вернул token_endpoint');
    }

    final response = await http.post(
      Uri.parse(tokenEndpoint),
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: {
        'grant_type': 'authorization_code',
        'client_id': OidcConfig.clientId,
        'code': code,
        'redirect_uri': OidcConfig.webRedirectUrl,
        'code_verifier': codeVerifier,
      },
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Ошибка Token Endpoint: ${response.statusCode} ${response.body}',
      );
    }

    return _saveTokenResponse(response.body);
  }

  Future<AuthTokens> _saveTokenResponse(
    String responseBody, {
    String? oldRefreshToken,
  }) async {
    final decoded = jsonDecode(responseBody);

    if (decoded is! Map<String, dynamic>) {
      throw Exception('Token Endpoint вернул неверный формат');
    }

    final accessToken = decoded['access_token']?.toString();

    if (accessToken == null || accessToken.isEmpty) {
      throw Exception('Token Endpoint не вернул access_token');
    }

    final idToken = decoded['id_token']?.toString();
    final refreshToken =
        decoded['refresh_token']?.toString() ?? oldRefreshToken;
    final tokenType = decoded['token_type']?.toString();

    final scopeRaw = decoded['scope']?.toString();
    final scopes = scopeRaw == null || scopeRaw.isEmpty
        ? OidcConfig.scopes
        : scopeRaw.split(' ');

    DateTime? accessTokenExpiration;
    final expiresInRaw = decoded['expires_in'];

    if (expiresInRaw != null) {
      final expiresIn = int.tryParse(expiresInRaw.toString());

      if (expiresIn != null) {
        accessTokenExpiration = DateTime.now().add(
          Duration(seconds: expiresIn),
        );
      }
    }

    final now = DateTime.now();

    await _tokenStorage.saveTokens(
      accessToken: accessToken,
      refreshToken: refreshToken,
      idToken: idToken,
      accessTokenExpiration: accessTokenExpiration,
      tokenType: tokenType,
      scopes: scopes,
      lastTokenRefreshTime: now,
    );

    return AuthTokens(
      accessToken: accessToken,
      idToken: idToken,
      refreshToken: refreshToken,
      accessTokenExpiration: accessTokenExpiration,
      tokenType: tokenType,
      scopes: scopes,
      lastTokenRefreshTime: now,
    );
  }

  Future<Map<String, dynamic>> _loadDiscovery() async {
    final response = await http.get(Uri.parse(OidcConfig.discoveryUrl));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Не удалось получить Discovery: ${response.statusCode} ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body);

    if (decoded is! Map<String, dynamic>) {
      throw Exception('Discovery вернул неверный формат');
    }

    return decoded;
  }

  String _generateCodeVerifier() {
    return _generateRandomString(64);
  }

  String _createCodeChallenge(String codeVerifier) {
    final bytes = ascii.encode(codeVerifier);
    final digest = sha256.convert(bytes);
    return base64UrlEncode(digest.bytes).replaceAll('=', '');
  }

  String _generateRandomString(int length) {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~';

    final random = Random.secure();

    return List.generate(
      length,
      (_) => chars[random.nextInt(chars.length)],
    ).join();
  }
}