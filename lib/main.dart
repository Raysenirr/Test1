import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app/app.dart';
import 'auth/auth_provider.dart';
import 'auth/auth_service.dart';
import 'auth/auth_session_manager.dart';
import 'auth/token_storage.dart';

void main() {
  final tokenStorage = TokenStorage();
  final authService = AuthService(tokenStorage);
  final authSessionManager = AuthSessionManager(authService);

  runApp(
    ChangeNotifierProvider(
      create: (_) => AuthProvider(authSessionManager)..checkAuthState(),
      child: const App(),
    ),
  );
}