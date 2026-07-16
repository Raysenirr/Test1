import 'package:flutter/foundation.dart';

import '../models/auth_state.dart';
import '../models/auth_tokens.dart';
import '../models/user_profile.dart';
import 'auth_service.dart';
import 'web_auth_service_stub.dart'
    if (dart.library.html) 'web_auth_service.dart';

class AuthSessionManager {
  final AuthService _mobileAuthService;
  late final WebAuthService _webAuthService;

  AuthSessionManager(this._mobileAuthService) {
    _webAuthService = WebAuthService(_mobileAuthService.tokenStorage);
  }

  Future<AuthState> restoreSession() async {
    if (kIsWeb) {
      final redirectTokens = await _webAuthService.handleRedirectIfNeeded();

      if (redirectTokens != null) {
        return _buildAuthenticatedState(redirectTokens);
      }
    }

    final savedTokens = await getSavedTokens();

    if (savedTokens.accessToken == null && savedTokens.refreshToken == null) {
      await logout();
      return const AuthState.unauthenticated();
    }

    if (_mobileAuthService.isAccessTokenActual(
      savedTokens.accessTokenExpiration,
    )) {
      return _buildAuthenticatedState(savedTokens);
    }

    if (savedTokens.refreshToken != null) {
      final refreshedTokens = await refreshTokens();
      return _buildAuthenticatedState(refreshedTokens);
    }

    await logout();
    return const AuthState.unauthenticated();
  }

  Future<AuthState?> login() async {
    if (kIsWeb) {
      await _webAuthService.login();
      return null;
    }

    final tokens = await _mobileAuthService.login();
    return _buildAuthenticatedState(tokens);
  }

  Future<AuthState> refreshSession() async {
    final tokens = await refreshTokens();
    return _buildAuthenticatedState(tokens);
  }

  Future<AuthTokens> refreshTokens() {
    if (kIsWeb) {
      return _webAuthService.refreshTokens();
    }

    return _mobileAuthService.refreshTokens();
  }

  Future<AuthTokens> getSavedTokens() {
    if (kIsWeb) {
      return _webAuthService.getSavedTokens();
    }

    return _mobileAuthService.getSavedTokens();
  }

  Future<void> logout() {
    if (kIsWeb) {
      return _webAuthService.logout();
    }

    return _mobileAuthService.logout();
  }

  AuthState _buildAuthenticatedState(AuthTokens tokens) {
    UserProfile? profile;

    final idToken = tokens.idToken;

    if (idToken != null && idToken.isNotEmpty) {
      try {
        profile = UserProfile.fromIdToken(idToken);
      } catch (error) {
        debugPrint('PROFILE DECODE ERROR: $error');
      }
    }

    return AuthState.authenticated(
      tokens: tokens,
      profile: profile,
    );
  }
}