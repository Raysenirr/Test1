import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _idTokenKey = 'id_token';
  static const String _accessTokenExpirationKey = 'access_token_expiration';
  static const String _tokenTypeKey = 'token_type';
  static const String _scopeKey = 'scope';
  static const String _lastTokenRefreshTimeKey = 'last_token_refresh_time';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<void> saveTokens({
    required String accessToken,
    String? refreshToken,
    String? idToken,
    DateTime? accessTokenExpiration,
    String? tokenType,
    List<String>? scopes,
    required DateTime lastTokenRefreshTime,
  }) async {
    await _storage.write(key: _accessTokenKey, value: accessToken);

    if (refreshToken != null && refreshToken.isNotEmpty) {
      await _storage.write(key: _refreshTokenKey, value: refreshToken);
    }

    if (idToken != null && idToken.isNotEmpty) {
      await _storage.write(key: _idTokenKey, value: idToken);
    }

    if (accessTokenExpiration != null) {
      await _storage.write(
        key: _accessTokenExpirationKey,
        value: accessTokenExpiration.toIso8601String(),
      );
    }

    if (tokenType != null && tokenType.isNotEmpty) {
      await _storage.write(key: _tokenTypeKey, value: tokenType);
    }

    if (scopes != null && scopes.isNotEmpty) {
      await _storage.write(key: _scopeKey, value: scopes.join(' '));
    }

    await _storage.write(
      key: _lastTokenRefreshTimeKey,
      value: lastTokenRefreshTime.toIso8601String(),
    );
  }

  Future<String?> getAccessToken() {
    return _storage.read(key: _accessTokenKey);
  }

  Future<String?> getRefreshToken() {
    return _storage.read(key: _refreshTokenKey);
  }

  Future<String?> getIdToken() {
    return _storage.read(key: _idTokenKey);
  }

  Future<String?> getTokenType() {
    return _storage.read(key: _tokenTypeKey);
  }

  Future<List<String>?> getScopes() async {
    final value = await _storage.read(key: _scopeKey);

    if (value == null || value.isEmpty) {
      return null;
    }

    return value.split(' ');
  }

  Future<DateTime?> getAccessTokenExpiration() async {
    final value = await _storage.read(key: _accessTokenExpirationKey);

    if (value == null) {
      return null;
    }

    return DateTime.tryParse(value);
  }

  Future<DateTime?> getLastTokenRefreshTime() async {
    final value = await _storage.read(key: _lastTokenRefreshTimeKey);

    if (value == null) {
      return null;
    }

    return DateTime.tryParse(value);
  }

  Future<void> clear() {
    return _storage.deleteAll();
  }
}