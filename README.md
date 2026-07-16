четверг 23:19
Authoriza.7z
Файл
ну вот это коллеги на kotlin только клиент айди может различаться это ок
andler: no exist. decor=DecorView@3f3a117[MainActivity]
D/SurfaceView@c7b7840(16393): updateSurface: surface is not valid
I/SurfaceView@c7b7840(16393): releaseSurfaces: viewRoot = ViewRootImpl@4ccf122[MainActivity]
I/SurfaceView@c7b7840(16393): applyTransactionOnVriDraw: vri = ViewRootImpl@4ccf122[MainActivity] fRS = true t = 0x79114eca00 android.view.SurfaceView.releaseSurfaces:858 android.view.SurfaceView.updateSurface:998 android.view.SurfaceView.lambda$new$0$android-view-SurfaceView:200 
I/SurfaceView@c7b7840(16393): applyTransactionOnVriDraw: viewRoot.applyTransactionOnDrawFromReleaseSurfaces
I/ViewRootImpl@4ccf122[MainActivity](16393): from releaseSurfaces t.apply t = 0x79114eca00 и все та же ошибка redirect_uris must only contain web uris в приложении авторизы все норм
понедельник 0:48
понедельник 1:50
понедельник 11:05
вторник 18:00
вчера 0:24
flutter_application_1.zip
ZIP-архив
вчера 10:51

Да, лучше так. Архив, который ты прислала, у меня выглядит как дефолтный Flutter counter app, то есть там нет текущих auth_service.dart, auth_provider.dart и т.д. Поэтому показываю прямо по файлам: куда зайти и что заменить/создать.

Начни с этого набора. Это закрывает требования без UserInfo.

1. pubspec.yaml

В dependencies: должны быть эти зависимости:

dependencies:
  flutter:
    sdk: flutter

  flutter_appauth: ^9.0.1
  flutter_secure_storage: ^9.2.2
  provider: ^6.1.2

После этого:

flutter pub get
2. Создай файл lib/config/oidc_config.dart
class OidcConfig {
  static const String discoveryUrl =
      'https://a-kalinin-authoriza-backend-stand-d37a.twc1.net/oidc/.well-known/openid-configuration';

  static const String clientId =
      '88be8919-1792-42fe-9f17-e9ba64e17507';

  static const String redirectUrl =
      'ru.authoriza.demo:/oauth2callback';

  static const List<String> scopes = [
    'openid',
    'profile',
    'email',
    'offline_access',
  ];
}

Если ты вернулась на https://oidc.authoriza.ru/oidc, не меняй наугад. Оставь тот discovery, с которым у тебя реально прошёл вход и вернулись токены.

3. Создай файл lib/auth/token_storage.dart
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
4. Создай файл lib/auth/user_profile.dart
import 'dart:convert';

class UserProfile {
  final String? subject;
  final String? name;
  final String? preferredUsername;
  final String? email;
  final Map<String, dynamic> claims;

  const UserProfile({
    required this.subject,
    required this.name,
    required this.preferredUsername,
    required this.email,
    required this.claims,
  });

  factory UserProfile.fromIdToken(String idToken) {
    final parts = idToken.split('.');

    if (parts.length != 3) {
      throw Exception('ID token имеет неверный формат');
    }

    final payload = parts[1];
    final normalized = base64Url.normalize(payload);
    final decodedBytes = base64Url.decode(normalized);
    final decodedString = utf8.decode(decodedBytes);
    final decodedJson = jsonDecode(decodedString);

    if (decodedJson is! Map<String, dynamic>) {
      throw Exception('Не удалось прочитать payload ID token');
    }

    return UserProfile.fromClaims(decodedJson);
  }

  factory UserProfile.fromClaims(Map<String, dynamic> claims) {
    return UserProfile(
      subject: _readString(claims, [
        'sub',
        'subject',
        'user_id',
        'id',
      ]),
      name: _readString(claims, [
        'name',
        'full_name',
        'display_name',
      ]),
      preferredUsername: _readString(claims, [
        'preferred_username',
        'username',
        'login',
        'user_name',
        'nickname',
      ]),
      email: _readString(claims, [
        'email',
        'mail',
      ]),
      claims: claims,
    );
  }

  static String? _readString(
    Map<String, dynamic> claims,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = claims[key];

      if (value != null && value.toString().isNotEmpty) {
        return value.toString();
      }
    }

    return null;
  }
}
5. Создай файл lib/auth/auth_service.dart
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

  Future<AuthTokens> login() async {
    final result = await _appAuth.authorizeAndExchangeCode(
      AuthorizationTokenRequest(
        OidcConfig.clientId,
        OidcConfig.redirectUrl,
        discoveryUrl: OidcConfig.discoveryUrl,
        scopes: OidcConfig.scopes,
      ),
    );

    if (result.accessToken == null) {
      throw Exception('Не удалось получить access token');
    }

    final now = DateTime.now();

    await _tokenStorage.saveTokens(
      accessToken: result.accessToken!,
      refreshToken: result.refreshToken,
      idToken: result.idToken,
      accessTokenExpiration: result.accessTokenExpirationDateTime,
      tokenType: result.tokenType,
      scopes: result.scopes ?? OidcConfig.scopes,
      lastTokenRefreshTime: now,
    );

    return AuthTokens(
      accessToken: result.accessToken,
      idToken: result.idToken,
      refreshToken: result.refreshToken,
      accessTokenExpiration: result.accessTokenExpirationDateTime,
      tokenType: result.tokenType,
      scopes: result.scopes ?? OidcConfig.scopes,
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
        OidcConfig.redirectUrl,
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

    await _tokenStorage.saveTokens(
      accessToken: result.accessToken!,
      refreshToken: newRefreshToken,
      idToken: result.idToken,
      accessTokenExpiration: result.accessTokenExpirationDateTime,
      tokenType: result.tokenType,
      scopes: result.scopes ?? OidcConfig.scopes,
      lastTokenRefreshTime: now,
    );

    return AuthTokens(
      accessToken: result.accessToken,
      idToken: result.idToken,
      refreshToken: newRefreshToken,
      accessTokenExpiration: result.accessTokenExpirationDateTime,
      tokenType: result.tokenType,
      scopes: result.scopes ?? OidcConfig.scopes,
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
6. Создай файл lib/auth/auth_provider.dart
import 'dart:async';

import 'package:flutter/material.dart';

import 'auth_service.dart';
import 'user_profile.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService;

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

  AuthProvider(this._authService);

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
      final savedTokens = await _authService.getSavedTokens();

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
        final refreshedTokens = await _authService.refreshTokens();
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
      final tokens = await _authService.refreshTokens();

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
      final tokens = await _authService.refreshTokens();

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
      await _authService.logout();
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
      await _authService.logout();
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
7. lib/main.dart замени целиком

В твоём архиве сейчас дефолтный counter app, поэтому main.dart надо заменить полностью:

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'auth/auth_provider.dart';
import 'auth/auth_service.dart';
import 'auth/token_storage.dart';

void main() {
  final tokenStorage = TokenStorage();
  final authService = AuthService(tokenStorage);

  runApp(
    ChangeNotifierProvider(
      create: (_) => AuthProvider(authService)..checkAuthState(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OIDC Flutter Client',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (auth.isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (auth.isAuthenticated) {
      return const HomeScreen();
    }

    return const LoginScreen();
  }
}

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('OIDC вход'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Войдите через OpenID Connect',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: auth.isLoading
                    ? null
                    : () {
                        context.read<AuthProvider>().login();
                      },
                child: const Text('Войти'),
              ),
              if (auth.errorMessage != null) ...[
                const SizedBox(height: 16),
                Text(
                  auth.errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final profile = auth.profile;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Профиль и токены'),
        actions: [
          IconButton(
            onPressed: auth.isLoading
                ? null
                : () {
                    context.read<AuthProvider>().logout();
                  },
            icon: const Icon(Icons.logout),
            tooltip: 'Выйти',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          StatusBlock(auth: auth),

          const SizedBox(height: 16),

          ElevatedButton(
            onPressed: auth.isLoading
                ? null
                : () {
                    context.read<AuthProvider>().refreshTokens();
                  },
            child: const Text('Обновить токены через refresh token'),
          ),

          const SizedBox(height: 16),

          Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Профиль из ID Token',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('ID: ${profile?.subject ?? 'Нет данных'}'),
                  Text('Имя: ${profile?.name ?? 'Нет данных'}'),
                  Text(
                    'Логин: ${profile?.preferredUsername ?? 'Нет данных'}',
                  ),
                  Text('Email: ${profile?.email ?? 'Нет данных'}'),
                ],
              ),
            ),
          ),

          MaskedTokenBlock(
            title: 'Access Token',
            value: auth.accessToken,
          ),

          MaskedTokenBlock(
            title: 'ID Token',
            value: auth.idToken,
          ),

          MaskedTokenBlock(
            title: 'Refresh Token',
            value: auth.refreshToken,
          ),

          JwtBlock(
            title: 'Access Token payload',
            token: auth.accessToken,
          ),

          JwtBlock(
            title: 'ID Token payload',
            token: auth.idToken,
          ),

          if (auth.errorMessage != null) ...[
            const SizedBox(height: 16),
            Text(
              auth.errorMessage!,
              style: const TextStyle(color: Colors.red),
            ),
          ],
        ],
      ),
    );
  }
}

class StatusBlock extends StatelessWidget {
  final AuthProvider auth;

  const StatusBlock({
    super.key,
    required this.auth,
  });

  @override
  Widget build(BuildContext context) {
    final scopeText = auth.scopes?.join(' ') ?? 'Нет данных';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Состояние',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text('Статус авторизации: ${auth.authorizationStatus}'),
            Text('Token Type: ${auth.tokenType ?? 'Нет данных'}'),
            Text('Scope: $scopeText'),
            Text('Expires in: ${auth.expiresIn?.toString() ?? 'Нет данных'}'),
            Text(
              'Access Token истекает: '
              '${_formatDateTime(auth.accessTokenExpiration)}',
            ),
            const Text(
              'Refresh Token истекает: недоступно',
            ),
            Text(
              'Последнее обновление токенов: '
              '${_formatDateTime(auth.lastTokenRefreshTime)}',
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime? value) {
    if (value == null) {
      return 'Нет данных';
    }

    return value.toLocal().toString();
  }
}

class MaskedTokenBlock extends StatelessWidget {
  final String title;
  final String? value;

  const MaskedTokenBlock({
    super.key,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final maskedValue = _maskToken(value);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: SelectableText.rich(
          TextSpan(
            children: [
              TextSpan(
                text: '$title\n\n',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              TextSpan(
                text: maskedValue,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _maskToken(String? token) {
    if (token == null || token.isEmpty) {
      return 'Нет данных';
    }

    if (token.length <= 20) {
      return '${token.substring(0, 4)}...${token.substring(token.length - 4)}';
    }

    final start = token.substring(0, 12);
    final end = token.substring(token.length - 12);

    return '$start...$end';
  }
}

class JwtBlock extends StatelessWidget {
  final String title;
  final String? token;

  const JwtBlock({
    super.key,
    required this.title,
    required this.token,
  });

  @override
  Widget build(BuildContext context) {
    final decoded = _decodeJwtPayload(token);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: SelectableText.rich(
          TextSpan(
            children: [
              TextSpan(
                text: '$title\n\n',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              TextSpan(
                text: decoded ?? 'Не удалось декодировать payload',
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _decodeJwtPayload(String? token) {
    if (token == null || token.isEmpty) {
      return null;
    }

    final parts = token.split('.');

    if (parts.length != 3) {
      return null;
    }

    try {
      final normalized = base64Url.normalize(parts[1]);
      final decodedBytes = base64Url.decode(normalized);
      final decodedString = utf8.decode(decodedBytes);
      final decodedJson = jsonDecode(decodedString);

      const encoder = JsonEncoder.withIndent('  ');
      return encoder.convert(decodedJson);
    } catch (_) {
      return null;
    }
  }
}
8. android/app/build.gradle.kts

В defaultConfig у тебя должно быть:

manifestPlaceholders["appAuthRedirectScheme"] = "ru.authoriza.demo"

А в самый низ файла добавь:

dependencies {
    implementation("androidx.appcompat:appcompat:1.7.0")
}
9. android/app/src/main/AndroidManifest.xml

Замени целиком на это:

<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:tools="http://schemas.android.com/tools">

    <uses-permission android:name="android.permission.INTERNET" />

    <application
        android:label="flutter_application_1"
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher">

        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:launchMode="singleTop"
            android:taskAffinity=""
            android:theme="@style/LaunchTheme"
            android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
            android:hardwareAccelerated="true"
            android:windowSoftInputMode="adjustResize">

            <meta-data
                android:name="io.flutter.embedding.android.NormalTheme"
                android:resource="@style/NormalTheme" />

            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>

        </activity>

        <activity
            android:name="net.openid.appauth.RedirectUriReceiverActivity"
            android:exported="true"
            android:theme="@style/AppAuthRedirectTheme"
            tools:node="replace">
            <intent-filter>
                <action android:name="android.intent.action.VIEW" />

                <category android:name="android.intent.category.DEFAULT" />
                <category android:name="android.intent.category.BROWSABLE" />

                <data android:scheme="ru.authoriza.demo" />
            </intent-filter>
        </activity>

        <meta-data
            android:name="flutterEmbedding"
            android:value="2" />

    </application>

    <queries>
        <intent>
            <action android:name="android.intent.action.PROCESS_TEXT" />
            <data android:mimeType="text/plain" />
        </intent>
    </queries>

</manifest>
10. android/app/src/main/res/values/styles.xml

Внутрь <resources> добавь стиль:

<style name="AppAuthRedirectTheme" parent="Theme.AppCompat.Light.NoActionBar">
    <item name="android:windowNoTitle">true</item>
    <item name="android:windowActionBar">false</item>
    <item name="android:windowIsTranslucent">true</item>
    <item name="android:windowBackground">@android:color/transparent</item>
</style>

То есть в конце перед </resources>.

11. android/app/src/main/res/values-night/styles.xml

Туда тоже добавь:

<style name="AppAuthRedirectTheme" parent="Theme.AppCompat.NoActionBar">
    <item name="android:windowNoTitle">true</item>
    <item name="android:windowActionBar">false</item>
    <item name="android:windowIsTranslucent">true</item>
    <item name="android:windowBackground">@android:color/transparent</item>
</style>

После всех правок:

flutter clean
flutter pub get
flutter run

Проверка: входишь, видишь замаскированные токены, payload обоих JWT, token_type, scope, expires_in, время истечения access token, время последнего обновления. Потом закрываешь приложение и открываешь снова — оно должно восстановить сессию. Нажимаешь logout — должно очистить всё и вернуть на кнопку входа.

ладно не важно, как мне теперь добавить в этот код открытие для браузеров и айфонов

Да, можно. Только важно разделить:

flutter_appauth нормально подходит для Android и iOS, но не для браузера/web. На pub.dev у flutter_appauth указана работа через нативные AppAuth SDK для Android/iOS/macOS, а web там не является целевой платформой самого пакета.

То есть тебе нужны две ветки логики:

для Android/iOS — оставляешь flutter_appauth;

для браузера — делаешь отдельный web-flow через redirect на страницу Authoriza и обработку callback в браузере.

1. Что добавить для iPhone / iOS

Сначала в Authoriza добавь тот же redirect URI, что и для Android:

ru.authoriza.demo:/oauth2callback

Потом открой файл:

ios/Runner/Info.plist

И перед закрывающим:

</dict>
</plist>

добавь:

<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLName</key>
        <string>ru.authoriza.demo</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>ru.authoriza.demo</string>
        </array>
    </dict>
</array>

Итог: iOS будет знать, что ссылка вида:

ru.authoriza.demo:/oauth2callback

должна открывать твоё приложение. Для iOS custom URL scheme прописывается именно через CFBundleURLTypes в Info.plist; это стандартный способ настроить callback-схему для Flutter OAuth-приложения.

Код auth_service.dart для iOS менять почти не надо, потому что flutter_appauth сам работает и на Android, и на iOS:

final result = await _appAuth.authorizeAndExchangeCode(
  AuthorizationTokenRequest(
    OidcConfig.clientId,
    OidcConfig.redirectUrl,
    discoveryUrl: OidcConfig.discoveryUrl,
    scopes: OidcConfig.scopes,
  ),
);

То есть для iPhone главное — Info.plist и тот же redirect в Authoriza.

2. Что с браузером / Flutter Web

Для web нельзя просто оставить flutter_appauth, потому что он не рассчитан на Flutter Web. Поэтому для браузера лучше сделать отдельный WebAuthService.

В Authoriza для web нужно добавить отдельный redirect URI, например:

http://localhost:8080/callback.html

или, если запускаешь Flutter Web стандартно:

http://localhost:3000/callback.html

Порт должен совпадать с тем, на котором ты запускаешь web-приложение. Например:

flutter run -d chrome --web-port 3000

Тогда redirect URI будет:

http://localhost:3000/callback.html
3. Как лучше организовать конфиг

В lib/config/oidc_config.dart добавь отдельные redirect для mobile и web:

class OidcConfig {
  static const String discoveryUrl =
      'https://a-kalinin-authoriza-backend-stand-d37a.twc1.net/oidc/.well-known/openid-configuration';

  static const String issuer =
      'https://a-kalinin-authoriza-backend-stand-d37a.twc1.net/oidc';

  static const String clientId =
      '88be8919-1792-42fe-9f17-e9ba64e17507';

  static const String mobileRedirectUrl =
      'ru.authoriza.demo:/oauth2callback';

  static const String webRedirectUrl =
      'http://localhost:3000/callback.html';

  static const List<String> scopes = [
    'openid',
    'profile',
    'email',
    'offline_access',
  ];
}

И в мобильном AuthService замени:

OidcConfig.redirectUrl

на:

OidcConfig.mobileRedirectUrl

То есть:

AuthorizationTokenRequest(
  OidcConfig.clientId,
  OidcConfig.mobileRedirectUrl,
  discoveryUrl: OidcConfig.discoveryUrl,
  scopes: OidcConfig.scopes,
)

И в refresh тоже:

TokenRequest(
  OidcConfig.clientId,
  OidcConfig.mobileRedirectUrl,
  discoveryUrl: OidcConfig.discoveryUrl,
  refreshToken: savedRefreshToken,
  scopes: OidcConfig.scopes,
)
4. Самый простой вариант для web

Если тебе web нужен именно “чтобы открывалось в браузере”, а не обязательно идеально, то самый простой путь — для web сделать отдельную кнопку/экран, который открывает authorization URL.

Нужно добавить зависимости:

dependencies:
  http: ^1.2.2
  crypto: ^3.0.3
  url_launcher: ^6.3.0

Потом:

flutter pub get

Но тут сразу важный момент: для нормального web OAuth нужно хранить code_verifier, обрабатывать code из URL после возврата и обменивать его на токены. Это уже чуть больше кода, чем mobile, потому что flutter_appauth за тебя это делает на Android/iOS, а в web — нет.

Поэтому я бы сделала так:

если тебе для сдачи нужен Android + iOS, то добавляем только Info.plist, и всё;

если реально нужен Flutter Web в Chrome, тогда надо делать отдельный web-auth flow, и я лучше дам тебе готовые файлы: web_auth_service.dart, callback-обработку и правки main.dart.

5. Минимально что надо сделать сейчас

Для iPhone:

в ios/Runner/Info.plist добавь CFBundleURLTypes;

в Authoriza добавь ru.authoriza.demo:/oauth2callback;

проверь, что в коде для mobile используется mobileRedirectUrl.

Для браузера:

в Authoriza добавь web redirect:

http://localhost:3000/callback.html

запускай так:

flutter run -d chrome --web-port 3000

и уже под это нужно делать отдельную web-реализацию, потому что текущий flutter_appauth не закроет web.

Самое безопасное решение по архитектуре: оставить текущий AuthService для Android/iOS, а для браузера сделать отдельный WebAuthService, и в коде выбирать через kIsWeb.

а это все будет в одном проекте?

Да, всё может быть в одном Flutter-проекте.

У тебя один проект:

flutter_application_1

и внутри него лежат платформы:

android/
ios/
web/
lib/

То есть Android, iPhone и браузер — это не три разных проекта, а три платформы одного Flutter-приложения.

Но внутри кода нужно разделить авторизацию:

для Android/iOS используем текущий flutter_appauth;

для Web используем отдельный код, потому что flutter_appauth не работает в браузере.

Обычно это выглядит так:

lib/
  auth/
    auth_service.dart          // общий интерфейс/провайдер
    mobile_auth_service.dart   // Android + iOS через flutter_appauth
    web_auth_service.dart      // браузер через redirect + PKCE
    token_storage.dart
    auth_provider.dart
  config/
    oidc_config.dart
  main.dart

И в коде выбираем платформу:

import 'package:flutter/foundation.dart';

if (kIsWeb) {
  // web auth
} else {
  // mobile auth
}

То есть пользователь запускает:

flutter run -d android

и работает Android-ветка.

Запускает:

flutter run -d chrome --web-port 3000

и работает Web-ветка.

На iPhone:

flutter run -d ios

и работает iOS-ветка.

Но проект всё равно один.

Для iPhone изменения небольшие: добавить CFBundleURLTypes в ios/Runner/Info.plist, и всё. Текущий flutter_appauth должен работать.

Для браузера изменений больше: нужен отдельный web-flow, потому что браузеру нельзя использовать custom scheme:

ru.authoriza.demo:/oauth2callback

Для web нужен redirect вида:

http://localhost:3000/callback.html

или потом настоящий адрес сайта, если будешь деплоить.

Так что ответ: да, один проект, но с разными реализациями авторизации под платформы.

сегодня 15:50
давай сначала для браузера сделаем

Да, давай сначала web. Суть такая: для браузера мы не используем flutter_appauth, а делаем Authorization Code Flow с PKCE вручную: генерируем code_verifier, считаем code_challenge, отправляем браузер в Authoriza, после возврата берём code из адресной строки и меняем его на токены.

Сначала в Authoriza добавь redirect URI для браузера:

http://localhost:3000/

И запускай web именно так:

flutter run -d chrome --web-port 3000

Теперь правки.

В pubspec.yaml добавь зависимости:

http: ^1.2.2
crypto: ^3.0.3

Потом:

flutter pub get

В lib/config/oidc_config.dart добавь web redirect:

class OidcConfig {
  static const String discoveryUrl =
      'https://a-kalinin-authoriza-backend-stand-d37a.twc1.net/oidc/.well-known/openid-configuration';

  static const String clientId =
      '88be8919-1792-42fe-9f17-e9ba64e17507';

  static const String mobileRedirectUrl =
      'ru.authoriza.demo:/oauth2callback';

  static const String webRedirectUrl =
      'http://localhost:3000/';

  static const List<String> scopes = [
    'openid',
    'profile',
    'email',
    'offline_access',
  ];
}

Теперь создай файл:

lib/auth/web_auth_service.dart

И вставь туда:

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

Теперь надо подключить это в auth_provider.dart.

В начало файла добавь:

import 'package:flutter/foundation.dart';

import 'web_auth_service.dart';

В класс AuthProvider добавь поле:

late final WebAuthService _webAuthService;

В конструкторе замени:

AuthProvider(this._authService);

на:

AuthProvider(this._authService) {
  _webAuthService = WebAuthService(_authService.tokenStorage);
}

Но для этого надо в auth_service.dart открыть доступ к tokenStorage.

В auth_service.dart добавь getter внутрь класса AuthService:

TokenStorage get tokenStorage => _tokenStorage;

Теперь в auth_provider.dart в методе login() нужно сделать развилку.

Было:

final tokens = await _authService.login();

Замени на:

final tokens = kIsWeb
    ? await _webAuthService.login().then((_) => null)
    : await _authService.login();

if (tokens == null) {
  return;
}

То есть весь login() должен выглядеть так:

Future<void> login() async {
  _isLoading = true;
  _errorMessage = null;
  notifyListeners();

  try {
    final tokens = kIsWeb
        ? await _webAuthService.login().then((_) => null)
        : await _authService.login();

    if (tokens == null) {
      return;
    }

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

Теперь в checkAuthState() в самом начале try добавь обработку возврата из браузера:

if (kIsWeb) {
  final redirectTokens = await _webAuthService.handleRedirectIfNeeded();

  if (redirectTokens != null) {
    _setTokens(redirectTokens);
    _isAuthenticated = true;
    return;
  }
}

Должно быть примерно так:

try {
  if (kIsWeb) {
    final redirectTokens = await _webAuthService.handleRedirectIfNeeded();

    if (redirectTokens != null) {
      _setTokens(redirectTokens);
      _isAuthenticated = true;
      return;
    }
  }

  final savedTokens = await _authService.getSavedTokens();

В refreshTokens() замени:

final tokens = await _authService.refreshTokens();

на:

final tokens = kIsWeb
    ? await _webAuthService.refreshTokens()
    : await _authService.refreshTokens();

В _refreshTokensSilently() тоже замени:

final tokens = await _authService.refreshTokens();

на:

final tokens = kIsWeb
    ? await _webAuthService.refreshTokens()
    : await _authService.refreshTokens();

В logout() можно оставить _authService.logout(), но лучше для web:

if (kIsWeb) {
  await _webAuthService.logout();
} else {
  await _authService.logout();
}

То есть:

try {
  if (kIsWeb) {
    await _webAuthService.logout();
  } else {
    await _authService.logout();
  }

  _clearState();
}

И в _forceLogout() тоже:

try {
  if (kIsWeb) {
    await _webAuthService.logout();
  } else {
    await _authService.logout();
  }
} catch (error) {
  debugPrint('FORCE LOGOUT STORAGE CLEAR ERROR: $error');
}

Теперь запуск:

flutter clean
flutter pub get
flutter run -d chrome --web-port 3000

Если после ввода логина вернёт ошибку CORS или что-то вроде:

Access to fetch at token endpoint has been blocked by CORS

значит Flutter-код уже нормальный, но сервер Authoriza не разрешает браузеру делать запрос на Token Endpoint. Тогда на стороне Authoriza надо включить CORS для:

http://localhost:3000

или использовать web-клиент/SPA-клиент, где разрешены browser redirect URI.

Самый важный момент: в Authoriza для web должен быть redirect:

http://localhost:3000/

а для Android/iOS остаётся:

ru.authoriza.demo:/oauth2callback
import 'dart:async';
import 'package:flutter/foundation.dart';

import 'package:flutter/material.dart';

import 'auth_service.dart';
import 'user_profile.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService;

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

  AuthProvider(this._authService);

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
      final savedTokens = await _authService.getSavedTokens();

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
        final refreshedTokens = await _authService.refreshTokens();
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
      final tokens = await _authService.refreshTokens();

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
      final tokens = await _authService.refreshTokens();

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
      await _authService.logout();
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
      await _authService.logout();
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
}как тут лучше сделать? перепиши полностю

Да, тут лучше сделать через условный импорт, иначе если ты просто импортируешь web_auth_service.dart, где есть dart:html, Android/iOS могут перестать собираться.

То есть будет так:

для браузера подключится настоящий web_auth_service.dart;

для Android/iOS подключится заглушка web_auth_service_stub.dart;

AuthProvider останется один общий.

Сначала в auth_service.dart внутрь класса AuthService добавь getter:

TokenStorage get tokenStorage => _tokenStorage;

То есть примерно так:

class AuthService {
  final FlutterAppAuth _appAuth = const FlutterAppAuth();
  final TokenStorage _tokenStorage;

  TokenStorage get tokenStorage => _tokenStorage;

  AuthService(this._tokenStorage);

  ...
}

Теперь создай файл:

lib/auth/web_auth_service_stub.dart

И вставь:

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

А теперь твой lib/auth/auth_provider.dart замени полностью на это:

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

Главное отличие от твоего варианта: теперь AuthProvider сам выбирает, чем пользоваться.

На Android/iOS:

_authService.login()
_authService.refreshTokens()
_authService.logout()

На web:

_webAuthService.login()
_webAuthService.handleRedirectIfNeeded()
_webAuthService.refreshTokens()
_webAuthService.logout()

И ещё раз важный момент: без web_auth_service_stub.dart Android/iOS могут ругаться на dart:html, поэтому заглушка обязательна.

делаем заглушку

Да, делаем. Заглушка нужна, чтобы Android/iOS не пытались компилировать файл с dart:html.

Создай файл:

lib/auth/web_auth_service_stub.dart

И вставь туда полностью:

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

Потом в auth_provider.dart импорт должен быть именно такой:

import 'web_auth_service_stub.dart'
    if (dart.library.html) 'web_auth_service.dart';

То есть не надо отдельно писать:

import 'web_auth_service.dart';

Иначе Android/iOS опять увидят dart:html и могут сломаться.

Ещё проверь, что в auth_service.dart у тебя есть getter, потому что AuthProvider будет создавать web-сервис через общий TokenStorage:

TokenStorage get tokenStorage => _tokenStorage;

Он должен быть внутри класса AuthService:

class AuthService {
  final FlutterAppAuth _appAuth = const FlutterAppAuth();
  final TokenStorage _tokenStorage;

  TokenStorage get tokenStorage => _tokenStorage;

  AuthService(this._tokenStorage);

  // остальные методы
}

После этого уже можно делать настоящий файл web_auth_service.dart для браузера.

я могу проверять?

Да, можешь проверять, но сначала проверь, что у тебя уже есть оба файла:

lib/auth/web_auth_service_stub.dart
lib/auth/web_auth_service.dart

И в auth_provider.dart импорт именно такой:

import 'web_auth_service_stub.dart'
    if (dart.library.html) 'web_auth_service.dart';

Потом запусти сначала Android, чтобы убедиться, что заглушка ничего не сломала:

flutter clean
flutter pub get
flutter run

Если Android запускается и вход работает — отлично, условный импорт сделан нормально.

Для браузера запускай так:

flutter run -d chrome --web-port 3000

И в Authoriza должен быть добавлен redirect URI:

http://localhost:3000/

Если в браузере после входа вернёт на приложение и покажет токены/профиль — всё ок. Если будет ошибка CORS на Token Endpoint, это уже не ошибка Flutter-кода, а настройка Authoriza: нужно разрешить origin http://localhost:3000 для браузерного клиента.

er run                          
Launching lib\main.dart on SM A515F
in debug mode...
Running Gradle task 'assembleDebug'.
lib/auth/auth_provider.dart:32:51: Error: The getter 'tokenStorage' isn't defined for the type 'AuthService'.
Running Gradle task 'assembleDebug'.
 - 'AuthService' is from 'package:flutter_application_1/auth/auth_service.dart' ('lib/auth/auth_service.dart').
Running Gradle task 'assembleDebug'.
Try correcting the name to the name of an existing getter, or defining a getter or field named 'tokenStorage'.
Running Gradle task 'assembleDebug'.
    _webAuthService = WebAuthService(_authService.tokenStorage);
Running Gradle task 'assembleDebug'.
                          ^^^^^^^^^^^^
Running Gradle task 'assembleDebug'.
lib/auth/auth_service.dart:52:20: Error: Member not found: 'redirectUrl'.
Running Gradle task 'assembleDebug'.
        OidcConfig.redirectUrl,
Running Gradle task 'assembleDebug'.
                   ^^^^^^^^^^^
Running Gradle task 'assembleDebug'.
lib/auth/auth_service.dart:95:20: Error: Member not found: 'redirectUrl'.
Running Gradle task 'assembleDebug'.
        OidcConfig.redirectUrl,
Running Gradle task 'assembleDebug'.
                   ^^^^^^^^^^^
Running Gradle task 'assembleDebug'.
Target kernel_snapshot_program failed: Exception
Running Gradle task 'assembleDebug'.

Running Gradle task 'assembleDebug'.

Running Gradle task 'assembleDebug'.
FAILURE: Build failed with an exception.
Running Gradle task 'assembleDebug'.

Running Gradle task 'assembleDebug'.
* What went wrong:
Running Gradle task 'assembleDebug'.
Execution failed for task ':app:compileFlutterBuildDebug'.
Running Gradle task 'assembleDebug'.
> Process 'command 'C:\Users\REDMI\flutter\bin\flutter.bat'' finished with non-zero exit value 1
Running Gradle task 'assembleDebug'.

Running Gradle task 'assembleDebug'.
* Try:
Running Gradle task 'assembleDebug'.
> Run with --stacktrace option to get the stack trace.
Running Gradle task 'assembleDebug'.
> Run with --info or --debug option to get more log output.
Running Gradle task 'assembleDebug'.
> Run with --scan to generate a Build Scan (Powered by Develocity).
Running Gradle task 'assembleDebug'.
> Get more help at https://help.gradle.org.
Running Gradle task 'assembleDebug'.

Running Gradle task 'assembleDebug'.
BUILD FAILED in 22s
Running Gradle task 'assembleDebug'...                            22,7s|
Error: Gradle task assembleDebug
failed with exit code 1

Тут две простые ошибки из-за переименований.

Первая: в AuthProvider мы написали:

_authService.tokenStorage

но в AuthService ещё нет такого getter.

Вторая: в OidcConfig мы, скорее всего, переименовали redirectUrl в mobileRedirectUrl, а в auth_service.dart всё ещё используется старое имя OidcConfig.redirectUrl.

Исправляем так.

Открой файл:

lib/auth/auth_service.dart

Внутри класса AuthService найди начало:

class AuthService {
  final FlutterAppAuth _appAuth = const FlutterAppAuth();
  final TokenStorage _tokenStorage;

  AuthService(this._tokenStorage);

Замени на:

class AuthService {
  final FlutterAppAuth _appAuth = const FlutterAppAuth();
  final TokenStorage _tokenStorage;

  TokenStorage get tokenStorage => _tokenStorage;

  AuthService(this._tokenStorage);

То есть мы добавили:

TokenStorage get tokenStorage => _tokenStorage;

Теперь в этом же файле найди оба места:

OidcConfig.redirectUrl

И замени на:

OidcConfig.mobileRedirectUrl

У тебя должно получиться вот так в login():

final result = await _appAuth.authorizeAndExchangeCode(
  AuthorizationTokenRequest(
    OidcConfig.clientId,
    OidcConfig.mobileRedirectUrl,
    discoveryUrl: OidcConfig.discoveryUrl,
    scopes: OidcConfig.scopes,
  ),
);

И вот так в refreshTokens():

final result = await _appAuth.token(
  TokenRequest(
    OidcConfig.clientId,
    OidcConfig.mobileRedirectUrl,
    discoveryUrl: OidcConfig.discoveryUrl,
    refreshToken: savedRefreshToken,
    scopes: OidcConfig.scopes,
  ),
);

Проверь, что в lib/config/oidc_config.dart у тебя есть именно это поле:

static const String mobileRedirectUrl =
    'ru.authoriza.demo:/oauth2callback';

А не только старое:

static const String redirectUrl =
    'ru.authoriza.demo:/oauth2callback';

После правок запусти:

flutter clean
flutter pub get
flutter run

Если хочешь самый быстрый фикс без переименований, можно наоборот в oidc_config.dart добавить алиас:

static const String redirectUrl = mobileRedirectUrl;

Но аккуратнее всё-таки заменить в auth_service.dart на mobileRedirectUrl, чтобы было понятно: это redirect именно для Android/iOS.

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

  TokenStorage get tokenStorage => _tokenStorage;

  AuthService(this._tokenStorage);  final FlutterAppAuth _appAuth = const FlutterAppAuth();
  final TokenStorage _tokenStorage;

  AuthService(this._tokenStorage);

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

    await _tokenStorage.saveTokens(
      accessToken: result.accessToken!,
      refreshToken: result.refreshToken,
      idToken: result.idToken,
      accessTokenExpiration: result.accessTokenExpirationDateTime,
      tokenType: result.tokenType,
      scopes: result.scopes ?? OidcConfig.scopes,
      lastTokenRefreshTime: now,
    );

    return AuthTokens(
      accessToken: result.accessToken,
      idToken: result.idToken,
      refreshToken: result.refreshToken,
      accessTokenExpiration: result.accessTokenExpirationDateTime,
      tokenType: result.tokenType,
      scopes: result.scopes ?? OidcConfig.scopes,
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

    await _tokenStorage.saveTokens(
      accessToken: result.accessToken!,
      refreshToken: newRefreshToken,
      idToken: result.idToken,
      accessTokenExpiration: result.accessTokenExpirationDateTime,
      tokenType: result.tokenType,
      scopes: result.scopes ?? OidcConfig.scopes,
      lastTokenRefreshTime: now,
    );

    return AuthTokens(
      accessToken: result.accessToken,
      idToken: result.idToken,
      refreshToken: newRefreshToken,
      accessTokenExpiration: result.accessTokenExpirationDateTime,
      tokenType: result.tokenType,
      scopes: result.scopes ?? OidcConfig.scopes,
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
}исправь все полностью\

Да, у тебя просто случайно продублировался кусок класса AuthService. Нужно заменить файл целиком, чтобы не осталось второй пары _appAuth, _tokenStorage и второго конструктора.

Замени весь файл:

lib/auth/auth_service.dart

на это:

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

Потом проверь lib/config/oidc_config.dart. Там обязательно должно быть поле:

static const String mobileRedirectUrl =
    'ru.authoriza.demo:/oauth2callback';

Если у тебя там сейчас только redirectUrl, либо переименуй его в mobileRedirectUrl, либо добавь алиас:

static const String mobileRedirectUrl =
    'ru.authoriza.demo:/oauth2callback';

static const String redirectUrl = mobileRedirectUrl;

После этого запускай:

flutter clean
flutter pub get
flutter run
а тут

Это значит, что ты в web_auth_service.dart импортировала пакет http, но он не добавлен в pubspec.yaml.

Открой:

pubspec.yaml

В блок dependencies: добавь:

http: ^1.2.2
crypto: ^3.0.3

Должно быть примерно так:

dependencies:
  flutter:
    sdk: flutter

  flutter_appauth: ^9.0.1
  flutter_secure_storage: ^9.2.2
  provider: ^6.1.2
  http: ^1.2.2
  crypto: ^3.0.3

Потом в терминале выполни:

flutter pub get

Если после этого http всё ещё красный, перезапусти анализатор в VS Code: Ctrl + Shift + P → Dart: Restart Analysis Server.

http нужен для web-версии, потому что в браузере мы сами делаем запросы к Discovery Endpoint и Token Endpoint. crypto нужен для PKCE, чтобы посчитать code_challenge.

сегодня 23:04
почему одно и тоже приложение в телефоне и на компе по разному показывает expires in на телефоне 400 с чем то, а в хроме 3600

Это нормально может быть по двум причинам.

Первая и самая вероятная: на телефоне у тебя показывается сколько осталось до истечения уже полученного access token, а в Chrome ты видишь свежий expires_in из ответа Token Endpoint.

То есть 3600 — это “токен выдан на 3600 секунд”, примерно 1 час.

А 400 с чем-то на телефоне — это “до конца жизни текущего сохранённого токена осталось 400 секунд”. Если ты вошла на телефоне давно, закрывала приложение, открывала снова, то оно восстановило старый токен из flutter_secure_storage, и там уже осталось не 3600, а 400 секунд.

У тебя в коде expiresIn считается вот так:

final seconds = expiration.difference(DateTime.now()).inSeconds;

То есть это не исходное expires_in из ответа сервера, а оставшееся время на текущий момент.

Вторая причина: телефон и Chrome могут использовать разные flow/redirect/client-настройки. Например:

Android/iOS идут через:

OidcConfig.mobileRedirectUrl

а Web через:

OidcConfig.webRedirectUrl

Если в Authoriza для mobile и web фактически разные клиенты или разные настройки токенов, сервер может выдавать разное время жизни access token. Но если client_id один и тот же, чаще всего причина всё-таки в том, что на телефоне токен старый.

Как проверить быстро:

На телефоне нажми logout, потом войди заново. Сразу после входа expires_in должен быть около:

3600

или чуть меньше, например 3590.

Если после нового входа на телефоне всё равно около 400, значит сервер реально выдаёт mobile-токен с коротким временем жизни.

Для нормального отображения я бы разделила два поля:

expires_in из Token Endpoint: 3600
осталось до истечения Access Token: 423

Сейчас у тебя одно поле называется Expires in, но по факту показывает “осталось секунд”. Поэтому оно и выглядит странно.

Если хочешь оставить просто и понятно, переименуй на экране:

Text('Осталось до истечения Access Token: ${auth.expiresIn?.toString() ?? 'Нет данных'} секунд'),

А не:

Text('Expires in: ${auth.expiresIn?.toString() ?? 'Нет данных'}'),

Так будет честнее: 400 — это не ошибка, это оставшееся время.

нет, они однозначно разные по времени

Да, тогда это уже не “старый токен”, а реально сервер выдаёт разные lifetime для разных платформ/flow или ты их по-разному считаешь.

Самое важное: expires_in из Token Endpoint и exp внутри JWT — это не одно и то же отображение, но они должны примерно совпадать по смыслу.

Нужно проверить не поле на экране, а сам payload токена:

В Access Token payload найди поля:

"iat": ...
"exp": ...

iat — когда токен выдан.
exp — когда токен истекает.
Разница exp - iat покажет реальную жизнь токена в секундах.

Если на телефоне:

exp - iat ≈ 600

а в Chrome:

exp - iat ≈ 3600

значит Authoriza реально выдаёт mobile-токен на 10 минут, а web-токен на 1 час.

Почему так может быть:

У тебя для телефона и браузера разные redirect URI:

mobileRedirectUrl = 'ru.authoriza.demo:/oauth2callback'
webRedirectUrl = 'http://localhost:3000/'

Сервер может по redirect/client type/platform policy выдавать разное время жизни токена. Особенно если один flow идёт как mobile/native, а второй как SPA/web.

Ещё может быть так, что web-код берёт expires_in прямо из ответа Token Endpoint, а Android-код берёт:

result.accessTokenExpirationDateTime

из flutter_appauth. Это значение AppAuth сам собирает на основе ответа сервера. Поэтому для проверки лучше выводить ещё и lifetime из JWT.

Добавь в JwtBlock или отдельный блок такую функцию:

int? getJwtLifetimeSeconds(String? token) {
  if (token == null || token.isEmpty) {
    return null;
  }

  final parts = token.split('.');

  if (parts.length != 3) {
    return null;
  }

  try {
    final normalized = base64Url.normalize(parts[1]);
    final decodedBytes = base64Url.decode(normalized);
    final decodedString = utf8.decode(decodedBytes);
    final decodedJson = jsonDecode(decodedString);

    if (decodedJson is! Map<String, dynamic>) {
      return null;
    }

    final exp = int.tryParse(decodedJson['exp']?.toString() ?? '');
    final iat = int.tryParse(decodedJson['iat']?.toString() ?? '');

    if (exp == null || iat == null) {
      return null;
    }

    return exp - iat;
  } catch (_) {
    return null;
  }
}

И на экран рядом со статусом добавь:

Text(
  'JWT lifetime Access Token: '
  '${getJwtLifetimeSeconds(auth.accessToken)?.toString() ?? 'Нет данных'} секунд',
),

Если эта строка на телефоне показывает примерно 600, а в Chrome 3600, то всё: это не баг Flutter. Это разные настройки выдачи токенов на стороне Authoriza.

Тогда у тебя два варианта.

Первый — принять как есть. Это нормально: приложение не обязано получать одинаковый lifetime на разных платформах. Главное, что автообновление работает за 5 минут до истечения.

Второй — попросить/настроить в Authoriza одинаковый lifetime access token для mobile и web-клиента. Особенно проверь, не создано ли фактически два разных приложения/клиента или разные политики для ru.authoriza.demo:/oauth2callback и http://localhost:3000/.

И ещё момент: если access token на телефоне живёт около 600 секунд, а автообновление стоит за 5 минут до истечения, то оно будет обновляться примерно через 5 минут после выдачи:

600 секунд - 300 секунд = 300 секунд

То есть при коротком lifetime таймер будет срабатывать довольно часто. Это нормально, но можно для теста поставить запас не 5 минут, а 1 минуту, если токены короткие. Но по требованиям у тебя написано “рекомендуемый запас не менее 5 минут”, так что лучше оставить 5 минут.

Я бы сейчас сделала так: сравни именно exp - iat в payload на телефоне и в Chrome. Это докажет, что времена реально разные со стороны сервера, а не из-за нашего расчёта expiresIn.

refresh и хранение работает в вебе, ну и для айфона делаем

Да, если web уже работает, для iPhone проще: там не надо отдельный web_auth_service. iOS будет идти через тот же мобильный AuthService, что и Android, то есть через flutter_appauth.

Нужно сделать 3 вещи: добавить redirect в Authoriza, прописать URL scheme в Info.plist, и проверить, что в коде используется mobileRedirectUrl.

Открой:

ios/Runner/Info.plist

И перед самым закрытием файла, перед:

</dict>
</plist>

добавь вот это:

<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLName</key>
        <string>ru.authoriza.demo</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>ru.authoriza.demo</string>
        </array>
    </dict>
</array>

То есть конец Info.plist должен выглядеть примерно так:

    <key>UIApplicationSupportsIndirectInputEvents</key>
    <true/>

    <key>CFBundleURLTypes</key>
    <array>
        <dict>
            <key>CFBundleURLName</key>
            <string>ru.authoriza.demo</string>
            <key>CFBundleURLSchemes</key>
            <array>
                <string>ru.authoriza.demo</string>
            </array>
        </dict>
    </array>
</dict>
</plist>

В Authoriza для этого же клиента должен быть добавлен redirect:

ru.authoriza.demo:/oauth2callback

Если у тебя уже был этот redirect для Android, то отдельно для iOS добавлять ничего нового не надо, потому что iOS использует тот же custom scheme.

Теперь проверь lib/config/oidc_config.dart. Там должно быть так:

class OidcConfig {
  static const String discoveryUrl =
      'https://a-kalinin-authoriza-backend-stand-d37a.twc1.net/oidc/.well-known/openid-configuration';

  static const String clientId =
      '88be8919-1792-42fe-9f17-e9ba64e17507';

  static const String mobileRedirectUrl =
      'ru.authoriza.demo:/oauth2callback';

  static const String webRedirectUrl =
      'http://localhost:3000/';

  static const List<String> scopes = [
    'openid',
    'profile',
    'email',
    'offline_access',
  ];
}

И в auth_service.dart для мобильной авторизации должно быть именно:

AuthorizationTokenRequest(
  OidcConfig.clientId,
  OidcConfig.mobileRedirectUrl,
  discoveryUrl: OidcConfig.discoveryUrl,
  scopes: OidcConfig.scopes,
)

А для refresh:

TokenRequest(
  OidcConfig.clientId,
  OidcConfig.mobileRedirectUrl,
  discoveryUrl: OidcConfig.discoveryUrl,
  refreshToken: savedRefreshToken,
  scopes: OidcConfig.scopes,
)

Для iOS больше отдельного кода не нужно. Твой AuthProvider уже делает так:

if (kIsWeb) {
  // web auth
} else {
  // mobile auth через flutter_appauth
}

iPhone попадает в else, как Android.

Если будешь запускать на Mac с iPhone/симулятором:

flutter clean
flutter pub get
cd ios
pod install
cd ..
flutter run -d ios

Или если устройство видно Flutter:

flutter devices
flutter run -d <id_iphone>

На Windows iOS собрать и проверить нельзя, нужен macOS с Xcode. Но сами правки для iOS — это в основном Info.plist, потому что вся логика уже общая с Android.

Проверка на iPhone такая же: нажимаешь «Войти», открывается Authoriza, после логина должно вернуться в приложение по ru.authoriza.demo:/oauth2callback, показать профиль/токены, refresh и хранение должны работать через тот же TokenStorage и AuthProvider.

можно же с codemagic скомпилировать для айос

Да, можно. Codemagic как раз позволяет собрать iOS из Flutter-проекта без Mac: он запускает сборку на macOS-машине в облаке. По их документации, при automatic code signing Codemagic может создать сертификат и provisioning profile за тебя без Mac, но для подписанной сборки всё равно нужен доступ к Apple Developer/App Store Connect.

Но есть важное разделение:

Для просто проверить, что iOS вообще собирается, можно сделать unsigned/simulator build. Такой .app нельзя нормально поставить на реальный iPhone как обычное приложение, но можно проверить компиляцию iOS-части.

Для установить на реальный iPhone/TestFlight/App Store нужен Apple Developer Program, подпись, provisioning profile и bundle id. Codemagic поддерживает iOS code signing и App Store Connect integration.

Для твоего проекта сначала я бы сделала именно проверочную iOS-сборку, чтобы убедиться, что Info.plist, flutter_appauth, flutter_secure_storage, условные импорты web/mobile и всё остальное не ломают iOS.

Минимально что надо до Codemagic:

В ios/Runner/Info.plist должен быть URL scheme:

<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLName</key>
        <string>ru.authoriza.demo</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>ru.authoriza.demo</string>
        </array>
    </dict>
</array>

В Authoriza должен быть redirect:

ru.authoriza.demo:/oauth2callback

А в oidc_config.dart для мобильной ветки:

static const String mobileRedirectUrl =
    'ru.authoriza.demo:/oauth2callback';

Дальше можно добавить в корень проекта файл codemagic.yaml для проверки сборки:

workflows:
  ios-debug-build:
    name: iOS Debug Build
    max_build_duration: 60
    instance_type: mac_mini_m2

    environment:
      flutter: stable
      xcode: latest
      cocoapods: default

    scripts:
      - name: Get Flutter packages
        script: |
          flutter pub get

      - name: Install CocoaPods
        script: |
          cd ios
          pod install
          cd ..

      - name: Build iOS without code signing
        script: |
          flutter build ios --debug --no-codesign

    artifacts:
      - build/ios/iphoneos/Runner.app
      - build/ios/iphoneos/*.app
      - /tmp/xcodebuild_logs/*.log

Потом пушишь это в GitHub, заходишь в Codemagic, подключаешь репозиторий, выбираешь workflow ios-debug-build и запускаешь. Если сборка зелёная — iOS-часть проекта компилируется.

Если хочешь именно .ipa для установки на iPhone, тогда нужен подписанный workflow. Для этого в Codemagic надо подключить App Store Connect API key или сертификаты/provisioning profile. Codemagic умеет генерировать signing certificate и provisioning profile через App Store Connect API key.

Для установки на реальный iPhone без TestFlight обычно нужен development/ad hoc provisioning profile с UDID устройства. Через TestFlight проще, но для него тоже нужен Apple Developer Program.

То есть ответ: да, можно через Codemagic, и это нормальный путь с Windows. На первом шаге я бы собрала --no-codesign, чтобы поймать ошибки кода. Потом уже занималась подписью.

Дальше можно добавить в корень проекта файл codemagic.yaml для проверки сборки:

это куда

Да, после декомпозиции код уже выглядит намного читабельнее, особенно если ты реально разложила так:

auth/
  auth_provider.dart
  auth_session_manager.dart
  auth_service.dart
  web_auth_service.dart
  web_auth_service_stub.dart
  token_storage.dart

models/
  auth_tokens.dart
  auth_state.dart
  user_profile.dart

widgets/
  status_block.dart
  profile_block.dart
  masked_token_block.dart
  jwt_payload_block.dart

utils/
  jwt_utils.dart
  token_masker.dart
  date_time_utils.dart

screens/
  login_screen.dart
  home_screen.dart

app/
  app.dart
  auth_gate.dart

Это уже не спагетти. Для учебного проекта это нормальная, понятная структура: сервисы отдельно, состояние отдельно, модели отдельно, UI отдельно. Прям “идеальная чистая архитектура” не нужна, иначе проект станет сложнее самого задания.

По ТЗ, если не учитывать UserInfo, у тебя картина такая.

Authorization Code Flow with PKCE — выполнено.
На Android/iOS используется flutter_appauth, он как раз делает Authorization Code Flow с PKCE. Для web ты вручную делаешь code_verifier, code_challenge, state, редирект и обмен кода на токены. Это тоже подходит.

Настройка подключения — выполнено, но надо README.
В коде есть OidcConfig: clientId, discoveryUrl, redirect URI, scopes. Redirect URI настроены: mobile ru.authoriza.demo:/oauth2callback, web http://localhost:3000/. Но по ТЗ прямо написано “документирует весь процесс”, значит README обязателен. Без README формально пункт слабый.

Discovery — выполнено.
Mobile использует:

discoveryUrl: OidcConfig.discoveryUrl

Web тоже получает authorization_endpoint и token_endpoint из discovery. Это хорошо. Главное — не добавляй руками отдельные URL типа authorizationEndpoint, tokenEndpoint в конфиг.

Аутентификация пользователя — выполнено.
После кнопки входа идёт редирект в Authoriza, выполняется flow, токены приходят через Token Endpoint, потом сохраняются в TokenStorage.

Отображение ответа Token Endpoint — почти выполнено.
У тебя отображаются access_token, id_token, refresh_token, token_type, scope, время истечения. Но важный момент: expires_in у тебя сейчас, кажется, отображается как “сколько секунд осталось до истечения access token”, а не как оригинальное поле expires_in, которое пришло от Token Endpoint.

Для задания это обычно нормально, потому что по смыслу ты показываешь срок жизни токена. Но если хочешь прям идеально по ТЗ, можно в AuthTokens добавить отдельное поле:

final int? expiresIn;

и сохранять туда result.accessTokenExpirationDateTime.difference(now).inSeconds при получении токенов. Но я бы не усложняла, если в UI уже есть “Осталось до истечения Access Token”.

Отображение содержимого JWT — выполнено.
Есть декодированный payload для ID Token и Access Token. Это прям по ТЗ.

Хранение данных аутентификации — выполнено.
Сохраняются Access Token, Refresh Token, ID Token, время истечения access token. После перезапуска идёт checkAuthState() и попытка восстановить сессию. Это закрыто.

Обновление токенов — выполнено хорошо.
Ручная кнопка есть. После refresh токены сохраняются заново, UI обновляется. Автообновление есть при запуске и по таймеру за 5 минут до истечения access token. Это сильный пункт.

Единственное: по ТЗ после обновления надо “повторно получить UserInfo”, но ты сказала проверяем без UserInfo. Тогда этот подпункт пропускаем.

Выход пользователя — выполнено.
Logout чистит сохранённые токены, состояние, профиль, таймер, возвращает на экран входа. Интерфейс очищается.

Отображение состояния — выполнено.
Есть статус авторизации, время истечения Access Token, время последнего обновления токенов. Refresh Token expiration у тебя “недоступно”, и это нормально, если Authoriza не отдаёт отдельное время истечения refresh token. В README можно так и написать: “время истечения Refresh Token не отображается, так как Token Endpoint не возвращает это значение”.

Секреты — нормально, если нет client_secret.
clientId в репозитории — это нормально для public client. А вот client_secret быть не должно вообще. Проверь поиском по проекту:

Select-String -Path .\lib\**\* -Pattern "client_secret","secret","password" -Recurse

И отдельно можно просто в VS Code поискать:

client_secret
secret
password

Культура кода — после декомпозиции нормально.
Я бы оценила как читабельно. Особенно если main.dart маленький, UI вынесен в widgets, JWT-декодирование в utils, а web/mobile-развилка в AuthSessionManager.

Что я бы ещё поправила перед сдачей:

Убери из UserProfile поле preferredUsername, если ты уже не показываешь логин и не хочешь лишнего. Не обязательно, но чище.

Переименуй в UI Expires in в “Осталось до истечения Access Token”, потому что это не оригинальный expires_in, а вычисленное оставшееся время.

Убедись, что в логах нет полного токена. Такие строки нельзя оставлять:

debugPrint(accessToken);
debugPrint(idToken);
debugPrint(refreshToken);

Авто-refresh логи можно оставить, они безопасные.

И самое главное — README. Сейчас по ТЗ именно документация может быть самым слабым местом. Туда надо добавить разделы: создание приложения в Authoriza, redirect URI, scopes, Discovery, запуск Android, запуск Web, iOS через Codemagic, хранение, refresh, logout, UserInfo не используется/исключён по согласованию.

Итог: без UserInfo у тебя ТЗ закрыто примерно на 85–90%. Главные недостающие вещи перед сдачей: README, проверка отсутствия секретов, и мелкая чистка формулировок в UI.

а мы же вылетаем из сессии и просим снова залогиниться если refresh token заканчивается

Да, именно так: если refresh token больше не работает, приложение выкидывает пользователя из сессии и просит войти заново.

У нас это закрыто не через “мы заранее знаем срок refresh token”, а через попытку обновления. Потому что refresh token обычно не всегда содержит понятное время истечения, и Token Endpoint может просто вернуть ошибку, когда он протух, отозван или стал невалидным.

У тебя это происходит здесь:

В AuthService.refreshTokens():

final result = await _appAuth.token(
  TokenRequest(
    OidcConfig.clientId,
    OidcConfig.mobileRedirectUrl,
    discoveryUrl: OidcConfig.discoveryUrl,
    refreshToken: savedRefreshToken,
    scopes: OidcConfig.scopes,
  ),
);

Если refresh token умер, этот вызов упадёт с ошибкой. Дальше ошибка ловится в AuthProvider.

Для ручного обновления:

catch (error, stackTrace) {
  debugPrint('AUTH ERROR: $error');
  debugPrint('AUTH STACKTRACE: $stackTrace');

  await _logoutSilently();

  _errorMessage = 'Сессия истекла. Войдите заново.';
}

Для автообновления:

catch (error, stackTrace) {
  debugPrint('AUTO REFRESH ERROR: $error');
  debugPrint('AUTO REFRESH STACKTRACE: $stackTrace');

  await _logoutSilently();
  _errorMessage = 'Сессия истекла. Войдите заново.';
  notifyListeners();
}

А _logoutSilently() чистит сохранённые токены и состояние:

await _sessionManager.logout();
_clearState();

То есть логика такая:

access token истёк или скоро истечёт → приложение пробует refresh token → если refresh token валиден, получает новые токены → если refresh token невалиден/истёк, очищает всё и возвращает на экран входа.

В README можно написать так:

Если Access Token истёк или скоро истечёт, приложение пытается обновить токены через Refresh Token. Если Refresh Token отсутствует, истёк или Token Endpoint возвращает ошибку при обновлении, сохранённые токены удаляются, состояние авторизации очищается, пользователь возвращается на экран входа и должен пройти авторизацию заново.

Это нормально по ТЗ. Отдельное “время истечения Refresh Token” отображается как недоступное, потому что сервер не отдаёт это значение явно.

надо readme написать как тут 
authoriza-core/authoriza-spring-demo.git

Да, поняла. У них README прям как отчёт по ТЗ: назначение, стек, настройка Авторизы, Discovery, запуск, сценарии проверки, структура проекта, безопасность. Я открыла их README — там именно такой формат: описание проекта, таблица технологий, настройка клиента, Discovery, хранение, refresh, logout, проверки и статус реализации.

Тебе можно сделать почти такой же, но под Flutter. Замени свой README.md полностью вот этим:

# Authoriza Flutter OIDC Client

**Демонстрационный проект интеграции Авторизы для Flutter**

Проект представляет собой Flutter-приложение, демонстрирующее интеграцию с сервисом Авториза по протоколу OpenID Connect.

Приложение реализует OpenID Connect Authorization Code Flow with PKCE, получение токенов через Token Endpoint, отображение ответа Token Endpoint, декодирование JWT payload, сохранение сессии, восстановление авторизации после перезапуска, ручное и автоматическое обновление токенов, а также выход с очисткой сохранённых данных.

## Назначение проекта

Данный проект является примером интеграции Авторизы для Flutter-приложения.

Он демонстрирует:

- реализацию OpenID Connect Authorization Code Flow with PKCE;
- использование Discovery Endpoint для получения OIDC-конфигурации;
- перенаправление пользователя в Авторизу после нажатия кнопки входа;
- получение Access Token, ID Token и Refresh Token;
- сохранение результатов аутентификации;
- восстановление сессии после перезапуска приложения;
- ручное обновление токенов через Refresh Token;
- автоматическое обновление Access Token до истечения срока действия;
- обработку ситуации, когда Refresh Token отсутствует, истёк или больше не принимается провайдером;
- отображение маскированных токенов;
- отображение decoded payload для Access Token и ID Token;
- logout с очисткой сохранённой сессии.

## Стек технологий

| Компонент | Инструмент |
| --- | --- |
| Язык | Dart |
| Фреймворк | Flutter |
| OIDC-клиент для Android/iOS | flutter_appauth |
| Web OIDC | Authorization Code Flow with PKCE |
| Хранение токенов | flutter_secure_storage |
| Управление состоянием | provider |
| HTTP-запросы для web-flow | http |
| PKCE code challenge для web | crypto |
| iOS CI build | Codemagic |

Основные библиотеки:

```yaml
flutter_appauth
flutter_secure_storage
provider
http
crypto
Требования к окружению

Перед запуском необходимо установить:

Flutter SDK;
Dart SDK;
Android Studio или другой редактор;
Android SDK;
браузер Chrome для запуска web-версии;
физическое Android-устройство или Android Emulator;
доступ к приложению, зарегистрированному в Авторизе.

Проверить Flutter можно командой:

flutter doctor

Установить зависимости:

flutter pub get
Настройка приложения в Авторизе

Для работы приложения необходимо создать OIDC-приложение в Авторизе и настроить параметры клиента.

Основные параметры
Параметр	Значение
Flow	Authorization Code Flow
PKCE	Включён
Client type	Public client
Client authentication method	none
Mobile Redirect URI	ru.authoriza.demo:/oauth2callback
Web Redirect URI	http://localhost:3000/
Scopes

В приложении используются следующие scopes:

openid profile email offline_access

Scope offline_access нужен для получения Refresh Token.

Discovery

Приложение использует Discovery Endpoint.

OIDC endpoint-ы не прописываются вручную в коде. Приложение получает конфигурацию через Discovery.

Discovery URL:

https://a-kalinin-authoriza-backend-stand-d37a.twc1.net/oidc/.well-known/openid-configuration

Конфигурация находится в файле:

lib/config/oidc_config.dart

Пример конфигурации:

class OidcConfig {
  static const String discoveryUrl =
      'https://a-kalinin-authoriza-backend-stand-d37a.twc1.net/oidc/.well-known/openid-configuration';

  static const String clientId =
      '88be8919-1792-42fe-9f17-e9ba64e17507';

  static const String mobileRedirectUrl =
      'ru.authoriza.demo:/oauth2callback';

  static const String webRedirectUrl =
      'http://localhost:3000/';

  static const List<String> scopes = [
    'openid',
    'profile',
    'email',
    'offline_access',
  ];
}

Для Android и iOS используется flutter_appauth, который получает endpoint-ы через discoveryUrl.

Для web-версии приложение самостоятельно загружает Discovery-документ и берёт из него:

authorization_endpoint
token_endpoint
Redirect URI
Android

Для Android настроен custom scheme redirect:

ru.authoriza.demo:/oauth2callback

В android/app/src/main/AndroidManifest.xml добавлен intent-filter для обработки redirect URI.

iOS

Для iOS redirect scheme добавлен в:

ios/Runner/Info.plist

Используется схема:

ru.authoriza.demo
Web

Для web-версии используется redirect URI:

http://localhost:3000/

Запуск web-версии должен выполняться на порту 3000.

Запуск проекта
Android

Запуск на Android-устройстве или эмуляторе:

flutter run
Web

Запуск web-версии:

flutter run -d chrome --web-port 3000

После запуска пользователь нажимает кнопку входа, приложение перенаправляет его в Авторизу, после успешной авторизации получает authorization code и обменивает его на токены через Token Endpoint.

iOS

iOS-сборка проверяется через Codemagic.

Файл конфигурации находится в корне проекта:

codemagic.yaml

Workflow выполняет сборку iOS без подписи:

flutter build ios --debug --no-codesign

Такая сборка подтверждает, что проект компилируется под iOS. Для установки на реальный iPhone требуется Apple Developer signing и сборка подписанного .ipa.

Основные экраны приложения
Экран входа

На экране входа отображается кнопка авторизации.

После нажатия кнопки приложение:

формирует Authorization Request;
использует Authorization Code Flow with PKCE;
перенаправляет пользователя в Авторизу;
получает authorization code;
обменивает code на токены через Token Endpoint;
сохраняет полученные данные;
открывает экран профиля и токенов.
Экран профиля и токенов

После успешной авторизации отображаются:

статус авторизации;
token_type;
scope;
время истечения Access Token;
время истечения Refresh Token, если доступно;
время последнего обновления токенов;
данные пользователя из ID Token;
маскированный Access Token;
маскированный ID Token;
маскированный Refresh Token;
decoded payload Access Token;
decoded payload ID Token.

Полные значения токенов на экран не выводятся. Токены отображаются в маскированном виде.

Отображение ответа Token Endpoint

После входа приложение отображает данные, полученные от Token Endpoint:

Поле	Статус
access_token	отображается в маскированном виде
id_token	отображается в маскированном виде
refresh_token	отображается в маскированном виде, если выдан
expires_in	отображается как оставшееся время до истечения Access Token
token_type	отображается
scope	отображается
Отображение содержимого JWT

Приложение декодирует JWT и отображает payload.

Для ID Token отображается:

ID Token payload

Для Access Token отображается:

Access Token payload

Декодирование выполняется локально на клиенте. Подпись токена в приложении не проверяется, так как задача приложения — отобразить содержимое полученных JWT.

UserInfo

В текущей реализации UserInfo Endpoint не используется.

Данные пользователя отображаются из payload ID Token.

Если необходимо полностью закрыть пункт UserInfo из технического задания, нужно добавить отдельный запрос к userinfo_endpoint после успешного входа и после refresh token. В текущей версии этот пункт исключён из реализации по согласованию.

Хранение сессии

Для хранения данных аутентификации используется flutter_secure_storage.

Сохраняются:

Access Token;
Refresh Token;
ID Token;
время истечения Access Token;
token_type;
scope;
время последнего обновления токенов.

После закрытия и повторного запуска приложение выполняет попытку восстановления сессии.

Если Access Token ещё действителен, пользователь остаётся авторизованным.

Если Access Token истёк или скоро истечёт, приложение пытается обновить токены через Refresh Token.

Если Refresh Token отсутствует, истёк или Token Endpoint возвращает ошибку, сохранённые токены удаляются, состояние авторизации очищается, пользователь возвращается на экран входа.

Обновление токенов
Ручное обновление

На экране профиля доступна кнопка:

Обновить токены через refresh token

После нажатия приложение:

берёт сохранённый Refresh Token;
выполняет запрос к Token Endpoint;
получает новые токены;
обновляет сохранённые данные;
обновляет отображаемую информацию на экране.
Автоматическое обновление

Автоматическое обновление выполняется:

при запуске приложения;
по таймеру до истечения срока действия Access Token.

Запас времени до истечения Access Token:

5 минут

Если обновление прошло успешно, новые токены сохраняются, а интерфейс обновляется.

Если обновление завершилось ошибкой, приложение очищает сохранённые данные и переводит пользователя в состояние до авторизации.

Выход из приложения

При выходе приложение:

удаляет сохранённые токены;
удаляет сохранённые пользовательские данные;
очищает состояние авторизации;
очищает таймер автоматического обновления;
возвращает пользователя на экран входа.
Проверка основных сценариев
1. Вход через Авторизу
Запустить приложение.
Нажать кнопку входа.
Выполнить авторизацию в Авторизе.
Убедиться, что после входа открыт экран профиля и токенов.

Ожидаемый результат:

пользователь авторизован;
получены Access Token, ID Token и Refresh Token;
данные сохранены;
токены отображаются в маскированном виде;
JWT payload отображается.
2. Проверка PKCE

При переходе на Authorization Endpoint в URL должны присутствовать параметры:

code_challenge=...
code_challenge_method=S256

Это подтверждает использование Authorization Code Flow with PKCE.

Для Android/iOS PKCE выполняется библиотекой flutter_appauth.

Для web-версии PKCE формируется в коде приложения.

3. Проверка Discovery

В коде не должны быть вручную прописаны Authorization Endpoint и Token Endpoint.

Приложение должно использовать:

discoveryUrl

Для web-версии endpoint-ы должны браться из Discovery-документа.

4. Отображение токенов

После входа на экране должны отображаться:

Access Token;
ID Token;
Refresh Token, если выдан;
token_type;
scope;
срок действия Access Token;
время последнего обновления токенов.

Токены отображаются в маскированном виде.

5. Отображение JWT payload

После входа на экране должны отображаться:

Access Token payload;
ID Token payload.
6. Ручное обновление токенов
Выполнить вход.
Нажать кнопку обновления токенов.
Проверить, что время последнего обновления изменилось.
Проверить, что данные на экране обновились.

Ожидаемый результат:

Token Endpoint возвращает новые токены;
новые токены сохраняются;
интерфейс обновляется.
7. Автоматическое обновление Access Token
Выполнить вход.
Дождаться приближения срока истечения Access Token.
Приложение автоматически выполнит refresh заранее.

Ожидаемый результат:

Access Token обновляется до истечения;
сохранённые данные обновляются;
пользователь остаётся авторизованным.
8. Восстановление сессии после перезапуска
Выполнить вход.
Закрыть приложение.
Запустить приложение снова.

Ожидаемый результат:

приложение находит сохранённые токены;
выполняет восстановление сессии;
если Refresh Token ещё действителен, повторный вход не требуется.
9. Недействительный Refresh Token

Если Refresh Token отсутствует, истёк или отклонён Token Endpoint, приложение:

удаляет сохранённые токены;
очищает локальное состояние;
не выполняет восстановление сессии;
возвращает пользователя на экран входа.
10. Выход из приложения
Выполнить вход.
Нажать кнопку выхода.

Ожидаемый результат:

сохранённые токены удаляются;
пользовательские данные очищаются;
интерфейс возвращается в состояние до авторизации;
повторное восстановление сессии невозможно без нового входа.
Структура проекта
flutter_application_1/
├── android/                         # Android-конфигурация
├── ios/                             # iOS-конфигурация
├── lib/
│   ├── app/
│   │   ├── app.dart                 # MaterialApp
│   │   └── auth_gate.dart           # Выбор экрана по состоянию авторизации
│   ├── auth/
│   │   ├── auth_provider.dart       # UI-состояние авторизации
│   │   ├── auth_service.dart        # Mobile OIDC через flutter_appauth
│   │   ├── auth_session_manager.dart # Сценарии login, restore, refresh, logout
│   │   ├── token_storage.dart       # Хранение токенов
│   │   ├── web_auth_service.dart    # Web Authorization Code Flow with PKCE
│   │   └── web_auth_service_stub.dart # Stub для mobile-сборок
│   ├── config/
│   │   └── oidc_config.dart         # OIDC-конфигурация
│   ├── models/
│   │   ├── auth_state.dart          # Состояние авторизации
│   │   ├── auth_tokens.dart         # Модель токенов
│   │   └── user_profile.dart        # Профиль из ID Token
│   ├── screens/
│   │   ├── home_screen.dart         # Экран профиля и токенов
│   │   └── login_screen.dart        # Экран входа
│   ├── utils/
│   │   ├── date_time_utils.dart     # Форматирование времени
│   │   ├── jwt_utils.dart           # Декодирование JWT
│   │   └── token_masker.dart        # Маскирование токенов
│   ├── widgets/
│   │   ├── jwt_payload_block.dart   # UI-блок JWT payload
│   │   ├── masked_token_block.dart  # UI-блок маскированного токена
│   │   ├── profile_block.dart       # UI-блок профиля
│   │   └── status_block.dart        # UI-блок состояния авторизации
│   └── main.dart                    # Точка входа
├── web/                             # Web-конфигурация Flutter
├── codemagic.yaml                   # CI-сборка iOS
├── pubspec.yaml                     # Зависимости Flutter
└── README.md
Возможные проблемы и решения
Проблема	Возможная причина	Решение
Не открывается приложение после входа на Android	Не настроен custom scheme redirect	Проверить AndroidManifest.xml и redirect URI в Авторизе
Ошибка redirect URI	Redirect URI не совпадает с настройками в Авторизе	Проверить ru.authoriza.demo:/oauth2callback и http://localhost:3000/
Не приходит Refresh Token	Не указан scope offline_access	Проверить scopes в OidcConfig и настройках клиента
После перезапуска пользователь не восстановился	Refresh Token истёк или был очищен	Выполнить вход заново
Web-версия не возвращается в приложение	Неверный порт запуска	Запускать через flutter run -d chrome --web-port 3000
Ошибка CORS в web	Token Endpoint не разрешает запросы из браузера	Разрешить origin http://localhost:3000 на стороне провайдера
iOS нельзя установить на iPhone	Сборка выполнена без code signing	Настроить Apple Developer signing и собрать .ipa
Refresh Token отклонён	Refresh Token истёк или отозван	Приложение очищает сессию и просит войти заново
Безопасность

В репозиторий не должны попадать:

client_secret;
.env;
полные значения токенов;
дампы Token Endpoint response;
логи с токенами;
локальные файлы сборки;
временные файлы IDE.

Client ID для public client может находиться в клиентском приложении.

Client Secret в Flutter-приложении не используется и не должен храниться в репозитории.

Токены в интерфейсе отображаются только в маскированном виде.

Статус реализации

Реализовано:

OIDC Discovery;
Authorization Code Flow with PKCE;
Android login через flutter_appauth;
iOS-сборка через Codemagic;
web login через Authorization Code Flow with PKCE;
получение Access Token, ID Token и Refresh Token;
отображение параметров Token Endpoint;
маскирование токенов;
декодирование JWT payload;
сохранение токенов;
восстановление сессии после перезапуска;
ручное обновление токенов;
автоматическое обновление Access Token за 5 минут до истечения;
обработка недействительного Refresh Token;
logout с очисткой сохранённых данных;
декомпозиция кода на auth, models, screens, widgets, utils и app.

Не реализовано:

запрос к UserInfo Endpoint.

UserInfo Endpoint не используется в текущей версии. Данные пользователя отображаются из ID Token payload.


После вставки сделай:

```powershell
git add README.md
git commit -m "Add project documentation"
git push

Только проверь перед коммитом, что в README совпадает твоя реальная структура папок. Если ты не создавала какой-то файл из структуры, лучше убрать его из дерева, чтобы проверяющий не увидел несоответствие.

Вставленная ​​уценка(1).md
Файл
README
Описание:
назначения проекта;
стек и используемая библиотека OIDC;
требований к окружению;
установки зависимостей;
запуска проекта;
настройки приложения в Авторизе;
проверки основных сценариев. надо все точно также

Да, тогда README надо сделать строго под эти пункты, без лишнего огромного отчёта. Я бы взяла структуру как в примере Spring Boot README: назначение, стек, окружение, установка, настройка Авторизы, запуск, проверка сценариев, структура, безопасность, статус реализации

Замени README.md вот этим:

# Authoriza Flutter OIDC Client

**Демонстрационный проект интеграции Авторизы для Flutter**

Проект представляет собой Flutter-приложение, демонстрирующее интеграцию с сервисом Авториза по протоколу OpenID Connect.

Приложение реализует OpenID Connect Authorization Code Flow with PKCE, получение токенов через Token Endpoint, отображение полученных токенов, декодирование JWT payload, сохранение сессии, восстановление авторизации после перезапуска, ручное и автоматическое обновление токенов, а также выход с очисткой сохранённых данных.

## Назначение проекта

Данный проект является примером интеграции Авторизы для Flutter-приложения.

Он демонстрирует:

* реализацию OpenID Connect Authorization Code Flow with PKCE;
* использование Discovery Endpoint для получения OIDC-конфигурации;
* перенаправление пользователя в Авторизу после нажатия кнопки входа;
* получение Access Token, ID Token и Refresh Token через Token Endpoint;
* отображение ответа Token Endpoint;
* отображение decoded payload для Access Token и ID Token;
* сохранение токенов в локальное защищённое хранилище;
* восстановление сессии после перезапуска приложения;
* ручное обновление токенов через Refresh Token;
* автоматическое обновление Access Token до истечения срока действия;
* обработку ситуации, когда Refresh Token отсутствует, истёк или больше не принимается провайдером;
* выход из приложения с очисткой сохранённой сессии.

## Стек технологий

| Компонент | Инструмент |
| --- | --- |
| Язык | Dart |
| Фреймворк | Flutter |
| OIDC-клиент для Android/iOS | flutter_appauth |
| Web OIDC | Authorization Code Flow with PKCE |
| Хранение токенов | flutter_secure_storage |
| Управление состоянием | provider |
| HTTP-запросы для web-flow | http |
| Формирование PKCE code challenge для web | crypto |
| iOS CI build | Codemagic |

Используемые библиотеки:

```yaml
flutter_appauth
flutter_secure_storage
provider
http
crypto

Библиотека flutter_appauth используется для выполнения OpenID Connect Authorization Code Flow with PKCE на Android и iOS.

Для web-версии Authorization Code Flow with PKCE реализован в коде приложения: создаются code_verifier, code_challenge, state, выполняется redirect в Авторизу, после чего authorization code обменивается на токены через Token Endpoint.

Требования к окружению

Перед запуском необходимо установить:

Flutter SDK;
Dart SDK;
Android Studio или другой редактор;
Android SDK;
Chrome для запуска web-версии;
физическое Android-устройство или Android Emulator;
доступ к приложению, зарегистрированному в Авторизе.

Проверить Flutter можно командой:

flutter doctor
Установка зависимостей

Для установки зависимостей необходимо выполнить:

flutter pub get

Если проект ранее собирался с ошибками или были изменены зависимости, можно выполнить очистку:

flutter clean
flutter pub get
Настройка приложения в Авторизе

Для работы приложения необходимо создать OIDC-приложение в Авторизе и настроить параметры клиента.

Основные параметры
Параметр	Значение
Flow	Authorization Code Flow
PKCE	Включён
Тип клиента	Public client
Client authentication method	none
Mobile Redirect URI	ru.authoriza.demo:/oauth2callback
Web Redirect URI	http://localhost:3000/
Scopes

В приложении используются следующие scopes:

openid
profile
email
offline_access

Scope offline_access используется для получения Refresh Token.

Discovery

Приложение использует Discovery Endpoint.

OIDC endpoint-ы не прописываются вручную в коде. Приложение получает конфигурацию через Discovery.

Discovery URL:

https://a-kalinin-authoriza-backend-stand-d37a.twc1.net/oidc/.well-known/openid-configuration

OIDC-конфигурация находится в файле:

lib/config/oidc_config.dart

Пример конфигурации:

class OidcConfig {
  static const String discoveryUrl =
      'https://a-kalinin-authoriza-backend-stand-d37a.twc1.net/oidc/.well-known/openid-configuration';

  static const String clientId =
      '88be8919-1792-42fe-9f17-e9ba64e17507';

  static const String mobileRedirectUrl =
      'ru.authoriza.demo:/oauth2callback';

  static const String webRedirectUrl =
      'http://localhost:3000/';

  static const List<String> scopes = [
    'openid',
    'profile',
    'email',
    'offline_access',
  ];
}

clientId является идентификатором public client и может находиться в клиентском приложении.

client_secret в Flutter-приложении не используется и не должен храниться в репозитории.

Redirect URI
Android

Для Android используется custom scheme redirect:

ru.authoriza.demo:/oauth2callback

В файле:

android/app/src/main/AndroidManifest.xml

настроен intent-filter для обработки redirect URI.

iOS

Для iOS redirect scheme добавлен в файл:

ios/Runner/Info.plist

Используется схема:

ru.authoriza.demo

iOS-сборка проверялась через Codemagic без code signing.

Web

Для web-версии используется redirect URI:

http://localhost:3000/

Поэтому web-версию необходимо запускать именно на порту 3000.

Запуск проекта
Android

Запуск на Android-устройстве или эмуляторе:

flutter run

После запуска необходимо нажать кнопку входа. Приложение перенаправит пользователя в Авторизу, выполнит Authorization Code Flow with PKCE и после успешной авторизации отобразит полученные данные.

Web

Запуск web-версии:

flutter run -d chrome --web-port 3000

После входа Авториза вернёт пользователя на:

http://localhost:3000/

Приложение обработает authorization code и выполнит обмен кода на токены через Token Endpoint.

iOS

iOS-сборка проверяется через Codemagic.

Файл конфигурации находится в корне проекта:

codemagic.yaml

Workflow выполняет сборку iOS без подписи:

flutter build ios --debug --no-codesign

Такая сборка подтверждает, что проект компилируется под iOS.

Для установки приложения на реальный iPhone требуется Apple Developer signing и сборка подписанного .ipa.

Основные экраны приложения
Экран входа

На экране входа отображается кнопка авторизации.

После нажатия кнопки приложение:

формирует Authorization Request;
использует Authorization Code Flow with PKCE;
перенаправляет пользователя в Авторизу;
получает authorization code;
обменивает authorization code на токены через Token Endpoint;
сохраняет полученные данные;
открывает экран профиля и токенов.
Экран профиля и токенов

После успешной авторизации отображаются:

статус авторизации;
token_type;
scope;
время истечения Access Token;
время истечения Refresh Token, если доступно;
время последнего обновления токенов;
данные пользователя из ID Token;
маскированный Access Token;
маскированный ID Token;
маскированный Refresh Token;
decoded payload Access Token;
decoded payload ID Token.

Полные значения токенов на экран не выводятся. Токены отображаются в маскированном виде.

Отображение ответа Token Endpoint

После входа приложение отображает данные, полученные от Token Endpoint.

Минимальный набор:

Поле	Отображение
access_token	отображается в маскированном виде
id_token	отображается в маскированном виде
refresh_token	отображается в маскированном виде, если выдан
expires_in	отображается как оставшееся время до истечения Access Token
token_type	отображается
scope	отображается
Отображение содержимого токенов

Приложение декодирует JWT и отображает payload.

Для ID Token отображается:

ID Token payload

Для Access Token отображается:

Access Token payload

Декодирование выполняется локально на клиенте.

UserInfo

В текущей реализации UserInfo Endpoint не используется.

Данные пользователя отображаются из payload ID Token.

Если необходимо полностью закрыть пункт UserInfo из технического задания, нужно добавить отдельный запрос к userinfo_endpoint после успешного входа и после обновления токенов.

Хранение данных аутентификации

Для хранения данных аутентификации используется flutter_secure_storage.

Сохраняются:

Access Token;
Refresh Token;
ID Token;
время истечения Access Token;
token_type;
scope;
время последнего обновления токенов.

После закрытия и повторного запуска приложения выполняется попытка восстановления сессии.

Если Access Token ещё действителен, пользователь остаётся авторизованным.

Если Access Token истёк или скоро истечёт, приложение пытается обновить токены через Refresh Token.

Если Refresh Token отсутствует, истёк или Token Endpoint возвращает ошибку, сохранённые токены удаляются, состояние авторизации очищается, пользователь возвращается на экран входа.

Обновление токенов
Ручное обновление

На экране профиля доступна кнопка обновления токенов.

После нажатия приложение:

берёт сохранённый Refresh Token;
выполняет запрос к Token Endpoint;
получает новые токены;
обновляет сохранённые данные;
обновляет отображаемую информацию.
Автоматическое обновление

Автоматическое обновление выполняется:

при запуске приложения;
по таймеру до истечения срока действия Access Token.

Access Token обновляется заранее, с запасом примерно 5 минут до истечения срока действия.

Если обновление прошло успешно, новые токены сохраняются, а интерфейс обновляется.

Если обновление завершилось ошибкой, приложение очищает сохранённые данные и возвращает пользователя на экран входа.

Выход пользователя

При выходе приложение:

удаляет сохранённые токены;
удаляет сохранённые пользовательские данные;
очищает состояние авторизации;
очищает таймер автоматического обновления;
возвращает пользователя на экран входа.
Отображение состояния

Приложение отображает:

статус авторизации;
время истечения Access Token;
время истечения Refresh Token, если доступно;
время последнего обновления токенов.

Если Token Endpoint не возвращает время истечения Refresh Token, приложение отображает, что это значение недоступно.

Проверка основных сценариев
1. Вход через Авторизу
Запустить приложение.
Нажать кнопку входа.
Выполнить авторизацию в Авторизе.
Убедиться, что после входа открыт экран профиля и токенов.

Ожидаемый результат:

пользователь авторизован;
получены Access Token, ID Token и Refresh Token;
токены сохранены;
токены отображаются в маскированном виде;
JWT payload отображается.
2. Проверка PKCE

При переходе на Authorization Endpoint в URL должны присутствовать параметры:

code_challenge=...
code_challenge_method=S256

Это подтверждает использование Authorization Code Flow with PKCE.

Для Android и iOS PKCE выполняется библиотекой flutter_appauth.

Для web-версии PKCE формируется в коде приложения.

3. Проверка Discovery

В коде не должны быть вручную прописаны Authorization Endpoint и Token Endpoint.

Приложение должно использовать:

discoveryUrl

Для web-версии endpoint-ы должны браться из Discovery-документа.

4. Отображение токенов

После входа на экране должны отображаться:

Access Token;
ID Token;
Refresh Token, если выдан;
token_type;
scope;
срок действия Access Token;
время последнего обновления токенов.

Токены должны отображаться в маскированном виде.

5. Отображение JWT payload

После входа на экране должны отображаться:

Access Token payload;
ID Token payload.
6. Ручное обновление токенов
Выполнить вход.
Нажать кнопку обновления токенов.
Проверить, что время последнего обновления изменилось.
Проверить, что данные на экране обновились.

Ожидаемый результат:

Token Endpoint возвращает новые токены;
новые токены сохраняются;
интерфейс обновляется.
7. Автоматическое обновление Access Token
Выполнить вход.
Дождаться приближения срока истечения Access Token.
Приложение автоматически выполнит refresh заранее.

Ожидаемый результат:

Access Token обновляется до истечения;
сохранённые данные обновляются;
пользователь остаётся авторизованным.
8. Восстановление сессии после перезапуска
Выполнить вход.
Закрыть приложение.
Запустить приложение снова.

Ожидаемый результат:

приложение находит сохранённые токены;
выполняет восстановление сессии;
если Refresh Token ещё действителен, повторный вход не требуется.
9. Недействительный Refresh Token

Если Refresh Token отсутствует, истёк или отклонён Token Endpoint, приложение:

удаляет сохранённые токены;
очищает локальное состояние;
не выполняет восстановление сессии;
возвращает пользователя на экран входа.
10. Выход из приложения
Выполнить вход.
Нажать кнопку выхода.

Ожидаемый результат:

сохранённые токены удаляются;
пользовательские данные очищаются;
интерфейс возвращается в состояние до авторизации;
повторное восстановление сессии невозможно без нового входа.
Структура проекта
flutter_application_1/
├── android/
├── ios/
├── lib/
│   ├── app/
│   │   ├── app.dart
│   │   └── auth_gate.dart
│   ├── auth/
│   │   ├── auth_provider.dart
│   │   ├── auth_service.dart
│   │   ├── auth_session_manager.dart
│   │   ├── token_storage.dart
│   │   ├── web_auth_service.dart
│   │   └── web_auth_service_stub.dart
│   ├── config/
│   │   └── oidc_config.dart
│   ├── models/
│   │   ├── auth_state.dart
│   │   ├── auth_tokens.dart
│   │   └── user_profile.dart
│   ├── screens/
│   │   ├── home_screen.dart
│   │   └── login_screen.dart
│   ├── utils/
│   │   ├── date_time_utils.dart
│   │   ├── jwt_utils.dart
│   │   └── token_masker.dart
│   ├── widgets/
│   │   ├── jwt_payload_block.dart
│   │   ├── masked_token_block.dart
│   │   ├── profile_block.dart
│   │   └── status_block.dart
│   └── main.dart
├── web/
├── codemagic.yaml
├── pubspec.yaml
└── README.md
Возможные проблемы и решения
Проблема	Возможная причина	Решение
Не открывается приложение после входа на Android	Не настроен custom scheme redirect	Проверить AndroidManifest.xml и redirect URI в Авторизе
Ошибка redirect URI	Redirect URI не совпадает с настройками в Авторизе	Проверить ru.authoriza.demo:/oauth2callback и http://localhost:3000/
Не приходит Refresh Token	Не указан scope offline_access	Проверить scopes в OidcConfig и настройках клиента
После перезапуска пользователь не восстановился	Refresh Token истёк или был очищен	Выполнить вход заново
Web-версия не возвращается в приложение	Неверный порт запуска	Запускать через flutter run -d chrome --web-port 3000
Ошибка CORS в web	Token Endpoint не разрешает запросы из браузера	Разрешить origin http://localhost:3000 на стороне провайдера
iOS нельзя установить на iPhone	Сборка выполнена без code signing	Настроить Apple Developer signing и собрать .ipa
Refresh Token отклонён	Refresh Token истёк или отозван	Приложение очищает сессию и просит войти заново
Безопасность

В репозиторий не должны попадать:

client_secret;
.env;
полные значения токенов;
дампы Token Endpoint response;
логи с токенами;
локальные файлы сборки;
временные файлы IDE.

Client ID для public client может находиться в клиентском приложении.

Client Secret в Flutter-приложении не используется и не должен храниться в репозитории.

Токены в интерфейсе отображаются только в маскированном виде.

Статус реализации

Реализовано:

OIDC Discovery;
Authorization Code Flow with PKCE;
Android login через flutter_appauth;
iOS-сборка через Codemagic;
web login через Authorization Code Flow with PKCE;
получение Access Token, ID Token и Refresh Token;
отображение параметров Token Endpoint;
маскирование токенов;
декодирование JWT payload;
сохранение токенов;
восстановление сессии после перезапуска;
ручное обновление токенов;
автоматическое обновление Access Token за 5 минут до истечения;
обработка недействительного Refresh Token;
logout с очисткой сохранённых данных;
декомпозиция кода на auth, models, screens, widgets, utils и app.

Не реализовано:

запрос к UserInfo Endpoint.

UserInfo Endpoint не используется в текущей версии. Данные пользователя отображаются из ID Token payload.


Потом сохрани и запушь:

```powershell
git add README.md
git commit -m "Add README documentation"
git push

Перед пушем только проверь, что структура папок в README совпадает с реальной. Если у тебя какого-то файла нет, лучше убрать его из дерева README.

скинь мне текстовым файликом или сразу readme

Сделала готовый README.md файлом: 
README.md

Он собран в той же логике, что пример Spring Boot README: назначение, стек, окружение, установка зависимостей, запуск, настройка Авторизы и проверка сценариев. За основу структуры брала твой пример README по Spring Boot, где эти разделы уже идут в нужном формате.

Сохрани его в корень проекта вместо старого README.md, рядом с pubspec.yaml, потом:

git add README.md
git commit -m "Add README documentation"
git push

Библиотека
/
README.md
# Authoriza Flutter OIDC Client

**Демонстрационный проект интеграции Авторизы для Flutter**

Проект представляет собой Flutter-приложение, демонстрирующее интеграцию с сервисом Авториза по протоколу OpenID Connect.

Приложение реализует OpenID Connect Authorization Code Flow with PKCE, получение токенов через Token Endpoint, отображение полученных токенов, декодирование JWT payload, сохранение сессии, восстановление авторизации после перезапуска, ручное и автоматическое обновление токенов, а также выход с очисткой сохранённых данных.

## Назначение проекта

Данный проект является примером интеграции Авторизы для Flutter-приложения.

Он демонстрирует:

* реализацию OpenID Connect Authorization Code Flow with PKCE;
* использование Discovery Endpoint для получения OIDC-конфигурации;
* перенаправление пользователя в Авторизу после нажатия кнопки входа;
* получение Access Token, ID Token и Refresh Token через Token Endpoint;
* отображение ответа Token Endpoint;
* отображение decoded payload для Access Token и ID Token;
* сохранение токенов в локальное защищённое хранилище;
* восстановление сессии после перезапуска приложения;
* ручное обновление токенов через Refresh Token;
* автоматическое обновление Access Token до истечения срока действия;
* обработку ситуации, когда Refresh Token отсутствует, истёк или больше не принимается провайдером;
* выход из приложения с очисткой сохранённой сессии.

## Стек технологий

| Компонент | Инструмент |
| --- | --- |
| Язык | Dart |
| Фреймворк | Flutter |
| OIDC-клиент для Android/iOS | flutter_appauth |
| Web OIDC | Authorization Code Flow with PKCE |
| Хранение токенов | flutter_secure_storage |
| Управление состоянием | provider |
| HTTP-запросы для web-flow | http |
| Формирование PKCE code challenge для web | crypto |
| iOS CI build | Codemagic |

Используемые библиотеки:

```yaml
flutter_appauth
flutter_secure_storage
provider
http
crypto
```

Библиотека `flutter_appauth` используется для выполнения OpenID Connect Authorization Code Flow with PKCE на Android и iOS.

Для web-версии Authorization Code Flow with PKCE реализован в коде приложения: создаются `code_verifier`, `code_challenge`, `state`, выполняется redirect в Авторизу, после чего authorization code обменивается на токены через Token Endpoint.

## Требования к окружению

Перед запуском необходимо установить:

* Flutter SDK;
* Dart SDK;
* Android Studio или другой редактор;
* Android SDK;
* Chrome для запуска web-версии;
* физическое Android-устройство или Android Emulator;
* доступ к приложению, зарегистрированному в Авторизе.

Проверить Flutter можно командой:

```bash
flutter doctor
```

## Установка зависимостей

Для установки зависимостей необходимо выполнить:

```bash
flutter pub get
```

Если проект ранее собирался с ошибками или были изменены зависимости, можно выполнить очистку:

```bash
flutter clean
flutter pub get
```

## Настройка приложения в Авторизе

Для работы приложения необходимо создать OIDC-приложение в Авторизе и настроить параметры клиента.

### Основные параметры

| Параметр | Значение |
| --- | --- |
| Flow | Authorization Code Flow |
| PKCE | Включён |
| Тип клиента | Public client |
| Client authentication method | none |
| Mobile Redirect URI | `ru.authoriza.demo:/oauth2callback` |
| Web Redirect URI | `http://localhost:3000/` |

### Scopes

В приложении используются следующие scopes:

```text
openid
profile
email
offline_access
```

Scope `offline_access` используется для получения Refresh Token.

### Discovery

Приложение использует Discovery Endpoint.

OIDC endpoint-ы не прописываются вручную в коде. Приложение получает конфигурацию через Discovery.

Discovery URL:

```text
https://a-kalinin-authoriza-backend-stand-d37a.twc1.net/oidc/.well-known/openid-configuration
```

OIDC-конфигурация находится в файле:

```text
lib/config/oidc_config.dart
```

Пример конфигурации:

```dart
class OidcConfig {
  static const String discoveryUrl =
      'https://a-kalinin-authoriza-backend-stand-d37a.twc1.net/oidc/.well-known/openid-configuration';

  static const String clientId =
      '88be8919-1792-42fe-9f17-e9ba64e17507';

  static const String mobileRedirectUrl =
      'ru.authoriza.demo:/oauth2callback';

  static const String webRedirectUrl =
      'http://localhost:3000/';

  static const List<String> scopes = [
    'openid',
    'profile',
    'email',
    'offline_access',
  ];
}
```

`clientId` является идентификатором public client и может находиться в клиентском приложении.

`client_secret` в Flutter-приложении не используется и не должен храниться в репозитории.

## Redirect URI

### Android

Для Android используется custom scheme redirect:

```text
ru.authoriza.demo:/oauth2callback
```

В файле:

```text
android/app/src/main/AndroidManifest.xml
```

настроен intent-filter для обработки redirect URI.

### iOS

Для iOS redirect scheme добавлен в файл:

```text
ios/Runner/Info.plist
```

Используется схема:

```text
ru.authoriza.demo
```

iOS-сборка проверялась через Codemagic без code signing.

### Web

Для web-версии используется redirect URI:

```text
http://localhost:3000/
```

Поэтому web-версию необходимо запускать именно на порту `3000`.

## Запуск проекта

### Android

Запуск на Android-устройстве или эмуляторе:

```bash
flutter run
```

После запуска необходимо нажать кнопку входа. Приложение перенаправит пользователя в Авторизу, выполнит Authorization Code Flow with PKCE и после успешной авторизации отобразит полученные данные.

### Web

Запуск web-версии:

```bash
flutter run -d chrome --web-port 3000
```

После входа Авториза вернёт пользователя на:

```text
http://localhost:3000/
```

Приложение обработает authorization code и выполнит обмен кода на токены через Token Endpoint.

### iOS

iOS-сборка проверяется через Codemagic.

Файл конфигурации находится в корне проекта:

```text
codemagic.yaml
```

Workflow выполняет сборку iOS без подписи:

```bash
flutter build ios --debug --no-codesign
```

Такая сборка подтверждает, что проект компилируется под iOS.

Для установки приложения на реальный iPhone требуется Apple Developer signing и сборка подписанного `.ipa`.

## Основные экраны приложения

### Экран входа

На экране входа отображается кнопка авторизации.

После нажатия кнопки приложение:

1. формирует Authorization Request;
2. использует Authorization Code Flow with PKCE;
3. перенаправляет пользователя в Авторизу;
4. получает authorization code;
5. обменивает authorization code на токены через Token Endpoint;
6. сохраняет полученные данные;
7. открывает экран профиля и токенов.

### Экран профиля и токенов

После успешной авторизации отображаются:

* статус авторизации;
* token_type;
* scope;
* время истечения Access Token;
* время истечения Refresh Token, если доступно;
* время последнего обновления токенов;
* данные пользователя из ID Token;
* маскированный Access Token;
* маскированный ID Token;
* маскированный Refresh Token;
* decoded payload Access Token;
* decoded payload ID Token.

Полные значения токенов на экран не выводятся. Токены отображаются в маскированном виде.

## Отображение ответа Token Endpoint

После входа приложение отображает данные, полученные от Token Endpoint.

Минимальный набор:

| Поле | Отображение |
| --- | --- |
| access_token | отображается в маскированном виде |
| id_token | отображается в маскированном виде |
| refresh_token | отображается в маскированном виде, если выдан |
| expires_in | отображается как оставшееся время до истечения Access Token |
| token_type | отображается |
| scope | отображается |

## Отображение содержимого токенов

Приложение декодирует JWT и отображает payload.

Для ID Token отображается:

```text
ID Token payload
```

Для Access Token отображается:

```text
Access Token payload
```

Декодирование выполняется локально на клиенте.

## UserInfo

В текущей реализации UserInfo Endpoint не используется.

Данные пользователя отображаются из payload ID Token.

Если необходимо полностью закрыть пункт UserInfo из технического задания, нужно добавить отдельный запрос к `userinfo_endpoint` после успешного входа и после обновления токенов.

## Хранение данных аутентификации

Для хранения данных аутентификации используется `flutter_secure_storage`.

Сохраняются:

* Access Token;
* Refresh Token;
* ID Token;
* время истечения Access Token;
* token_type;
* scope;
* время последнего обновления токенов.

После закрытия и повторного запуска приложения выполняется попытка восстановления сессии.

Если Access Token ещё действителен, пользователь остаётся авторизованным.

Если Access Token истёк или скоро истечёт, приложение пытается обновить токены через Refresh Token.

Если Refresh Token отсутствует, истёк или Token Endpoint возвращает ошибку, сохранённые токены удаляются, состояние авторизации очищается, пользователь возвращается на экран входа.

## Обновление токенов

### Ручное обновление

На экране профиля доступна кнопка обновления токенов.

После нажатия приложение:

1. берёт сохранённый Refresh Token;
2. выполняет запрос к Token Endpoint;
3. получает новые токены;
4. обновляет сохранённые данные;
5. обновляет отображаемую информацию.

### Автоматическое обновление

Автоматическое обновление выполняется:

* при запуске приложения;
* по таймеру до истечения срока действия Access Token.

Access Token обновляется заранее, с запасом примерно 5 минут до истечения срока действия.

Если обновление прошло успешно, новые токены сохраняются, а интерфейс обновляется.

Если обновление завершилось ошибкой, приложение очищает сохранённые данные и возвращает пользователя на экран входа.

## Выход пользователя

При выходе приложение:

* удаляет сохранённые токены;
* удаляет сохранённые пользовательские данные;
* очищает состояние авторизации;
* очищает таймер автоматического обновления;
* возвращает пользователя на экран входа.

## Отображение состояния

Приложение отображает:

* статус авторизации;
* время истечения Access Token;
* время истечения Refresh Token, если доступно;
* время последнего обновления токенов.

Если Token Endpoint не возвращает время истечения Refresh Token, приложение отображает, что это значение недоступно.

## Проверка основных сценариев

### 1. Вход через Авторизу

1. Запустить приложение.
2. Нажать кнопку входа.
3. Выполнить авторизацию в Авторизе.
4. Убедиться, что после входа открыт экран профиля и токенов.

Ожидаемый результат:

* пользователь авторизован;
* получены Access Token, ID Token и Refresh Token;
* токены сохранены;
* токены отображаются в маскированном виде;
* JWT payload отображается.

### 2. Проверка PKCE

При переходе на Authorization Endpoint в URL должны присутствовать параметры:

```text
code_challenge=...
code_challenge_method=S256
```

Это подтверждает использование Authorization Code Flow with PKCE.

Для Android и iOS PKCE выполняется библиотекой `flutter_appauth`.

Для web-версии PKCE формируется в коде приложения.

### 3. Проверка Discovery

В коде не должны быть вручную прописаны Authorization Endpoint и Token Endpoint.

Приложение должно использовать:

```text
discoveryUrl
```

Для web-версии endpoint-ы должны браться из Discovery-документа.

### 4. Отображение токенов

После входа на экране должны отображаться:

* Access Token;
* ID Token;
* Refresh Token, если выдан;
* token_type;
* scope;
* срок действия Access Token;
* время последнего обновления токенов.

Токены должны отображаться в маскированном виде.

### 5. Отображение JWT payload

После входа на экране должны отображаться:

* Access Token payload;
* ID Token payload.

### 6. Ручное обновление токенов

1. Выполнить вход.
2. Нажать кнопку обновления токенов.
3. Проверить, что время последнего обновления изменилось.
4. Проверить, что данные на экране обновились.

Ожидаемый результат:

* Token Endpoint возвращает новые токены;
* новые токены сохраняются;
* интерфейс обновляется.

### 7. Автоматическое обновление Access Token

1. Выполнить вход.
2. Дождаться приближения срока истечения Access Token.
3. Приложение автоматически выполнит refresh заранее.

Ожидаемый результат:

* Access Token обновляется до истечения;
* сохранённые данные обновляются;
* пользователь остаётся авторизованным.

### 8. Восстановление сессии после перезапуска

1. Выполнить вход.
2. Закрыть приложение.
3. Запустить приложение снова.

Ожидаемый результат:

* приложение находит сохранённые токены;
* выполняет восстановление сессии;
* если Refresh Token ещё действителен, повторный вход не требуется.

### 9. Недействительный Refresh Token

Если Refresh Token отсутствует, истёк или отклонён Token Endpoint, приложение:

* удаляет сохранённые токены;
* очищает локальное состояние;
* не выполняет восстановление сессии;
* возвращает пользователя на экран входа.

### 10. Выход из приложения

1. Выполнить вход.
2. Нажать кнопку выхода.

Ожидаемый результат:

* сохранённые токены удаляются;
* пользовательские данные очищаются;
* интерфейс возвращается в состояние до авторизации;
* повторное восстановление сессии невозможно без нового входа.

## Структура проекта

```text
flutter_application_1/
├── android/
├── ios/
├── lib/
│   ├── app/
│   │   ├── app.dart
│   │   └── auth_gate.dart
│   ├── auth/
│   │   ├── auth_provider.dart
│   │   ├── auth_service.dart
│   │   ├── auth_session_manager.dart
│   │   ├── token_storage.dart
│   │   ├── web_auth_service.dart
│   │   └── web_auth_service_stub.dart
│   ├── config/
│   │   └── oidc_config.dart
│   ├── models/
│   │   ├── auth_state.dart
│   │   ├── auth_tokens.dart
│   │   └── user_profile.dart
│   ├── screens/
│   │   ├── home_screen.dart
│   │   └── login_screen.dart
│   ├── utils/
│   │   ├── date_time_utils.dart
│   │   ├── jwt_utils.dart
│   │   └── token_masker.dart
│   ├── widgets/
│   │   ├── jwt_payload_block.dart
│   │   ├── masked_token_block.dart
│   │   ├── profile_block.dart
│   │   └── status_block.dart
│   └── main.dart
├── web/
├── codemagic.yaml
├── pubspec.yaml
└── README.md
```

## Возможные проблемы и решения

| Проблема | Возможная причина | Решение |
| --- | --- | --- |
| Не открывается приложение после входа на Android | Не настроен custom scheme redirect | Проверить `AndroidManifest.xml` и redirect URI в Авторизе |
| Ошибка redirect URI | Redirect URI не совпадает с настройками в Авторизе | Проверить `ru.authoriza.demo:/oauth2callback` и `http://localhost:3000/` |
| Не приходит Refresh Token | Не указан scope `offline_access` | Проверить scopes в `OidcConfig` и настройках клиента |
| После перезапуска пользователь не восстановился | Refresh Token истёк или был очищен | Выполнить вход заново |
| Web-версия не возвращается в приложение | Неверный порт запуска | Запускать через `flutter run -d chrome --web-port 3000` |
| Ошибка CORS в web | Token Endpoint не разрешает запросы из браузера | Разрешить origin `http://localhost:3000` на стороне провайдера |
| iOS нельзя установить на iPhone | Сборка выполнена без code signing | Настроить Apple Developer signing и собрать `.ipa` |
| Refresh Token отклонён | Refresh Token истёк или отозван | Приложение очищает сессию и просит войти заново |

## Безопасность

В репозиторий не должны попадать:

* client_secret;
* `.env`;
* полные значения токенов;
* дампы Token Endpoint response;
* логи с токенами;
* локальные файлы сборки;
* временные файлы IDE.

Client ID для public client может находиться в клиентском приложении.

Client Secret в Flutter-приложении не используется и не должен храниться в репозитории.

Токены в интерфейсе отображаются только в маскированном виде.

## Статус реализации

Реализовано:

* OIDC Discovery;
* Authorization Code Flow with PKCE;
* Android login через `flutter_appauth`;
* iOS-сборка через Codemagic;
* web login через Authorization Code Flow with PKCE;
* получение Access Token, ID Token и Refresh Token;
* отображение параметров Token Endpoint;
* маскирование токенов;
* декодирование JWT payload;
* сохранение токенов;
* восстановление сессии после перезапуска;
* ручное обновление токенов;
* автоматическое обновление Access Token за 5 минут до истечения;
* обработка недействительного Refresh Token;
* logout с очисткой сохранённых данных;
* декомпозиция кода на auth, models, screens, widgets, utils и app.

Не реализовано:

* запрос к UserInfo Endpoint.

UserInfo Endpoint не используется в текущей версии. Данные пользователя отображаются из ID Token payload.

Библиотека
/
README.md
# Authoriza Flutter OIDC Client

**Демонстрационный проект интеграции Авторизы для Flutter**

Проект представляет собой Flutter-приложение, демонстрирующее интеграцию с сервисом Авториза по протоколу OpenID Connect.

Приложение реализует OpenID Connect Authorization Code Flow with PKCE, получение токенов через Token Endpoint, отображение полученных токенов, декодирование JWT payload, сохранение сессии, восстановление авторизации после перезапуска, ручное и автоматическое обновление токенов, а также выход с очисткой сохранённых данных.

## Назначение проекта

Данный проект является примером интеграции Авторизы для Flutter-приложения.

Он демонстрирует:

* реализацию OpenID Connect Authorization Code Flow with PKCE;
* использование Discovery Endpoint для получения OIDC-конфигурации;
* перенаправление пользователя в Авторизу после нажатия кнопки входа;
* получение Access Token, ID Token и Refresh Token через Token Endpoint;
* отображение ответа Token Endpoint;
* отображение decoded payload для Access Token и ID Token;
* сохранение токенов в локальное защищённое хранилище;
* восстановление сессии после перезапуска приложения;
* ручное обновление токенов через Refresh Token;
* автоматическое обновление Access Token до истечения срока действия;
* обработку ситуации, когда Refresh Token отсутствует, истёк или больше не принимается провайдером;
* выход из приложения с очисткой сохранённой сессии.

## Стек технологий

| Компонент | Инструмент |
| --- | --- |
| Язык | Dart |
| Фреймворк | Flutter |
| OIDC-клиент для Android/iOS | flutter_appauth |
| Web OIDC | Authorization Code Flow with PKCE |
| Хранение токенов | flutter_secure_storage |
| Управление состоянием | provider |
| HTTP-запросы для web-flow | http |
| Формирование PKCE code challenge для web | crypto |
| iOS CI build | Codemagic |

Используемые библиотеки:

```yaml
flutter_appauth
flutter_secure_storage
provider
http
crypto
```

Библиотека `flutter_appauth` используется для выполнения OpenID Connect Authorization Code Flow with PKCE на Android и iOS.

Для web-версии Authorization Code Flow with PKCE реализован в коде приложения: создаются `code_verifier`, `code_challenge`, `state`, выполняется redirect в Авторизу, после чего authorization code обменивается на токены через Token Endpoint.

## Требования к окружению

Перед запуском необходимо установить:

* Flutter SDK;
* Dart SDK;
* Android Studio или другой редактор;
* Android SDK;
* Chrome для запуска web-версии;
* физическое Android-устройство или Android Emulator;
* доступ к приложению, зарегистрированному в Авторизе.

Проверить Flutter можно командой:

```bash
flutter doctor
```

## Установка зависимостей

Для установки зависимостей необходимо выполнить:

```bash
flutter pub get
```

Если проект ранее собирался с ошибками или были изменены зависимости, можно выполнить очистку:

```bash
flutter clean
flutter pub get
```

## Настройка приложения в Авторизе

Для работы приложения необходимо создать OIDC-приложение в Авторизе и настроить параметры клиента.

### Основные параметры

| Параметр | Значение |
| --- | --- |
| Flow | Authorization Code Flow |
| PKCE | Включён |
| Тип клиента | Public client |
| Client authentication method | none |
| Mobile Redirect URI | `ru.authoriza.demo:/oauth2callback` |
| Web Redirect URI | `http://localhost:3000/` |

### Scopes

В приложении используются следующие scopes:

```text
openid
profile
email
offline_access
```

Scope `offline_access` используется для получения Refresh Token.

### Discovery

Приложение использует Discovery Endpoint.

OIDC endpoint-ы не прописываются вручную в коде. Приложение получает конфигурацию через Discovery.

Discovery URL:

```text
https://a-kalinin-authoriza-backend-stand-d37a.twc1.net/oidc/.well-known/openid-configuration
```

OIDC-конфигурация находится в файле:

```text
lib/config/oidc_config.dart
```

Пример конфигурации:

```dart
class OidcConfig {
  static const String discoveryUrl =
      'https://a-kalinin-authoriza-backend-stand-d37a.twc1.net/oidc/.well-known/openid-configuration';

  static const String clientId =
      '88be8919-1792-42fe-9f17-e9ba64e17507';

  static const String mobileRedirectUrl =
      'ru.authoriza.demo:/oauth2callback';

  static const String webRedirectUrl =
      'http://localhost:3000/';

  static const List<String> scopes = [
    'openid',
    'profile',
    'email',
    'offline_access',
  ];
}
```

`clientId` является идентификатором public client и может находиться в клиентском приложении.

`client_secret` в Flutter-приложении не используется и не должен храниться в репозитории.

## Redirect URI

### Android

Для Android используется custom scheme redirect:

```text
ru.authoriza.demo:/oauth2callback
```

В файле:

```text
android/app/src/main/AndroidManifest.xml
```

настроен intent-filter для обработки redirect URI.

### iOS

Для iOS redirect scheme добавлен в файл:

```text
ios/Runner/Info.plist
```

Используется схема:

```text
ru.authoriza.demo
```

iOS-сборка проверялась через Codemagic без code signing.

### Web

Для web-версии используется redirect URI:

```text
http://localhost:3000/
```

Поэтому web-версию необходимо запускать именно на порту `3000`.

## Запуск проекта

### Android

Запуск на Android-устройстве или эмуляторе:

```bash
flutter run
```

После запуска необходимо нажать кнопку входа. Приложение перенаправит пользователя в Авторизу, выполнит Authorization Code Flow with PKCE и после успешной авторизации отобразит полученные данные.

### Web

Запуск web-версии:

```bash
flutter run -d chrome --web-port 3000
```

После входа Авториза вернёт пользователя на:

```text
http://localhost:3000/
```

Приложение обработает authorization code и выполнит обмен кода на токены через Token Endpoint.

### iOS

iOS-сборка проверяется через Codemagic.

Файл конфигурации находится в корне проекта:

```text
codemagic.yaml
```

Workflow выполняет сборку iOS без подписи:

```bash
flutter build ios --debug --no-codesign
```

Такая сборка подтверждает, что проект компилируется под iOS.

Для установки приложения на реальный iPhone требуется Apple Developer signing и сборка подписанного `.ipa`.

## Основные экраны приложения

### Экран входа

На экране входа отображается кнопка авторизации.

После нажатия кнопки приложение:

1. формирует Authorization Request;
2. использует Authorization Code Flow with PKCE;
3. перенаправляет пользователя в Авторизу;
4. получает authorization code;
5. обменивает authorization code на токены через Token Endpoint;
6. сохраняет полученные данные;
7. открывает экран профиля и токенов.

### Экран профиля и токенов

После успешной авторизации отображаются:

* статус авторизации;
* token_type;
* scope;
* время истечения Access Token;
* время истечения Refresh Token, если доступно;
* время последнего обновления токенов;
* данные пользователя из ID Token;
* маскированный Access Token;
* маскированный ID Token;
* маскированный Refresh Token;
* decoded payload Access Token;
* decoded payload ID Token.

Полные значения токенов на экран не выводятся. Токены отображаются в маскированном виде.

## Отображение ответа Token Endpoint

После входа приложение отображает данные, полученные от Token Endpoint.

Минимальный набор:

| Поле | Отображение |
| --- | --- |
| access_token | отображается в маскированном виде |
| id_token | отображается в маскированном виде |
| refresh_token | отображается в маскированном виде, если выдан |
| expires_in | отображается как оставшееся время до истечения Access Token |
| token_type | отображается |
| scope | отображается |

## Отображение содержимого токенов

Приложение декодирует JWT и отображает payload.

Для ID Token отображается:

```text
ID Token payload
```

Для Access Token отображается:

```text
Access Token payload
```

Декодирование выполняется локально на клиенте.

## UserInfo

В текущей реализации UserInfo Endpoint не используется.

Данные пользователя отображаются из payload ID Token.

Если необходимо полностью закрыть пункт UserInfo из технического задания, нужно добавить отдельный запрос к `userinfo_endpoint` после успешного входа и после обновления токенов.

## Хранение данных аутентификации

Для хранения данных аутентификации используется `flutter_secure_storage`.

Сохраняются:

* Access Token;
* Refresh Token;
* ID Token;
* время истечения Access Token;
* token_type;
* scope;
* время последнего обновления токенов.

После закрытия и повторного запуска приложения выполняется попытка восстановления сессии.

Если Access Token ещё действителен, пользователь остаётся авторизованным.

Если Access Token истёк или скоро истечёт, приложение пытается обновить токены через Refresh Token.

Если Refresh Token отсутствует, истёк или Token Endpoint возвращает ошибку, сохранённые токены удаляются, состояние авторизации очищается, пользователь возвращается на экран входа.

## Обновление токенов

### Ручное обновление

На экране профиля доступна кнопка обновления токенов.

После нажатия приложение:

1. берёт сохранённый Refresh Token;
2. выполняет запрос к Token Endpoint;
3. получает новые токены;
4. обновляет сохранённые данные;
5. обновляет отображаемую информацию.

### Автоматическое обновление

Автоматическое обновление выполняется:

* при запуске приложения;
* по таймеру до истечения срока действия Access Token.

Access Token обновляется заранее, с запасом примерно 5 минут до истечения срока действия.

Если обновление прошло успешно, новые токены сохраняются, а интерфейс обновляется.

Если обновление завершилось ошибкой, приложение очищает сохранённые данные и возвращает пользователя на экран входа.

## Выход пользователя

При выходе приложение:

* удаляет сохранённые токены;
* удаляет сохранённые пользовательские данные;
* очищает состояние авторизации;
* очищает таймер автоматического обновления;
* возвращает пользователя на экран входа.

## Отображение состояния

Приложение отображает:

* статус авторизации;
* время истечения Access Token;
* время истечения Refresh Token, если доступно;
* время последнего обновления токенов.

Если Token Endpoint не возвращает время истечения Refresh Token, приложение отображает, что это значение недоступно.

## Проверка основных сценариев

### 1. Вход через Авторизу

1. Запустить приложение.
2. Нажать кнопку входа.
3. Выполнить авторизацию в Авторизе.
4. Убедиться, что после входа открыт экран профиля и токенов.

Ожидаемый результат:

* пользователь авторизован;
* получены Access Token, ID Token и Refresh Token;
* токены сохранены;
* токены отображаются в маскированном виде;
* JWT payload отображается.

### 2. Проверка PKCE

При переходе на Authorization Endpoint в URL должны присутствовать параметры:

```text
code_challenge=...
code_challenge_method=S256
```

Это подтверждает использование Authorization Code Flow with PKCE.

Для Android и iOS PKCE выполняется библиотекой `flutter_appauth`.

Для web-версии PKCE формируется в коде приложения.

### 3. Проверка Discovery

В коде не должны быть вручную прописаны Authorization Endpoint и Token Endpoint.

Приложение должно использовать:

```text
discoveryUrl
```

Для web-версии endpoint-ы должны браться из Discovery-документа.

### 4. Отображение токенов

После входа на экране должны отображаться:

* Access Token;
* ID Token;
* Refresh Token, если выдан;
* token_type;
* scope;
* срок действия Access Token;
* время последнего обновления токенов.

Токены должны отображаться в маскированном виде.

### 5. Отображение JWT payload

После входа на экране должны отображаться:

* Access Token payload;
* ID Token payload.

### 6. Ручное обновление токенов

1. Выполнить вход.
2. Нажать кнопку обновления токенов.
3. Проверить, что время последнего обновления изменилось.
4. Проверить, что данные на экране обновились.

Ожидаемый результат:

* Token Endpoint возвращает новые токены;
* новые токены сохраняются;
* интерфейс обновляется.

### 7. Автоматическое обновление Access Token

1. Выполнить вход.
2. Дождаться приближения срока истечения Access Token.
3. Приложение автоматически выполнит refresh заранее.

Ожидаемый результат:

* Access Token обновляется до истечения;
* сохранённые данные обновляются;
* пользователь остаётся авторизованным.

### 8. Восстановление сессии после перезапуска

1. Выполнить вход.
2. Закрыть приложение.
3. Запустить приложение снова.

Ожидаемый результат:

* приложение находит сохранённые токены;
* выполняет восстановление сессии;
* если Refresh Token ещё действителен, повторный вход не требуется.

### 9. Недействительный Refresh Token

Если Refresh Token отсутствует, истёк или отклонён Token Endpoint, приложение:

* удаляет сохранённые токены;
* очищает локальное состояние;
* не выполняет восстановление сессии;
* возвращает пользователя на экран входа.

### 10. Выход из приложения

1. Выполнить вход.
2. Нажать кнопку выхода.

Ожидаемый результат:

* сохранённые токены удаляются;
* пользовательские данные очищаются;
* интерфейс возвращается в состояние до авторизации;
* повторное восстановление сессии невозможно без нового входа.

## Структура проекта

```text
flutter_application_1/
├── android/
├── ios/
├── lib/
│   ├── app/
│   │   ├── app.dart
│   │   └── auth_gate.dart
│   ├── auth/
│   │   ├── auth_provider.dart
│   │   ├── auth_service.dart
│   │   ├── auth_session_manager.dart
│   │   ├── token_storage.dart
│   │   ├── web_auth_service.dart
│   │   └── web_auth_service_stub.dart
│   ├── config/
│   │   └── oidc_config.dart
│   ├── models/
│   │   ├── auth_state.dart
│   │   ├── auth_tokens.dart
│   │   └── user_profile.dart
│   ├── screens/
│   │   ├── home_screen.dart
│   │   └── login_screen.dart
│   ├── utils/
│   │   ├── date_time_utils.dart
│   │   ├── jwt_utils.dart
│   │   └── token_masker.dart
│   ├── widgets/
│   │   ├── jwt_payload_block.dart
│   │   ├── masked_token_block.dart
│   │   ├── profile_block.dart
│   │   └── status_block.dart
│   └── main.dart
├── web/
├── codemagic.yaml
├── pubspec.yaml
└── README.md
```

## Возможные проблемы и решения

| Проблема | Возможная причина | Решение |
| --- | --- | --- |
| Не открывается приложение после входа на Android | Не настроен custom scheme redirect | Проверить `AndroidManifest.xml` и redirect URI в Авторизе |
| Ошибка redirect URI | Redirect URI не совпадает с настройками в Авторизе | Проверить `ru.authoriza.demo:/oauth2callback` и `http://localhost:3000/` |
| Не приходит Refresh Token | Не указан scope `offline_access` | Проверить scopes в `OidcConfig` и настройках клиента |
| После перезапуска пользователь не восстановился | Refresh Token истёк или был очищен | Выполнить вход заново |
| Web-версия не возвращается в приложение | Неверный порт запуска | Запускать через `flutter run -d chrome --web-port 3000` |
| Ошибка CORS в web | Token Endpoint не разрешает запросы из браузера | Разрешить origin `http://localhost:3000` на стороне провайдера |
| iOS нельзя установить на iPhone | Сборка выполнена без code signing | Настроить Apple Developer signing и собрать `.ipa` |
| Refresh Token отклонён | Refresh Token истёк или отозван | Приложение очищает сессию и просит войти заново |

## Безопасность

В репозиторий не должны попадать:

* client_secret;
* `.env`;
* полные значения токенов;
* дампы Token Endpoint response;
* логи с токенами;
* локальные файлы сборки;
* временные файлы IDE.

Client ID для public client может находиться в клиентском приложении.

Client Secret в Flutter-приложении не используется и не должен храниться в репозитории.

Токены в интерфейсе отображаются только в маскированном виде.

## Статус реализации

Реализовано:

* OIDC Discovery;
* Authorization Code Flow with PKCE;
* Android login через `flutter_appauth`;
* iOS-сборка через Codemagic;
* web login через Authorization Code Flow with PKCE;
* получение Access Token, ID Token и Refresh Token;
* отображение параметров Token Endpoint;
* маскирование токенов;
* декодирование JWT payload;
* сохранение токенов;
* восстановление сессии после перезапуска;
* ручное обновление токенов;
* автоматическое обновление Access Token за 5 минут до истечения;
* обработка недействительного Refresh Token;
* logout с очисткой сохранённых данных;
* декомпозиция кода на auth, models, screens, widgets, utils и app.

Не реализовано:

* запрос к UserInfo Endpoint.

UserInfo Endpoint не используется в текущей версии. Данные пользователя отображаются из ID Token payload.