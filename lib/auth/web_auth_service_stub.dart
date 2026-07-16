import 'auth_service.dart';
import 'token_storage.dart';

class WebAuthService {
  WebAuthService(TokenStorage tokenStorage);

  Future<void> login() async {
    throw UnsupportedError('WebAuthService доступен только в браузере');
  }

  Future<AuthTokens?> handleRedirectIfNeeded() async {
    return null;
  }

  Future<AuthTokens> refreshTokens() async {
    throw UnsupportedError('WebAuthService доступен только в браузере');
  }

  Future<AuthTokens> getSavedTokens() async {
    throw UnsupportedError('WebAuthService доступен только в браузере');
  }

  Future<void> logout() async {}
}