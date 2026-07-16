import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'auth_service.dart';
import 'user_profile.dart';
import 'web_auth_service_stub.dart'
    if (dart.library.html) 'web_auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService;
  late final WebAuthService _webAuthService;

  bool _isLoading = false;
  bool _isAuthenticated = false;
  bool _isRefreshing = false;
  String? _errorMessage;

  String? _accessToken;
  String? _idToken;
  String? _refreshToken;
  DateTime? _accessTokenExpiration;
  String? _tokenType;
  List<String>? _scopes;
  DateTime? _lastTokenRefreshTime;
  UserProfile? _profile;

  Timer? _refreshTimer;

  AuthProvider(this._authService) {
    _webAuthService = WebAuthService(_authService.tokenStorage);
  }

  bool get isLoading => _isLoading;
  bool get isAuthenticated => _isAuthenticated;
  String? get errorMessage => _errorMessage;

  String? get accessToken => _accessToken;
  String? get idToken => _idToken;
  String? get refreshToken => _refreshToken;
  DateTime? get accessTokenExpiration => _accessTokenExpiration;
  String? get tokenType => _tokenType;
  List<String>? get scopes => _scopes;
  DateTime? get lastTokenRefreshTime => _lastTokenRefreshTime;
  UserProfile? get profile => _profile;

  int? get expiresIn {
    final expiration = _accessTokenExpiration;

    if (expiration == null) {
      return null;
    }

    final seconds = expiration.difference(DateTime.now()).inSeconds;

    if (seconds < 0) {
      return 0;
    }

    return seconds;
  }

  String get authorizationStatus {
    return _isAuthenticated ? 'Авторизован' : 'Не авторизован';
  }

  Future<void> checkAuthState() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (kIsWeb) {
        final redirectTokens = await _webAuthService.handleRedirectIfNeeded();

        if (redirectTokens != null) {
          _setTokens(redirectTokens);
          _isAuthenticated = true;
          return;
        }
      }

      final savedTokens = await _getSavedTokens();

      if (savedTokens.accessToken == null && savedTokens.refreshToken == null) {
        await _forceLogout();
        return;
      }

      if (_authService.isAccessTokenActual(savedTokens.accessTokenExpiration)) {
        _setTokens(savedTokens);
        _isAuthenticated = savedTokens.accessToken != null;
        return;
      }

      if (savedTokens.refreshToken != null) {
        final refreshedTokens = await _refreshTokensByPlatform();
        _setTokens(refreshedTokens);
        _isAuthenticated = true;
        return;
      }

      await _forceLogout();
    } catch (error, stackTrace) {
      debugPrint('CHECK AUTH ERROR: $error');
      debugPrint('CHECK AUTH STACKTRACE: $stackTrace');

      await _forceLogout();
      _errorMessage = 'Сессия истекла. Войдите заново.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> login() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (kIsWeb) {
        await _webAuthService.login();
        return;
      }

      final tokens = await _authService.login();

      _setTokens(tokens);
      _isAuthenticated = true;
    } catch (error, stackTrace) {
      debugPrint('LOGIN ERROR: $error');
      debugPrint('LOGIN STACKTRACE: $stackTrace');

      await _forceLogout();
      _errorMessage = error.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshTokens() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final tokens = await _refreshTokensByPlatform();

      _setTokens(tokens);
      _isAuthenticated = true;
    } catch (error, stackTrace) {
      debugPrint('REFRESH ERROR: $error');
      debugPrint('REFRESH STACKTRACE: $stackTrace');

      await _forceLogout();
      _errorMessage = 'Сессия истекла. Войдите заново.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _refreshTokensSilently() async {
    if (_isRefreshing) {
      return;
    }

    _isRefreshing = true;

    try {
      final tokens = await _refreshTokensByPlatform();

      _setTokens(tokens);
      _isAuthenticated = true;
      _errorMessage = null;

      notifyListeners();
    } catch (error, stackTrace) {
      debugPrint('AUTO REFRESH ERROR: $error');
      debugPrint('AUTO REFRESH STACKTRACE: $stackTrace');

      await _forceLogout();
      _errorMessage = 'Сессия истекла. Войдите заново.';

      notifyListeners();
    } finally {
      _isRefreshing = false;
    }
  }

  Future<void> logout() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _logoutByPlatform();
      _clearState();
    } catch (error, stackTrace) {
      debugPrint('LOGOUT ERROR: $error');
      debugPrint('LOGOUT STACKTRACE: $stackTrace');

      _clearState();
      _errorMessage = error.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<AuthTokens> _getSavedTokens() {
    if (kIsWeb) {
      return _webAuthService.getSavedTokens();
    }

    return _authService.getSavedTokens();
  }

  Future<AuthTokens> _refreshTokensByPlatform() {
    if (kIsWeb) {
      return _webAuthService.refreshTokens();
    }

    return _authService.refreshTokens();
  }

  Future<void> _logoutByPlatform() {
    if (kIsWeb) {
      return _webAuthService.logout();
    }

    return _authService.logout();
  }

  void _setTokens(AuthTokens tokens) {
    _accessToken = tokens.accessToken;
    _idToken = tokens.idToken;
    _refreshToken = tokens.refreshToken;
    _accessTokenExpiration = tokens.accessTokenExpiration;
    _tokenType = tokens.tokenType;
    _scopes = tokens.scopes;
    _lastTokenRefreshTime = tokens.lastTokenRefreshTime;

    if (_idToken != null && _idToken!.isNotEmpty) {
      try {
        _profile = UserProfile.fromIdToken(_idToken!);
      } catch (error) {
        debugPrint('PROFILE DECODE ERROR: $error');
        _profile = null;
      }
    } else {
      _profile = null;
    }

    _scheduleAccessTokenRefresh();
  }

  void _scheduleAccessTokenRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = null;

    final expiration = _accessTokenExpiration;

    if (expiration == null) {
      debugPrint(
        'AUTO REFRESH: access token expiration отсутствует, таймер не поставлен',
      );
      return;
    }

    if (_refreshToken == null || _refreshToken!.isEmpty) {
      debugPrint(
        'AUTO REFRESH: refresh token отсутствует, таймер не поставлен',
      );
      return;
    }

    final refreshAt = expiration.subtract(const Duration(minutes: 5));
    final delay = refreshAt.difference(DateTime.now());

    if (delay.isNegative || delay == Duration.zero) {
      debugPrint(
        'AUTO REFRESH: access token скоро истекает, обновляем сразу',
      );

      Future.microtask(_refreshTokensSilently);
      return;
    }

    debugPrint('AUTO REFRESH: следующее обновление через $delay');

    _refreshTimer = Timer(delay, _refreshTokensSilently);
  }

  Future<void> _forceLogout() async {
    _refreshTimer?.cancel();
    _refreshTimer = null;

    try {
      await _logoutByPlatform();
    } catch (error) {
      debugPrint('FORCE LOGOUT STORAGE CLEAR ERROR: $error');
    }

    _clearState();
  }

  void _clearState() {
    _refreshTimer?.cancel();
    _refreshTimer = null;

    _isAuthenticated = false;
    _accessToken = null;
    _idToken = null;
    _refreshToken = null;
    _accessTokenExpiration = null;
    _tokenType = null;
    _scopes = null;
    _lastTokenRefreshTime = null;
    _profile = null;
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }
}