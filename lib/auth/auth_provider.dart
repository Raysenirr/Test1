import 'dart:async';

import 'package:flutter/material.dart';

import '../models/auth_state.dart';
import '../models/auth_tokens.dart';
import '../models/user_profile.dart';
import 'auth_session_manager.dart';

class AuthProvider extends ChangeNotifier {
  final AuthSessionManager _sessionManager;

  bool _isLoading = false;
  bool _isAuthenticated = false;
  bool _isRefreshing = false;
  String? _errorMessage;

  AuthTokens? _tokens;
  UserProfile? _profile;

  Timer? _refreshTimer;

  AuthProvider(this._sessionManager);

  bool get isLoading => _isLoading;
  bool get isAuthenticated => _isAuthenticated;
  String? get errorMessage => _errorMessage;

  String? get accessToken => _tokens?.accessToken;
  String? get idToken => _tokens?.idToken;
  String? get refreshToken => _tokens?.refreshToken;
  DateTime? get accessTokenExpiration => _tokens?.accessTokenExpiration;
  String? get tokenType => _tokens?.tokenType;
  List<String>? get scopes => _tokens?.scopes;
  DateTime? get lastTokenRefreshTime => _tokens?.lastTokenRefreshTime;
  UserProfile? get profile => _profile;

  int? get expiresIn => _tokens?.expiresIn;

  String get authorizationStatus {
    return _isAuthenticated ? 'Авторизован' : 'Не авторизован';
  }

  Future<void> checkAuthState() async {
    await _runWithLoading(() async {
      final state = await _sessionManager.restoreSession();
      _applyState(state);
    }, sessionExpiredMessage: true);
  }

  Future<void> login() async {
    await _runWithLoading(() async {
      final state = await _sessionManager.login();

      if (state == null) {
        return;
      }

      _applyState(state);
    });
  }

  Future<void> refreshTokens() async {
    await _runWithLoading(() async {
      final state = await _sessionManager.refreshSession();
      _applyState(state);
    }, sessionExpiredMessage: true);
  }

  Future<void> _refreshTokensSilently() async {
    if (_isRefreshing) {
      return;
    }

    _isRefreshing = true;

    try {
      final state = await _sessionManager.refreshSession();
      _applyState(state);
      _errorMessage = null;
      notifyListeners();
    } catch (error, stackTrace) {
      debugPrint('AUTO REFRESH ERROR: $error');
      debugPrint('AUTO REFRESH STACKTRACE: $stackTrace');

      await _logoutSilently();
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
      await _sessionManager.logout();
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

  Future<void> _runWithLoading(
    Future<void> Function() action, {
    bool sessionExpiredMessage = false,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await action();
    } catch (error, stackTrace) {
      debugPrint('AUTH ERROR: $error');
      debugPrint('AUTH STACKTRACE: $stackTrace');

      await _logoutSilently();

      _errorMessage = sessionExpiredMessage
          ? 'Сессия истекла. Войдите заново.'
          : error.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _applyState(AuthState state) {
    _isAuthenticated = state.isAuthenticated;
    _tokens = state.tokens;
    _profile = state.profile;

    _scheduleAccessTokenRefresh();
  }

  void _scheduleAccessTokenRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = null;

    final expiration = _tokens?.accessTokenExpiration;
    final refreshToken = _tokens?.refreshToken;

    if (!_isAuthenticated) {
      return;
    }

    if (expiration == null) {
      debugPrint(
        'AUTO REFRESH: access token expiration отсутствует, таймер не поставлен',
      );
      return;
    }

    if (refreshToken == null || refreshToken.isEmpty) {
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

  Future<void> _logoutSilently() async {
    _refreshTimer?.cancel();
    _refreshTimer = null;

    try {
      await _sessionManager.logout();
    } catch (error) {
      debugPrint('LOGOUT STORAGE CLEAR ERROR: $error');
    }

    _clearState();
  }

  void _clearState() {
    _refreshTimer?.cancel();
    _refreshTimer = null;

    _isAuthenticated = false;
    _tokens = null;
    _profile = null;
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }
}