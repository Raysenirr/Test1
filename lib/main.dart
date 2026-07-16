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